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
        if Qcalc[bus_idx] < limit.min_reactive_power_injection
            limit.limit_violation = LimitViolation.BelowMinimum
            power_flow_case.buses[bus_idx].type = Bus_type.PQ
        elseif Qcalc[bus_idx] > limit.max_reactive_power_injection
            limit.limit_violation = LimitViolation.AboveMaximum
            power_flow_case.buses[bus_idx].type = Bus_type.PQ
        else
            limit.limit_violation = LimitViolation.NoViolation
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
        if limit.limit_violation == LimitViolation.BelowMinimum
            if voltage_magnitudes[bus_idx] < power_flow_case.buses[bus_idx].voltage_magnitude
                # bus can go back to being PV
                power_flow_case.buses[bus_idx].type = Bus_type.PV
            end
        end
        if limit.limit_violation == LimitViolation.AboveMaximum
            if voltage_magnitudes[bus_idx] > power_flow_case.buses[bus_idx].voltage_magnitude
                # bus can go back to being PV
                power_flow_case.buses[bus_idx].type = Bus_type.PV
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
