The definition of the `min_up_time` parameter will trigger the creation of the [Constraint on minimum up time](@ref constraint_min_up_time). It sets a lower bound on the period that a unit has to stay online after a startup.

It can be defined for a [unit](@ref) and will then impose restrictions on the [units\_on](@ref) variables that represent the on- or offline status of the unit. The parameter is given as a duration value. When the parameter is not included, the aforementioned constraint will not be created, which is equivalent to choosing a value of 0.

For a more complete description of unit commmitment restrictions, see [Unit commitment](@ref).
