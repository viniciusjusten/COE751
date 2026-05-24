function num_controlled_voltages_by_reactive_power(power_flow_case::PowerFlowCase)
    return length(power_flow_case.caches.voltage_controlled_by_reactive_power)
end

function buses_that_control_voltage_by_reactive_power(power_flow_case::PowerFlowCase)
    return [vbcq.controlling_bus_index for vbcq in power_flow_case.caches.voltage_controlled_by_reactive_power]
end

function initialize_reactive_power_that_controls_voltage(
    power_flow_case::PowerFlowCase,
)
    n_bqv = num_controlled_voltages_by_reactive_power(power_flow_case)
    return zeros(n_bqv)
end

function reactive_power_control_mismatch(
    power_flow_case::PowerFlowCase,
    Qcalc::Vector{Float64},
    qg_vc::Vector{Float64},
)
    qd = zeros(num_controlled_voltages_by_reactive_power(power_flow_case))
    qcalc = zeros(num_controlled_voltages_by_reactive_power(power_flow_case))
    for (i, vbcq) in enumerate(power_flow_case.caches.voltage_controlled_by_reactive_power)
        controlling_bus_index = vbcq.controlling_bus_index
        qd[i] = power_flow_case.buses[controlling_bus_index].reactive_power_load

        controlled_bus_index = vbcq.controlled_bus_index
        qcalc[i] = Qcalc[controlled_bus_index]
    end
    return qg_vc .- qd .- qcalc
end
