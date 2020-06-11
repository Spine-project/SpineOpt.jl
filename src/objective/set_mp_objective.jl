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

"""
    set_objective!(m::Model)

Minimize the total discounted costs, corresponding to the sum over all
cost terms.
"""

"""
    set_objective!(m::Model)

Minimize the total error between target and representative distributions.
"""
function set_mp_objective!(m::Model)
    @fetch mp_objective_lowerbound = m.ext[:variables]
    @objective(m, Min,
        + mp_objective_lowerbound
    )
end


"""
    add_constraint_units_on!(m::Model, units_on, units_available)

Limit the units_on by the number of available units.
"""
function add_constraint_mp_objective!(m::Model)
    @fetch units_on, units_available = m.ext[:variables]
    constr_dict = m.ext[:constraints][:mp_objective] = Dict()    
    constr_dict] = @constraint(
            m,
            + mp_objective_lowerbound
            <=
            + expr_sum(
                mp_units_invested[u, s, t] * unit_investment_cost(unit=u, t=t)
                for (u, s, t) in mp_units_invested_available_indices();
                init=0
            )
        )
    
end
