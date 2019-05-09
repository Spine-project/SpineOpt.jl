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
    constraint_commitment_variables(m::Model)

This constraint ensures consistency between the variables `units_on`, `units_started_up`
and `units_shut_down`.
"""
# Can we think of a more generic name than commitment variables?

function constraint_commitment_variables(m::Model)
    @fetch units_on, units_started_up, units_shut_down = m.ext[:variables]
    for (u, t_after) in units_on_indices()
        for t_before in t_before_t(t_after=t_after)
            if !isempty(t_before) && t_before in [t for (u,t) in units_on_indices(unit=u)]
                @constraint(
                    m,
                    + units_on[u, t_after]
                    ==
                    + units_on[u, t_before]
                    + units_started_up[u, t_after] - units_shut_down[u, t_after]
                )
            end
        end
    end
end
