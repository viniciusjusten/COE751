function num_controlled_voltages_by_tap(power_flow_case::PowerFlowCase)
    return length(power_flow_case.caches.voltage_controlled_by_tap)
end

function initialize_tap_transformer_control(power_flow_case::PowerFlowCase)
    tap_control = zeros(num_controlled_voltages_by_tap(power_flow_case))
    for (i, vbct) in enumerate(power_flow_case.caches.voltage_controlled_by_tap)
        tap_control[i] = power_flow_case.circuits[vbct.controlling_circuit_idx].tap_ratio
    end
    return tap_control
end

function voltage_controlled_by_tap_mismatch(
    power_flow_case::PowerFlowCase,
    voltages::Vector{Float64},
)
    mismatch = zeros(num_controlled_voltages_by_tap(power_flow_case))
    for (i, vbct) in enumerate(power_flow_case.caches.voltage_controlled_by_tap)
        controlled_bus_index = vbct.controlled_bus_idx
        mismatch[i] = power_flow_case.buses[controlled_bus_index].voltage_magnitude - voltages[controlled_bus_index]
    end
    return mismatch
end

function update_tap_transformer_admittances(
    Ybus::Matrix{ComplexF64},
    power_flow_case::PowerFlowCase,
    previous_tap::Vector{Float64},
    tap_vc::Vector{Float64},
)
    for (i, vbct) in enumerate(power_flow_case.caches.voltage_controlled_by_tap)
        circuit_idx = vbct.controlling_circuit_idx
        from_idx = vbct.controlling_bus_from_idx
        to_idx = vbct.controlling_bus_to_idx
        
        previous_tap_ratio = previous_tap[i]
        tap_ratio = tap_vc[i]

        resistance = power_flow_case.circuits[circuit_idx].resistance
        reactance = power_flow_case.circuits[circuit_idx].reactance
        y = admittance(resistance, reactance)

        # remove previous tap ratio effects from Ybus
        Ybus[from_idx, from_idx] -= previous_tap_ratio^2 * y
        Ybus[from_idx, to_idx] += previous_tap_ratio * y
        Ybus[to_idx, from_idx] += previous_tap_ratio * y

        # update Ybus entries for the circuit based on the current tap ratio
        Ybus[from_idx, from_idx] += tap_ratio^2 * y
        Ybus[from_idx, to_idx] -= tap_ratio * y
        Ybus[to_idx, from_idx] -= tap_ratio * y
    end
    return Ybus
end
