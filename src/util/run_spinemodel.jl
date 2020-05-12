#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of Spine Model.
#
# Spine Model is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Spine Model is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################
"""
    run_spinemodel(url; <keyword arguments>)

Run the Spine model from `url` and write report to the same `url`.
Keyword arguments have the same purpose as for [`run_spinemodel`](@ref).
"""
function run_spinemodel(
        url::String;
        with_optimizer=optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0),
        cleanup=true,
        add_constraints=m -> nothing,
        update_constraints=m -> nothing,
        log_level=3)
    run_spinemodel(
        url,
        url;
        with_optimizer=with_optimizer,
        cleanup=cleanup,
        add_constraints=add_constraints,
        update_constraints=update_constraints,
        log_level=log_level
    )
end


function generate_temporal_structure()
    generate_current_window()
    generate_time_slice()
    generate_time_slice_relationships()
end


function generate_variable_indices()
    unit_flow_indices = unique(
        (unit=u, node=n, direction=d, stochastic_scenario=s, t=t)
        for (u, n, d) in Iterators.flatten((unit__from_node(), unit__to_node()))
        for (n, s, t) in node_stochastic_time_indices(node=n)
    )
    connection_flow_indices = unique(
        (connection=conn, node=n, direction=d, stochastic_scenario=s, t=t)
        for (conn, n, d) in Iterators.flatten((connection__from_node(), connection__to_node()))
        for (n, s, t) in node_stochastic_time_indices(node=n)
    )
    node_state_indices = unique(
        (node=n, stochastic_scenario=s, t=t)
        for n in node(has_state=:value_true)
        for (n, s, t) in node_stochastic_time_indices(node=n)
    )
    units_on_indices = unique(
        (unit=u, stochastic_scenario=s, t=t)
        for (u, s, t) in unit_stochastic_time_indices()
    )
    unit_flow_indices_rc = RelationshipClass(
        :unit_flow_indices_rc, [:unit, :node, :direction, :stochastic_scenario, :t], unit_flow_indices
    )
    connection_flow_indices_rc = RelationshipClass(
        :connection_flow_indices_rc, [:connection, :node, :direction, :stochastic_scenario, :t], connection_flow_indices
    )
    node_state_indices_rc = RelationshipClass(
        :node_state_indices_rc, [:node, :stochastic_scenario, :t], node_state_indices
    )
    units_on_indices_rc = RelationshipClass(
        :units_on_indices_rc, [:unit, :stochastic_scenario, :t], units_on_indices
    )
    @eval begin
        unit_flow_indices_rc = $unit_flow_indices_rc
        connection_flow_indices_rc = $connection_flow_indices_rc
        node_state_indices_rc = $node_state_indices_rc
        units_on_indices_rc = $units_on_indices_rc
    end
end


function generate_stochastic_structure()
    all_stochastic_trees = generate_all_stochastic_trees(start(current_window))
    generate_node_stochastic_time_indices(all_stochastic_trees)
    generate_node_stochastic_scenario_weight(all_stochastic_trees)
    full_stochastic_paths = find_full_stochastic_paths()
    @eval begin
        full_stochastic_paths = $full_stochastic_paths
    end
end


"""
    run_spinemodel(url_in, url_out; <keyword arguments>)

Run the Spine model from `url_in` and write report to `url_out`.
At least `url_in` must point to valid Spine database.
A new Spine database is created at `url_out` if it doesn't exist.

# Keyword arguments

**`with_optimizer=with_optimizer(Cbc.Optimizer, logLevel=0)`** is the optimizer factory for building the JuMP model.

**`cleanup=true`** tells [`run_spinemodel`](@ref) whether or not convenience functors should be
set to `nothing` after completion.

**`add_constraints=m -> nothing`** is called with the `Model` object in the first optimization window, and allows adding user contraints.

**`update_constraints=m -> nothing`** is called in windows 2 to the last, and allows updating contraints added by `add_constraints`.

**`log_level=3`** is the log level.
"""
function run_spinemodel(
        url_in::String,
        url_out::String;
        with_optimizer=optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0, "ratioGap" => 0.01),
        cleanup=true,
        add_constraints=m -> nothing,
        update_constraints=m -> nothing,
        log_level=3)
    level2 = log_level >= 2
    @log true "Running Spine Model for $(url_in)..."
    @logtime level2 "Initializing data structure from db..." begin
        using_spinedb(url_in, @__MODULE__; upgrade=true)
        generate_missing_items()
    end
    @logtime level2 "Preprocessing data structure..." preprocess_data_structure()
    @logtime level2 "Creating temporal structure..." generate_temporal_structure()
    @logtime level2 "Creating stochastic structure..." generate_stochastic_structure()
    @logtime level2 "Creating variable indices..." generate_variable_indices()
    check_islands(log_level)
    m = rerun_spinemodel(
        url_out;
        with_optimizer=with_optimizer,
        add_constraints=add_constraints,
        update_constraints=update_constraints,
        log_level=log_level
    )
    # TODO: cleanup && notusing_spinedb(url_in, @__MODULE__)
    m
end

function rerun_spinemodel(
        url_out::String;
        with_optimizer=optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0, "ratioGap" => 0.01),
        add_constraints=m -> nothing,
        update_constraints=m -> nothing,
        log_level=3)
    level0 = log_level >= 0
    level1 = log_level >= 1
    level2 = log_level >= 2
    level3 = log_level >= 3
    results = Dict()
    m = Model(with_optimizer)
    m.ext[:variables] = Dict{Symbol,Dict}()
    m.ext[:variables_definition] = Dict{Symbol,Dict}()
    m.ext[:values] = Dict{Symbol,Dict}()
    m.ext[:constraints] = Dict{Symbol,Dict}()
    @log level1 "Window 1: $current_window"
    @logtime level2 "Adding variables...\n" begin
        @logtime level3 "- [variable_units_available]" add_variable_units_available!(m)
        @logtime level3 "- [variable_units_on]" add_variable_units_on!(m)
        @logtime level3 "- [variable_units_started_up]" add_variable_units_started_up!(m)
        @logtime level3 "- [variable_units_shut_down]" add_variable_units_shut_down!(m)
        @logtime level3 "- [variable_unit_flow]" add_variable_unit_flow!(m)
        @logtime level3 "- [variable_unit_flow_op]" add_variable_unit_flow_op!(m)
        @logtime level3 "- [variable_connection_flow]" add_variable_connection_flow!(m)
        @logtime level3 "- [variable_node_state]" add_variable_node_state!(m)
        @logtime level3 "- [variable_node_slack_pos]" add_variable_node_slack_pos!(m)
        @logtime level3 "- [variable_node_slack_neg]" add_variable_node_slack_neg!(m)
        @logtime level3 "- [variable_node_injection]" add_variable_node_injection!(m)
    end
    @logtime level2 "Fixing variable values..." fix_variables!(m)
    @logtime level2 "Adding constraints...\n" begin
        @logtime level3 "- [constraint_unit_constraint]" add_constraint_unit_constraint!(m)
        @logtime level3 "- [constraint_node_injection]" add_constraint_node_injection!(m)
        @logtime level3 "- [constraint_nodal_balance]" add_constraint_nodal_balance!(m)
        @logtime level3 "- [constraint_connection_flow_ptdf]" add_constraint_connection_flow_ptdf!(m)
        @logtime level3 "- [constraint_connection_flow_lodf]" add_constraint_connection_flow_lodf!(m)
        @logtime level3 "- [constraint_unit_flow_capacity]" add_constraint_unit_flow_capacity!(m)
        @logtime level3 "- [constraint_operating_point_bounds]" add_constraint_operating_point_bounds!(m)
        @logtime level3 "- [constraint_operating_point_sum]" add_constraint_operating_point_sum!(m)
        @logtime level3 "- [constraint_fix_ratio_out_in_unit_flow]" add_constraint_fix_ratio_out_in_unit_flow!(m)
        @logtime level3 "- [constraint_max_ratio_out_in_unit_flow]" add_constraint_max_ratio_out_in_unit_flow!(m)
        @logtime level3 "- [constraint_min_ratio_out_in_unit_flow]" add_constraint_min_ratio_out_in_unit_flow!(m)
        @logtime level3 "- [constraint_fix_ratio_out_out_unit_flow]" add_constraint_fix_ratio_out_out_unit_flow!(m)
        @logtime level3 "- [constraint_max_ratio_out_out_unit_flow]" add_constraint_max_ratio_out_out_unit_flow!(m)
        @logtime level3 "- [constraint_fix_ratio_in_in_unit_flow]" add_constraint_fix_ratio_in_in_unit_flow!(m)
        @logtime level3 "- [constraint_max_ratio_in_in_unit_flow]" add_constraint_max_ratio_in_in_unit_flow!(m)
        @logtime level3 "- [constraint_fix_ratio_in_out_unit_flow]" add_constraint_fix_ratio_in_out_unit_flow!(m)
        @logtime level3 "- [constraint_max_ratio_in_out_unit_flow]" add_constraint_max_ratio_in_out_unit_flow!(m)
        @logtime level3 "- [constraint_min_ratio_in_out_unit_flow]" add_constraint_min_ratio_in_out_unit_flow!(m)
        @logtime level3 "- [constraint_fix_ratio_out_in_connection_flow]" add_constraint_fix_ratio_out_in_connection_flow!(m)
        @logtime level3 "- [constraint_max_ratio_out_in_connection_flow]" add_constraint_max_ratio_out_in_connection_flow!(m)
        @logtime level3 "- [constraint_min_ratio_out_in_connection_flow]" add_constraint_min_ratio_out_in_connection_flow!(m)
        @logtime level3 "- [constraint_connection_flow_capacity]" add_constraint_connection_flow_capacity!(m)
        @logtime level3 "- [constraint_node_state_capacity]" add_constraint_node_state_capacity!(m)
        @logtime level3 "- [constraint_max_cum_in_unit_flow_bound]" add_constraint_max_cum_in_unit_flow_bound!(m)
        @logtime level3 "- [constraint_units_on]" add_constraint_units_on!(m)
        @logtime level3 "- [constraint_units_available]" add_constraint_units_available!(m)
        @logtime level3 "- [constraint_minimum_operating_point]" add_constraint_minimum_operating_point!(m)
        @logtime level3 "- [constraint_min_down_time]" add_constraint_min_down_time!(m)
        @logtime level3 "- [constraint_min_up_time]" add_constraint_min_up_time!(m)
        @logtime level3 "- [constraint_unit_state_transition]" add_constraint_unit_state_transition!(m)
        @logtime level3 "- [constraint_user]" add_constraints(m)
        @logtime level3 "- [setting constraint names]" name_constraints!(m)
    end
    @logtime level2 "Setting objective..." set_objective!(m)
    k = 2
    while optimize_model!(m)
        @log level1 "Optimal solution found, objective function value: $(objective_value(m))"
        @logtime level2 "Saving results..." begin
            postprocess_results!(m)
            save_values!(m)
            save_results!(results, m)
        end
        roll_temporal_structure() || break
        @log level1 "Window $k: $current_window"
        @logtime level2 "Updating variables..." update_variables!(m)
        @logtime level2 "Fixing variable values..." fix_variables!(m)
        @logtime level2 "Updating constraints..." update_varying_constraints!(m)
        @logtime level2 "Updating user constraints..." update_constraints(m)
        @logtime level2 "Updating objective..." update_varying_objective!(m)
        k += 1
    end
     @logtime level2 "Writing report..." write_report(results, url_out)
     m
end

function optimize_model!(m::Model)
    write_mps_file(model=first(model())) == :write_mps_always && write_to_file(m, "model_diagnostics.mps")
    # NOTE: The above results in a lot of Warning: Variable connection_flow[...] is mentioned in BOUNDS,
    # but is not mentioned in the COLUMNS section. We are ignoring it.
    @logtime true "Optimizing model..." optimize!(m)
    if termination_status(m) == MOI.OPTIMAL
        true
    else
        @log true "Unable to find solution (reason: $(termination_status(m)))"
        write_mps_file(model=first(model())) == :write_mps_on_no_solve && write_to_file(m, "model_diagnostics.mps")
        false
    end
end

"""
    save_results!(results, m)

Update `results` with results from `m`.
"""
function save_results!(results, m)
    for out in output()
        value = get(m.ext[:values], out.name, nothing)
        if value === nothing
            @warn "can't find results for '$(out.name)'"
            continue
        end
        value_ = Dict{NamedTuple,Number}((; k..., t=start(k.t)) => v for (k, v) in value)
        existing = get!(results, out.name, Dict{NamedTuple,Number}())
        merge!(existing, value_)
    end
end

function write_report(results, default_url)
    reports = Dict()
    for (rpt, out) in report__output()
        value = get(results, out.name, nothing)
        if value === nothing
            continue
        end
        url = output_db_url(report=rpt, _strict=false)
        url === nothing && (url = default_url)
        url_reports = get!(reports, url, Dict())
        output_params = get!(url_reports, rpt.name, Dict{Symbol,Dict{NamedTuple,TimeSeries}}())
        output_params[out.name] = Dict{NamedTuple,TimeSeries}(
            k => TimeSeries(first.(v), last.(v), false, false) for (k, v) in pulldims(value, :t)
        )
    end
    for (url, url_reports) in reports
        for (rpt_name, output_params) in url_reports
            write_parameters(output_params, url; report=string(rpt_name))
        end
    end
end

"""
    pulldims(input, dims...)

An equivalent dictionary where the given dimensions are pulled from the key to the value.
"""
function pulldims(input::Dict{K,V}, dims::Symbol...) where {K<:NamedTuple,V}
    output = Dict()
    for (key, value) in sort(input)
        output_key = (; (k => v for (k, v) in pairs(key) if !(k in dims))...)
        output_value = ((key[dim] for dim in dims)..., value)
        push!(get!(output, output_key, []), output_value)
    end
    output
end

"""
    formulation(d::Dict)

An equivalent dictionary where `JuMP.ConstraintRef` values are replaced by their `String` formulation.
"""
formulation(d::Dict{K,JuMP.ConstraintRef}) where {K} = Dict{K,Any}(k => sprint(show, v) for (k, v) in d)
