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
    res_proc_costs(m::Model)

Add expression for reserve procurement costs.
"""
function res_proc_costs(m::Model,t1)
    @fetch unit_flow = m.ext[:variables]
    t0 = start(current_window(m))
    @expression(
        m,
        expr_sum(
            unit_flow[u, n, d, s, t] * duration(t)
            * reserve_procurement_cost[(node=n, stochastic_scenario=s, analysis_time=t0, t=t)]
            * node_stochastic_scenario_weight[(node=n, stochastic_scenario=s)]
            for n in indices(reserve_procurement_cost)  # TODO: change this to (u, n, d) indices
            for (u, n, d, s, t) in unit_flow_indices(m; node=n)
            if end_(t) <= t1;
            init=0
        )
    )
end