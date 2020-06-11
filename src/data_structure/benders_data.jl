#############################################################################
# Copyright (C) 2017 - 2020  Spine Project
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


function process_benders_data(m, j)
    add_benders_iteration(j)
    fix_mp_variables_sp(m, j)

end


function add_benders_iteration(j)
    add_object!(benders_iteration, Symbol(string("bi_", j)))
end

"""
    fix_mp_variables_sp(m, j)

Fix the value of the master problem variables in the sub problems by creating a timeseries parameter for the fix_value
    based on the result of the master problem solve values
"""

function fix_mp_variables_sp(m, j)
    for u in indices(canidate_units)
        time_indices = [start(inds.t)] for inds in mp_units_invested_available_indices(unit=u)
        vals = [m.ext[:values][:mp_units_invested_available][inds]] for inds in mp_units_invested_available_indices(unit=u)
        unit.parameter_values[u][:fix_units_invested_available] = parameter_value(TimeSeries(time_indices, vals, false, false))
    end
end
