using Revise
using SpineModel
using SpineInterface
using JuMP

import SpineModel: duration

# E_Fuel[n=ExtrS,t=1:T], Pfuel[n,t] == (1/efficiency[n]) * (Pbeta[n]*P[n,t] + Qbeta[n]*Q[n,t])
### flow_coeff(cstr, CHP1, fuel) = 1
### flow_coeff(cstr, CHP1, elec) = (1/eff)*Pbeta
### flow_coeff(cstr, CHP1, heat) = (1/eff)*Qbeta
# E_Feasible2[n=ExtrS,t=1:T], Pbeta[n]*P[n,t] + Qbeta[n]*Q[n,t] >= Pbeta[n]*Pmin[n]*U[n,t]
### flow_coeff(cstr, CHP1, elec) = -Pbeta
### flow_coeff(cstr, CHP1, heat) = -Qbeta
### units_on_coeff(cstr, CHP1) = Pbeta*Pmin
# E_Feasible1[n=ExtrS,t=1:T], Pbeta[n]*P[n,t] + Qbeta[n]*Q[n,t] <= Pbeta[n]*Pmax[n]*U[n,t]
### flow_coeff(cstr, CHP1, elec) = Pbeta
### flow_coeff(cstr, CHP1, heat) = Qbeta
### units_on_coeff(cstr, CHP1) = -Pbeta*Pmax
# BP_OperationStatus[n=BckP,t=1:T], U[n,t] == M1[n,t] + M2[n,t] => M1[n,t] + M2[n,t] <= 1
### units_on_coeff(cstr, CHP8_CHP_mode) = 1
### units_on_coeff(cstr, CHP8_boiler_mode) = 1

function constraint_flow_affine_expr(m::Model)
    @fetch flow, units_on = m.ext[:variables]
    constr_dict = m.ext[:constraints][:flow_affine_expr] = Dict()
    for cstr in constraint()
        tblk = constraint__temporal_block(constraint=cstr)
        t_list = isempty(tblk) ? time_slice() : time_slice(temporal_block=tblk)
        for t in t_list
            expr = @expression(
                m,
                + sum(
                    sum(
                        flow[u, n, c, d, t1] * duration(t1) * flow_coeff(;x..., t=t1)
                        for (u, n, c, d, t1) in flow_indices(
                            unit=get(x, :unit, anything),
                            node=get(x, :node, anything),
                            commodity=get(x, :commodity, anything),
                            direction=get(x, :direction, anything),
                            t=t
                        )
                    )
                    for x in indices(flow_coeff; constraint=cstr)
                )
                + sum(
                    sum(
                        units_on[u, t1] * duration(t1) * units_on_coeff(;x..., t=t1)
                        for (u, t1) in units_on_indices(unit=get(x, :unit, anything), t=t)
                    )
                    for x in indices(units_on_coeff; constraint=cstr)
                )
                + const_term(constraint=cstr, t=t) * duration(t)
            )
            type_ = cstr_type(constraint=cstr)
            if type_ == :lt
                constr_dict[cstr, t] = @constraint(m, expr <= 0)
            elseif type_ == :eq
                constr_dict[cstr, t] = @constraint(m, expr == 0)
            end
        end
    end
end

function extend_model(m::Model)
    constraint_flow_affine_expr(m)
end


db_url_in = "sqlite:////home/manuelma/Codes/spine/toolbox/projects/case_study_a3/input/input.sqlite"
db_url_out = "sqlite:////home/manuelma/Codes/spine/toolbox/projects/case_study_a3/output/output.sqlite"
m = run_spinemodel(db_url_in, db_url_out; extend_model=extend_model)



# constraint_flow_capacity
##########################
# GT_PowerMax[n=GasT,t=1:T], P[n,t] <= Pmax[n]*U[n,t]
# HB_Max[n=HeatB,t=1:T], Q[n,t] <= Qmax[n]*U[n,t]
# BP_CHPModePowerMax[n=BckP,t=1:T], P[n,t] <= Pmax[n]*M1[n,t]
# BP_BoilerModeHeatMax[n=BckP,t=1:T], QM2[n,t] <= Qmax[n]*M2[n,t]
