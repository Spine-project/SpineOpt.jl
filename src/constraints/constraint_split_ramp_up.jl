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
    add_constraint_split_ramp_up!(m::Model)

Split delta(`unit_flow`) in `ramp_up_unit_flow and` `start_up_unit_flow`.

This is required to enforce separate limitations on these two ramp types.
"""
function add_constraint_split_ramp_up!(m::Model)
    @fetch unit_flow, ramp_up_unit_flow, start_up_unit_flow, nonspin_ramp_up_unit_flow = m.ext[:variables]
    m.ext[:constraints][:split_ramp_up] = Dict(
        (unit=u, node=n, direction=d, stochastic_path=s, t_before=t_before, t_after=t_after) => @constraint(
            m,
            expr_sum(
                +unit_flow[u, n, d, s, t_after]
                for
                (u, n, d, s, t_after) in
                unit_flow_indices(m; unit=u, node=n, direction=d, stochastic_scenario=s, t=t_after) if
                !is_reserve_node(node=n);
                init=0,
            ) + expr_sum(
                +unit_flow[u, n, d, s, t_after]
                for
                (u, n, d, s, t_after) in
                unit_flow_indices(m; unit=u, node=n, direction=d, stochastic_scenario=s, t=t_after) if
                is_reserve_node(node=n) && upward_reserve(node=n);
                init=0,
            ) - expr_sum(
                +unit_flow[u, n, d, s, t_before]
                for
                (u, n, d, s, t_before) in
                unit_flow_indices(m; unit=u, node=n, direction=d, stochastic_scenario=s, t=t_before) if
                !is_reserve_node(node=n);
                init=0,
            ) <= expr_sum(
                +get(ramp_up_unit_flow, (u, n, d, s, t_after), 0) +
                get(start_up_unit_flow, (u, n, d, s, t_after), 0) +
                get(nonspin_ramp_up_unit_flow, (u, n, d, s, t_after), 0) for s in s;
                init=0,
            )
        ) for (u, n, d, s, t_before, t_after) in constraint_split_ramp_up_indices(m)
    )
end

"""
    constraint_split_ramp_up_indices(m::Model; filtering_options...)

Form the stochastic indexing Array for the `:split_ramp_up` constraint.

Uses stochastic path indices due to potentially different stochastic scenarios between `t_after` and `t_before`.
Keyword arguments can be used to filter the resulting Array.
"""
function constraint_split_ramp_up_indices(
    m::Model;
    unit=anything,
    node=anything,
    direction=anything,
    stochastic_path=anything,
    t_before=anything,
    t_after=anything,
)
    unique(
        (unit=u, node=n, direction=d, stochastic_path=path, t_before=t_before, t_after=t_after)
        for
        (u, n, d, s, t_after) in unique(Iterators.flatten((
            ramp_up_unit_flow_indices(m; unit=unit, node=node, direction=direction, t=t_after),
            start_up_unit_flow_indices(m; unit=unit, node=node, direction=direction, t=t_after),
            nonspin_ramp_up_unit_flow_indices(m; unit=unit, node=node, direction=direction, t=t_after),
        ))) for (n, t_before, t_after) in node_dynamic_time_indices(m; node=n, t_before=t_before, t_after=t_after)
        for
        path in active_stochastic_paths(unique(
            ind.stochastic_scenario for ind in unit_flow_indices(m; unit=u, node=n, direction=d, t=[t_before, t_after])
        )) if path == stochastic_path || path in stochastic_path
    )
end
