#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of SpineOpt.
#
# SpineOpt is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SpineOpt is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

# TODO: fix_units_on, fix_unit_flow

@testset "unit-based constraints" begin
	url_in = "sqlite:///$(@__DIR__)/test.sqlite"
	test_data = Dict(
		:objects => [
			["model", "instance"], 
			["temporal_block", "hourly"],
			["temporal_block", "two_hourly"],
			["stochastic_structure", "deterministic"],
			["stochastic_structure", "stochastic"],
			["unit", "test_unit"],
			["node", "test_node_a"],
			["node", "test_node_b"],
			["stochastic_scenario", "parent"],
			["stochastic_scenario", "child"],
		],
		:relationships => [
			["units_on_resolution", ["test_unit", "test_node_a"]],
			["unit__from_node", ["test_unit", "test_node_a"]],
			["unit__to_node", ["test_unit", "test_node_b"]],
			["node__temporal_block", ["test_node_a", "hourly"]],
			["node__temporal_block", ["test_node_b", "two_hourly"]],
			["node__stochastic_structure", ["test_node_a", "stochastic"]],
			["node__stochastic_structure", ["test_node_b", "deterministic"]],
			["stochastic_structure__stochastic_scenario", ["deterministic", "parent"]],
			["stochastic_structure__stochastic_scenario", ["stochastic", "parent"]],
			["stochastic_structure__stochastic_scenario", ["stochastic", "child"]],
			["parent_stochastic_scenario__child_stochastic_scenario", ["parent", "child"]],
		],
		:object_parameter_values => [
			["model", "instance", "model_start", Dict("type" => "date_time", "data" => "2000-01-01T00:00:00")],
			["model", "instance", "model_end", Dict("type" => "date_time", "data" => "2000-01-01T02:00:00")],
			["model", "instance", "duration_unit", "hour"],
			["temporal_block", "hourly", "resolution", Dict("type" => "duration", "data" => "1h")],
			["temporal_block", "two_hourly", "resolution", Dict("type" => "duration", "data" => "2h")],
		],
		:relationship_parameter_values => [
			[
				"stochastic_structure__stochastic_scenario", 
				["stochastic", "parent"], 
				"stochastic_scenario_end", 
				Dict("type" => "duration", "data" => "1h")
			]
		]
	)
	@testset "constraint_units_on" begin
		_load_template(url_in)
		db_api.import_data_to_url(url_in; test_data...)
		m = run_spineopt(url_in; log_level=0)
		var_units_on = m.ext[:variables][:units_on]
		var_units_available = m.ext[:variables][:units_available]
		constraint = m.ext[:constraints][:units_on]
		@test length(constraint) == 2
		scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
		time_slices = time_slice(temporal_block=temporal_block(:hourly))
		@testset for (s, t) in zip(scenarios, time_slices)
			key = (unit(:test_unit), s, t)
			var_u_on = var_units_on[key...]
			var_u_av = var_units_available[key...]
			expected_con = @build_constraint(var_u_on <= var_u_av)
			con_u_on = constraint[key]
			observed_con = constraint_object(con_u_on)
			@test _is_constraint_equal(observed_con, expected_con)
		end
	end
	@testset "constraint_units_available" begin
		_load_template(url_in)
		db_api.import_data_to_url(url_in; test_data...)
		number_of_units = 4		
		candidate_units = 3
		object_parameter_values = [
			["unit", "test_unit", "candidate_units", candidate_units], 
			["unit", "test_unit", "number_of_units", number_of_units]
		]
		relationships = [
			["unit__investment_temporal_block", ["test_unit", "hourly"]],
			["unit__investment_stochastic_structure", ["test_unit", "stochastic"]],
		]
		db_api.import_data_to_url(url_in; relationships=relationships, object_parameter_values=object_parameter_values)
		m = run_spineopt(url_in; log_level=0)
		var_units_available = m.ext[:variables][:units_available]
		var_units_invested_available = m.ext[:variables][:units_invested_available]
		constraint = m.ext[:constraints][:units_available]
		@test length(constraint) == 2
		scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
		time_slices = time_slice(temporal_block=temporal_block(:hourly))
		@testset for (s, t) in zip(scenarios, time_slices)
			key = (unit(:test_unit), s, t)
			var_u_av = var_units_available[key...]
			var_u_inv_av = var_units_invested_available[key...]
			expected_con = @build_constraint(var_u_av - var_u_inv_av == number_of_units)
			con = constraint[key]
			observed_con = constraint_object(con)
			@test _is_constraint_equal(observed_con, expected_con)
		end
	end
	@testset "constraint_unit_state_transition" begin
		_load_template(url_in)
		db_api.import_data_to_url(url_in; test_data...)
		m = run_spineopt(url_in; log_level=0)
		var_units_on = m.ext[:variables][:units_on]
		var_units_started_up = m.ext[:variables][:units_started_up]
		var_units_shut_down = m.ext[:variables][:units_shut_down]
		constraint = m.ext[:constraints][:unit_state_transition]
		@test length(constraint) == 3
		scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
		s0 = stochastic_scenario(:parent)
		time_slices = time_slice(temporal_block=temporal_block(:hourly))
		@testset for (s1, t1) in zip(scenarios, time_slices)
			path = unique([s0, s1])
			var_key1 = (unit(:test_unit), s1, t1)
			var_u_on1 = var_units_on[var_key1...]
			var_u_su1 = var_units_started_up[var_key1...]
			var_u_sd1 = var_units_shut_down[var_key1...]
			@testset for t0 in t_before_t(t_after=t1)
				var_key0 = (unit(:test_unit), s0, t0)
				var_u_on0 = get(var_units_on, var_key0, 0)
				con_key = (unit(:test_unit), path, t0, t1)
				expected_con = @build_constraint(var_u_on1 - var_u_on0 == var_u_su1 - var_u_sd1)
				observed_con = constraint_object(constraint[con_key])
				@test _is_constraint_equal(observed_con, expected_con)
			end
		end
	end
	@testset "constraint_unit_flow_capacity" begin
		_load_template(url_in)
		db_api.import_data_to_url(url_in; test_data...)
		unit_capacity = 100
		relationship_parameter_values = [
			["unit__from_node", ["test_unit", "test_node_a"], "unit_capacity", unit_capacity]
		]
		db_api.import_data_to_url(url_in; relationship_parameter_values=relationship_parameter_values)
		m = run_spineopt(url_in; log_level=0)
		var_unit_flow = m.ext[:variables][:unit_flow]
		var_units_on = m.ext[:variables][:units_on]
		constraint = m.ext[:constraints][:unit_flow_capacity]
		@test length(constraint) == 2
		scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
		time_slices = time_slice(temporal_block=temporal_block(:hourly))
		@testset for (s, t) in zip(scenarios, time_slices)
			var_u_flow_key = (unit(:test_unit), node(:test_node_a), direction(:from_node), s, t)
			var_u_on_key = (unit(:test_unit), s, t)
			var_u_flow = var_unit_flow[var_u_flow_key...]
			var_u_on = var_units_on[var_u_on_key...]
			con_key = (unit(:test_unit), node(:test_node_a), direction(:from_node), [s], t)
			expected_con = @build_constraint(var_u_flow <= unit_capacity * var_u_on)
			observed_con = constraint_object(constraint[con_key])
			@test _is_constraint_equal(observed_con, expected_con)
		end
	end
	@testset "constraint_minimum_operating_point" begin
		_load_template(url_in)
		db_api.import_data_to_url(url_in; test_data...)
		unit_capacity = 100
		minimum_operating_point = 0.25
		relationship_parameter_values = [
			["unit__from_node", ["test_unit", "test_node_a"], "unit_capacity", unit_capacity],
			["unit__from_node", ["test_unit", "test_node_a"], "minimum_operating_point", minimum_operating_point]
		]
		db_api.import_data_to_url(url_in; relationship_parameter_values=relationship_parameter_values)
		m = run_spineopt(url_in; log_level=0)
		var_unit_flow = m.ext[:variables][:unit_flow]
		var_units_on = m.ext[:variables][:units_on]
		constraint = m.ext[:constraints][:minimum_operating_point]
		@test length(constraint) == 2
		scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
		time_slices = time_slice(temporal_block=temporal_block(:hourly))
		@testset for (s, t) in zip(scenarios, time_slices)
			var_u_flow_key = (unit(:test_unit), node(:test_node_a), direction(:from_node), s, t)
			var_u_on_key = (unit(:test_unit), s, t)
			var_u_flow = var_unit_flow[var_u_flow_key...]
			var_u_on = var_units_on[var_u_on_key...]
			con_key = (unit(:test_unit), node(:test_node_a), direction(:from_node), [s], t)
			expected_con = @build_constraint(var_u_flow >= minimum_operating_point * unit_capacity * var_u_on)
			observed_con = constraint_object(constraint[con_key])
			@test _is_constraint_equal(observed_con, expected_con)
		end
	end
	@testset "constraint_operating_point_bounds" begin
		_load_template(url_in)
		db_api.import_data_to_url(url_in; test_data...)
		unit_capacity = 100
		points = [0.1, 0.5, 1.0]
		deltas = [points[1]; [points[i] - points[i - 1] for i in 2:length(points)]]
		operating_points = Dict("type" => "array", "data" => PyVector(points))
		relationship_parameter_values = [
			["unit__from_node", ["test_unit", "test_node_a"], "unit_capacity", unit_capacity],
			["unit__from_node", ["test_unit", "test_node_a"], "operating_points", operating_points]
		]
		db_api.import_data_to_url(url_in; relationship_parameter_values=relationship_parameter_values)
		m = run_spineopt(url_in; log_level=0)
		var_unit_flow_op = m.ext[:variables][:unit_flow_op]
		constraint = m.ext[:constraints][:operating_point_bounds]
		@test length(constraint) == 6
		scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
		time_slices = time_slice(temporal_block=temporal_block(:hourly))
		@testset for (s, t) in zip(scenarios, time_slices)
			@testset for (i, delta) in enumerate(deltas)
				key = (unit(:test_unit), node(:test_node_a), direction(:from_node), i, s, t)
				var_u_flow_op = var_unit_flow_op[key...]
				expected_con = @build_constraint(var_u_flow_op <= delta * unit_capacity)
				observed_con = constraint_object(constraint[key])
				@test _is_constraint_equal(observed_con, expected_con)
			end
		end
	end
	@testset "constraint_operating_point_sum" begin
		_load_template(url_in)
		db_api.import_data_to_url(url_in; test_data...)
		unit_capacity = 100
		points = [0.1, 0.5, 1.0]
		operating_points = Dict("type" => "array", "data" => PyVector(points))
		relationship_parameter_values = [
			["unit__from_node", ["test_unit", "test_node_a"], "operating_points", operating_points]
		]
		db_api.import_data_to_url(url_in; relationship_parameter_values=relationship_parameter_values)
		m = run_spineopt(url_in; log_level=0)
		var_unit_flow = m.ext[:variables][:unit_flow]
		var_unit_flow_op = m.ext[:variables][:unit_flow_op]
		constraint = m.ext[:constraints][:operating_point_sum]
		@test length(constraint) == 2
		scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
		time_slices = time_slice(temporal_block=temporal_block(:hourly))
		@testset for (s, t) in zip(scenarios, time_slices)
			subkey = (unit(:test_unit), node(:test_node_a), direction(:from_node))
			key = (subkey..., s, t)
			var_u_flow = var_unit_flow[key...]
			vars_u_flow_op = [var_unit_flow_op[(subkey..., i, s, t)...] for i in 1:length(points)]
			expected_con = @build_constraint(var_u_flow == sum(vars_u_flow_op))
			observed_con = constraint_object(constraint[key])
			@test _is_constraint_equal(observed_con, expected_con)
		end
	end
	@testset "constraint_ratio_unit_flow" begin
		flow_ratio = 0.8
		units_on_coeff = 0.2
		class = "unit__node__node"
		relationship = ["test_unit", "test_node_a", "test_node_b"]
		senses_by_prefix = Dict("min" => >=, "fix" => ==, "max" => <=)
		directions_by_prefix = Dict("in" => direction(:from_node), "out" => direction(:to_node))
		classes_by_prefix = Dict("in" => "unit__from_node", "out" => "unit__to_node")
		@testset for (p, a, b) in (
				("min", "in", "in"),
				("fix", "in", "in"),
				("max", "in", "in"),
				("min", "in", "out"),
				("fix", "in", "out"),
				("max", "in", "out"),
				("min", "out", "in"),
				("fix", "out", "in"),
				("max", "out", "in"),
				("min", "out", "out"),
				("fix", "out", "out"),
				("max", "out", "out"),
			)
			_load_template(url_in)
			db_api.import_data_to_url(url_in; test_data...)
			ratio = join([p, "ratio", a, b, "unit_flow"], "_")
			coeff = join([p, "units_on_coefficient", a, b], "_")
			relationships = [
				[classes_by_prefix[a], ["test_unit", "test_node_a"]],
				[classes_by_prefix[b], ["test_unit", "test_node_b"]],
				[class, relationship], 
			]
			relationship_parameter_values = [
				[class, relationship, ratio, flow_ratio], [class, relationship, coeff, units_on_coeff]
			]
			sense = senses_by_prefix[p]
			db_api.import_data_to_url(
				url_in; relationships=relationships, relationship_parameter_values=relationship_parameter_values
			)
			m = run_spineopt(url_in; log_level=0)
			var_unit_flow = m.ext[:variables][:unit_flow]
			var_units_on = m.ext[:variables][:units_on]
			constraint = m.ext[:constraints][Symbol(ratio)]
			@test length(constraint) == 1
			path = [stochastic_scenario(:parent), stochastic_scenario(:child)]
			t_long = first(time_slice(temporal_block=temporal_block(:two_hourly)))
			t_short1, t_short2 = time_slice(temporal_block=temporal_block(:hourly))
			d_a = directions_by_prefix[a]
			d_b = directions_by_prefix[b]
			var_u_flow_b_key = (unit(:test_unit), node(:test_node_b), d_b, stochastic_scenario(:parent), t_long)
			var_u_flow_a1_key = (unit(:test_unit), node(:test_node_a), d_a, stochastic_scenario(:parent), t_short1)
			var_u_flow_a2_key = (unit(:test_unit), node(:test_node_a), d_a, stochastic_scenario(:child), t_short2)
			var_u_on_a1_key = (unit(:test_unit), stochastic_scenario(:parent), t_short1)
			var_u_on_a2_key = (unit(:test_unit), stochastic_scenario(:child), t_short2)
			var_u_flow_b = var_unit_flow[var_u_flow_b_key...]
			var_u_flow_a1 = var_unit_flow[var_u_flow_a1_key...]
			var_u_flow_a2 = var_unit_flow[var_u_flow_a2_key...]
			var_u_on_a1 = var_units_on[var_u_on_a1_key...]
			var_u_on_a2 = var_units_on[var_u_on_a2_key...]
			con_key = (unit(:test_unit), node(:test_node_a), node(:test_node_b), path, t_long)
			expected_con_ref = SpineOpt.sense_constraint(
				m,
				var_u_flow_a1 + var_u_flow_a2,
				sense,
				2 * flow_ratio * var_u_flow_b + units_on_coeff * (var_u_on_a1 + var_u_on_a2)
			)
			expected_con = constraint_object(expected_con_ref)
			observed_con = constraint_object(constraint[con_key])
			@test _is_constraint_equal(observed_con, expected_con)
		end
	end
	@testset "constraint_min_up_time" begin
		model_end = Dict("type" => "date_time", "data" => "2000-01-01T05:00:00")
		@testset for min_up_minutes in (60, 120, 210)
			_load_template(url_in)
			db_api.import_data_to_url(url_in; test_data...)
			min_up_time = Dict("type" => "duration", "data" => string(min_up_minutes, "m"))
			object_parameter_values = [
				["unit", "test_unit", "min_up_time", min_up_time], ["model", "instance", "model_end", model_end],
			]
			db_api.import_data_to_url(url_in; object_parameter_values=object_parameter_values)
			m = run_spineopt(url_in; log_level=0)
			var_units_on = m.ext[:variables][:units_on]
			var_units_started_up = m.ext[:variables][:units_started_up]
			constraint = m.ext[:constraints][:min_up_time]
			@test length(constraint) == 5
			parent_end = stochastic_scenario_end(
				stochastic_structure=stochastic_structure(:stochastic), 
				stochastic_scenario=stochastic_scenario(:parent)
			)
			head_hours = length(time_slice(temporal_block=temporal_block(:hourly))) - round(parent_end, Hour(1)).value
			tail_hours = round(Minute(min_up_minutes), Hour(1)).value
			scenarios = [
				repeat([stochastic_scenario(:child)], head_hours); repeat([stochastic_scenario(:parent)], tail_hours)
			]
			time_slices = [
				reverse(time_slice(temporal_block=temporal_block(:hourly)));
				reverse(SpineOpt.history_time_slice(temporal_block=temporal_block(:hourly)))
			][1:head_hours + tail_hours]
			@testset for h in 1:length(constraint)
				s_set, t_set = scenarios[h:h + tail_hours - 1], time_slices[h:h + tail_hours - 1]
				s, t = s_set[1], t_set[1]
				path = reverse(unique(s_set))
				key = (unit(:test_unit), path, t)
				var_u_on_key = (unit(:test_unit), s, t)
				var_u_on = var_units_on[var_u_on_key...]
				vars_u_su = [var_units_started_up[unit(:test_unit), s, t] for (s, t) in zip(s_set, t_set)]
				expected_con = @build_constraint(var_u_on >= sum(vars_u_su))
				observed_con = constraint_object(constraint[key])
				@test _is_constraint_equal(observed_con, expected_con)
			end
		end
	end
	@testset "constraint_min_down_time" begin
		model_end = Dict("type" => "date_time", "data" => "2000-01-01T05:00:00")
		@testset for min_down_minutes in (45, 150, 300)
			_load_template(url_in)
			db_api.import_data_to_url(url_in; test_data...)
			min_down_time = Dict("type" => "duration", "data" => string(min_down_minutes, "m"))
			object_parameter_values = [
				["unit", "test_unit", "min_down_time", min_down_time], ["model", "instance", "model_end", model_end],
			]
			db_api.import_data_to_url(url_in; object_parameter_values=object_parameter_values)
			m = run_spineopt(url_in; log_level=0)
			var_units_on = m.ext[:variables][:units_on]
			var_units_available = m.ext[:variables][:units_available]
			var_units_shut_down = m.ext[:variables][:units_shut_down]
			constraint = m.ext[:constraints][:min_down_time]
			@test length(constraint) == 5
			parent_end = stochastic_scenario_end(
				stochastic_structure=stochastic_structure(:stochastic), 
				stochastic_scenario=stochastic_scenario(:parent)
			)
			head_hours = length(time_slice(temporal_block=temporal_block(:hourly))) - round(parent_end, Hour(1)).value
			tail_hours = round(Minute(min_down_minutes), Hour(1)).value
			scenarios = [
				repeat([stochastic_scenario(:child)], head_hours); repeat([stochastic_scenario(:parent)], tail_hours)
			]
			time_slices = [
				reverse(time_slice(temporal_block=temporal_block(:hourly)));
				reverse(SpineOpt.history_time_slice(temporal_block=temporal_block(:hourly)))
			][1:head_hours + tail_hours]
			@testset for h in 1:length(constraint)
				s_set, t_set = scenarios[h:h + tail_hours - 1], time_slices[h:h + tail_hours - 1]
				s, t = s_set[1], t_set[1]
				path = reverse(unique(s_set))
				key = (unit(:test_unit), path, t)
				var_u_av_on_key = (unit(:test_unit), s, t)
				var_u_av = var_units_available[var_u_av_on_key...]
				var_u_on = var_units_on[var_u_av_on_key...]
				vars_u_sd = [var_units_shut_down[unit(:test_unit), s, t] for (s, t) in zip(s_set, t_set)]
				expected_con = @build_constraint(var_u_av - var_u_on >= sum(vars_u_sd))
				observed_con = constraint_object(constraint[key])
				@test _is_constraint_equal(observed_con, expected_con)
			end
		end
	end	
	@testset "constraint_units_invested_available" begin
		_load_template(url_in)
		db_api.import_data_to_url(url_in; test_data...)
		candidate_units = 7
		object_parameter_values = [["unit", "test_unit", "candidate_units", candidate_units]]
		relationships = [
			["unit__investment_temporal_block", ["test_unit", "hourly"]],
			["unit__investment_stochastic_structure", ["test_unit", "stochastic"]],
		]
		db_api.import_data_to_url(url_in; relationships=relationships, object_parameter_values=object_parameter_values)
		m = run_spineopt(url_in; log_level=0)
		var_units_invested_available = m.ext[:variables][:units_invested_available]
		constraint = m.ext[:constraints][:units_invested_available]
		@test length(constraint) == 2
		scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
		time_slices = time_slice(temporal_block=temporal_block(:hourly))
		@testset for (s, t) in zip(scenarios, time_slices)
			key = (unit(:test_unit), s, t)
			var = var_units_invested_available[key...]
			expected_con = @build_constraint(var <= candidate_units)
			con = constraint[key]
			observed_con = constraint_object(con)
			@test _is_constraint_equal(observed_con, expected_con)
		end
	end
	@testset "constraint_units_invested_transition" begin
		_load_template(url_in)
		db_api.import_data_to_url(url_in; test_data...)
		candidate_units = 4
		object_parameter_values = [["unit", "test_unit", "candidate_units", candidate_units]]
		relationships = [
			["unit__investment_temporal_block", ["test_unit", "hourly"]],
			["unit__investment_stochastic_structure", ["test_unit", "stochastic"]],
		]
		db_api.import_data_to_url(url_in; relationships=relationships, object_parameter_values=object_parameter_values)
		m = run_spineopt(url_in; log_level=0)
		var_units_invested_available = m.ext[:variables][:units_invested_available]
		var_units_invested = m.ext[:variables][:units_invested]
		var_units_mothballed = m.ext[:variables][:units_mothballed]
		constraint = m.ext[:constraints][:units_invested_transition]
		@test length(constraint) == 3
		scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
		s0 = stochastic_scenario(:parent)
		time_slices = time_slice(temporal_block=temporal_block(:hourly))
		@testset for (s1, t1) in zip(scenarios, time_slices)
			path = unique([s0, s1])
			var_key1 = (unit(:test_unit), s1, t1)
			var_u_inv_av1 = var_units_invested_available[var_key1...]
			var_u_inv_1 = var_units_invested[var_key1...]
			var_u_moth_1 = var_units_mothballed[var_key1...]
			@testset for t0 in t_before_t(t_after=t1)
				var_key0 = (unit(:test_unit), s0, t0)
				var_u_inv_av0 = get(var_units_invested_available, var_key0, 0)
				con_key = (unit(:test_unit), path, t0, t1)
				expected_con = @build_constraint(var_u_inv_av1 - var_u_inv_1 + var_u_moth_1 == var_u_inv_av0)
				observed_con = constraint_object(constraint[con_key])
				@test _is_constraint_equal(observed_con, expected_con)
			end
		end
	end
	@testset "constraint_unit_lifetime" begin
		candidate_units = 3
		model_end = Dict("type" => "date_time", "data" => "2000-01-01T05:00:00")
		@testset for lifetime_minutes in (30, 180, 240)
			_load_template(url_in)
			db_api.import_data_to_url(url_in; test_data...)
			unit_investment_lifetime = Dict("type" => "duration", "data" => string(lifetime_minutes, "m"))
			object_parameter_values = [
				["unit", "test_unit", "candidate_units", candidate_units],
				["unit", "test_unit", "unit_investment_lifetime", unit_investment_lifetime],
				["model", "instance", "model_end", model_end]
			]
			relationships = [
				["unit__investment_temporal_block", ["test_unit", "hourly"]],
				["unit__investment_stochastic_structure", ["test_unit", "stochastic"]],
			]
			db_api.import_data_to_url(url_in; relationships=relationships, object_parameter_values=object_parameter_values)
			m = run_spineopt(url_in; log_level=0)
			var_units_invested_available = m.ext[:variables][:units_invested_available]
			var_units_invested = m.ext[:variables][:units_invested]
			constraint = m.ext[:constraints][:unit_lifetime]
			@test length(constraint) == 5
			parent_end = stochastic_scenario_end(
				stochastic_structure=stochastic_structure(:stochastic), 
				stochastic_scenario=stochastic_scenario(:parent)
			)
			head_hours = length(time_slice(temporal_block=temporal_block(:hourly))) - round(parent_end, Hour(1)).value
			tail_hours = round(Minute(lifetime_minutes), Hour(1)).value
			scenarios = [
				repeat([stochastic_scenario(:child)], head_hours); repeat([stochastic_scenario(:parent)], tail_hours)
			]
			time_slices = [
				reverse(time_slice(temporal_block=temporal_block(:hourly)));
				reverse(SpineOpt.history_time_slice(temporal_block=temporal_block(:hourly)))
			][1:head_hours + tail_hours]
			@testset for h in 1:length(constraint)
				s_set, t_set = scenarios[h:h + tail_hours - 1], time_slices[h:h + tail_hours - 1]
				s, t = s_set[1], t_set[1]
				path = reverse(unique(s_set))
				key = (unit(:test_unit), path, t)
				var_u_inv_av_key = (unit(:test_unit), s, t)
				var_u_inv_av = var_units_invested_available[var_u_inv_av_key...]
				vars_u_inv = [var_units_invested[unit(:test_unit), s, t] for (s, t) in zip(s_set, t_set)]
				expected_con = @build_constraint(var_u_inv_av >= sum(vars_u_inv))
				observed_con = constraint_object(constraint[key])
				@test _is_constraint_equal(observed_con, expected_con)
			end
		end
	end
end

