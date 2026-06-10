function num_buses_with_reactive_power_limits(power_flow_case::PowerFlowCase)
    return length(power_flow_case.caches.limited_reactive_power_injection)
end

function case_has_any_reactive_power_limit(power_flow_case::PowerFlowCase)
    return !isempty(power_flow_case.caches.limited_reactive_power_injection)
end

function reactive_power_limits!(
    power_flow_case::PowerFlowCase,
    Qcalc::Vector{Float64},
)
    for limit in power_flow_case.caches.limited_reactive_power_injection
        bus_idx = limit.bus_idx
        Qg = Qcalc[bus_idx] + power_flow_case.buses[bus_idx].reactive_power_load
        @info("barra $(bus_idx)")
        @info("Qg: $(Qg)")
        @info("Limites: [$(limit.min_reactive_power_injection), $(limit.max_reactive_power_injection)]")
        if limit.skip_limit_check
            continue
        end
        tol = power_flow_case.tolerance
        Qmin = limit.min_reactive_power_injection
        Qmax = limit.max_reactive_power_injection
        if Qg < Qmin - tol || Qg < Qmin + tol
            @info("  Limit violation: Below minimum")
            limit.limit_violation = LimitViolation.BelowMinimum
            power_flow_case.buses[bus_idx].type = Bus_type.PQ
        elseif Qg > Qmax - tol || Qg > Qmax + tol
            @info("  Limit violation: Above maximum")
            limit.limit_violation = LimitViolation.AboveMaximum
            power_flow_case.buses[bus_idx].type = Bus_type.PQ
        # else
        #     limit.limit_violation = LimitViolation.NoViolation
        end
    end
    return nothing
end

function update_Q_lim_mismatch(
    power_flow_case::PowerFlowCase,
    Q_mismatch::Vector{Float64},
    Qcalc::Vector{Float64},
)
    for limit in power_flow_case.caches.limited_reactive_power_injection
        bus_idx = limit.bus_idx
        if limit.limit_violation == LimitViolation.BelowMinimum
            Q_mismatch[bus_idx] = limit.min_reactive_power_injection - power_flow_case.buses[bus_idx].reactive_power_load - Qcalc[bus_idx]
        elseif limit.limit_violation == LimitViolation.AboveMaximum
            Q_mismatch[bus_idx] = limit.max_reactive_power_injection - power_flow_case.buses[bus_idx].reactive_power_load - Qcalc[bus_idx]
        end
    end
    return Q_mismatch
end

function check_if_PQ_buses_can_go_back_to_PV!(
    power_flow_case::PowerFlowCase,
    voltage_magnitudes::Vector{Float64},
)
    for limit in power_flow_case.caches.limited_reactive_power_injection
        bus_idx = limit.bus_idx
        @info("Check de tensão")
        @info("barra $(bus_idx)")
        @info("tensão: $(voltage_magnitudes[bus_idx])")
        @info("tensão especificada: $(power_flow_case.buses[bus_idx].voltage_magnitude))")
        vcalc = voltage_magnitudes[bus_idx]
        vesp = power_flow_case.buses[bus_idx].voltage_magnitude
        tol = power_flow_case.tolerance
        if limit.limit_violation == LimitViolation.BelowMinimum
            if vcalc < vesp - tol || vcalc < vesp + tol
                # bus can go back to being PV
                power_flow_case.buses[bus_idx].type = Bus_type.PV
                limit.skip_limit_check = true
                @info("  Bus $(bus_idx) can go back to PV")
            end
        end
        if limit.limit_violation == LimitViolation.AboveMaximum
            if vcalc > vesp - tol || vcalc > vesp + tol
                # bus can go back to being PV
                power_flow_case.buses[bus_idx].type = Bus_type.PV
                limit.skip_limit_check = true
                @info("  Bus $(bus_idx) can go back to PV")
            end
        end
    end
    return nothing
end

function bus_with_reactive_power_limits_satisfies_voltage(
    power_flow_case::PowerFlowCase,
    voltage_magnitude::Vector{Float64},
    tolerance::Float64,
)
    voltage_error = zeros(num_buses_with_reactive_power_limits(power_flow_case))
    if isempty(power_flow_case.caches.limited_reactive_power_injection)
        return true
    end
    for (i, limit) in enumerate(power_flow_case.caches.limited_reactive_power_injection)
        bus_idx = limit.bus_idx
        specified_voltage = power_flow_case.buses[bus_idx].voltage_magnitude
        voltage_error[i] = voltage_magnitude[bus_idx] - specified_voltage
    end
    return maximum(abs.(voltage_error)) < tolerance
end
