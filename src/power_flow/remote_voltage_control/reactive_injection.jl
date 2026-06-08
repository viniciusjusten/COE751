function num_controlled_voltages_by_reactive_power(power_flow_case::PowerFlowCase)
    return length(power_flow_case.caches.voltage_controlled_by_reactive_power)
end

function buses_that_control_voltage_by_reactive_power(power_flow_case::PowerFlowCase)
    return [vbcq.controlling_bus_idx for vbcq in power_flow_case.caches.voltage_controlled_by_reactive_power]
end

function initialize_reactive_power_that_controls_voltage(
    power_flow_case::PowerFlowCase,
)
    n_bqv = num_controlled_voltages_by_reactive_power(power_flow_case)
    return zeros(n_bqv)
end

function update_reactive_injection_that_controls_voltage!(
    power_flow_case::PowerFlowCase,
    qg_vc::Vector{Float64},
)
    for i in eachindex(power_flow_case.caches.voltage_controlled_by_reactive_power)
        power_flow_case.caches.voltage_controlled_by_reactive_power[i].reactive_generation += qg_vc[i]
    end

    return nothing
end

function reactive_power_control_mismatch(
    power_flow_case::PowerFlowCase,
    Qcalc::Vector{Float64},
)
    qg_vc = [vbcq.reactive_generation for vbcq in power_flow_case.caches.voltage_controlled_by_reactive_power]
    qd = zeros(num_controlled_voltages_by_reactive_power(power_flow_case))
    qcalc = zeros(num_controlled_voltages_by_reactive_power(power_flow_case))
    for (i, vbcq) in enumerate(power_flow_case.caches.voltage_controlled_by_reactive_power)
        controlling_bus_idx = vbcq.controlling_bus_idx
        qd[i] = power_flow_case.buses[controlling_bus_idx].reactive_power_load

        qcalc[i] = Qcalc[controlling_bus_idx]
    end
    return qg_vc .- qd .- qcalc
end

function voltage_controlled_by_reactive_power_mismatch(
    power_flow_case::PowerFlowCase,
    voltages::Vector{Float64},
)
    mismatch = zeros(num_controlled_voltages_by_reactive_power(power_flow_case))
    for (i, vbcq) in enumerate(power_flow_case.caches.voltage_controlled_by_reactive_power)
        controlled_bus_idx = vbcq.controlled_bus_idx
        mismatch[i] = power_flow_case.buses[controlled_bus_idx].voltage_magnitude - voltages[controlled_bus_idx]
    end
    return mismatch
end
