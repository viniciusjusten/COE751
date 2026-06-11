function admittance(resistance::Float64, reactance::Float64)
    return 1 / (resistance + im * reactance)
end

function admittance_matrix(power_flow_case::PowerFlowCase)
    num_buses = length(power_flow_case.buses)
    circuits = power_flow_case.circuits
    Y = zeros(ComplexF64, num_buses, num_buses)
    for circuit in circuits
        from = circuit.from_bus_idx
        to = circuit.to_bus_idx
        y = admittance(circuit.resistance, circuit.reactance)
        Y[from, from] += y * circuit.tap_ratio^2 + circuit.shunt_conductance + im * circuit.shunt_susceptance
        Y[to, to] += y + circuit.shunt_conductance + im * circuit.shunt_susceptance
        Y[from, to] -= y * circuit.tap_ratio * exp(im * circuit.phase_shift)
        Y[to, from] -= y * circuit.tap_ratio * exp(-im * circuit.phase_shift)
    end
    for (i, bus) in enumerate(power_flow_case.buses)
        Y[i, i] += im * bus.shunt_susceptance
    end    
    return Y
end

function power_injection(
    voltage_magnitudes::Vector{Float64},
    voltage_angles::Vector{Float64},
    admittance::Matrix{ComplexF64},
)
    voltage = voltage_magnitudes .* exp.(im * voltage_angles)
    current_injection = admittance * voltage
    power_injection = voltage .* conj.(current_injection)
    return power_injection
end

function jacobian(
    power_flow_case::PowerFlowCase,
    Ybus::Matrix{ComplexF64},
    power_injection::Vector{ComplexF64},
    voltage_magnitudes::Vector{Float64},
    voltage_angles::Vector{Float64};
    reactive_power_voltage_control::Vector{Float64} = Float64[],
    tap_transformer_control::Vector{Float64} = Float64[],
)    
    P = real.(power_injection)
    Q = imag.(power_injection)

    G = real.(Ybus)
    B = imag.(Ybus)

    v = voltage_magnitudes
    a = voltage_angles

    # regular power flow Jacobian components
    num_buses = length(power_flow_case.buses)
    H = zeros(num_buses, num_buses)
    N = zeros(num_buses, num_buses)
    M = zeros(num_buses, num_buses)
    L = zeros(num_buses, num_buses)

    for i in 1:num_buses, j in 1:num_buses
        if i == j
            H[i, j] = -(Q[i] + v[i]^2 * B[i, i])
            N[i, j] = (P[i] + v[i]^2 * G[i, i]) / v[i]
            M[i, j] = P[i] - v[i]^2 * G[i, i]
            L[i, j] = (Q[i] - v[i]^2 * B[i, i]) / v[i]

            if bus_is_slack(power_flow_case.buses[i])
                H[i, j] = 1e12
                L[i, j] = 1e12
            end

            if bus_is_pv(power_flow_case.buses[i])
                L[i, j] = 1e12
            end
        else
            H[i, j] = v[i] * v[j] * (G[i, j] * sin(a[i] - a[j]) - B[i, j] * cos(a[i] - a[j]))
            N[i, j] = v[i] * (G[i, j] * cos(a[i] - a[j]) + B[i, j] * sin(a[i] - a[j]))
            M[i, j] = -v[i] * v[j] * (G[i, j] * cos(a[i] - a[j]) + B[i, j] * sin(a[i] - a[j]))
            L[i, j] = v[i] * (G[i, j] * sin(a[i] - a[j]) - B[i, j] * cos(a[i] - a[j]))
        end
    end

    # reactive power voltage control Jacobian components
    num_qgvc = length(reactive_power_voltage_control)
    dP_dQg = zeros(num_buses, num_qgvc)
    dQ_dQg = zeros(num_buses, num_qgvc)
    dV_dA = zeros(num_qgvc, num_buses)
    dV_dV = zeros(num_qgvc, num_buses)
    dV_dQg = zeros(num_qgvc, num_qgvc)

    for (i, vbcq) in enumerate(power_flow_case.caches.voltage_controlled_by_reactive_power)
        controlling_bus_idx = vbcq.controlling_bus_idx
        controlled_bus_idx = vbcq.controlled_bus_idx

        if vbcq.disabled
            dV_dQg[i, i] = 1e12
        else
            dQ_dQg[controlling_bus_idx, i] = -1.0
            dV_dV[i, controlled_bus_idx] = 1.0
        end
    end

    # tap transformer control Jacobian components
    num_tapvc = length(tap_transformer_control)
    dP_dTap = zeros(num_buses, num_tapvc)
    dQ_dTap = zeros(num_buses, num_tapvc)
    dV_dA_tap = zeros(num_tapvc, num_buses)
    dV_dV_tap = zeros(num_tapvc, num_buses)
    dV_dQg_tap = zeros(num_tapvc, num_qgvc)
    dV_dTap = zeros(num_tapvc, num_tapvc)
    dV_dTap_qg = zeros(num_qgvc, num_tapvc)

    circuits = power_flow_case.circuits
    for (i, vbct) in enumerate(power_flow_case.caches.voltage_controlled_by_tap)
        controlling_circuit_idx = vbct.controlling_circuit_idx
        controlling_bus_from_index = vbct.controlling_bus_from_idx
        controlling_bus_to_index = vbct.controlling_bus_to_idx
        controlled_bus_index = vbct.controlled_bus_idx

        tap = tap_transformer_control[i]
        resistance = circuits[controlling_circuit_idx].resistance
        reactance = circuits[controlling_circuit_idx].reactance
        y = admittance(resistance, reactance)
        g = real(y)
        b = imag(y)
        vk = v[controlling_bus_from_index]
        vm = v[controlling_bus_to_index]
        ak = a[controlling_bus_from_index]
        am = a[controlling_bus_to_index]

        dP_dTap[controlling_bus_from_index, i] =
            2 * tap * vk^2 * g -
            vk * vm * g * cos(ak - am) -
            vk * vm * b * sin(ak - am)
        dQ_dTap[controlling_bus_from_index, i] =
            - 2 * tap * vk^2 * b +
            vk * vm * b * cos(ak - am) -
            vk * vm * g * sin(ak - am)
        dP_dTap[controlling_bus_to_index, i] =
            - vk * vm * g * cos(ak - am) +
            vk * vm * b * sin(ak - am)
        dQ_dTap[controlling_bus_to_index, i] =
            vk * vm * b * cos(ak - am) +
            vk * vm * g * sin(ak - am)
        dV_dV_tap[i, controlled_bus_index] = 1.0
    end

    return [
        H N dP_dQg dP_dTap;
        M L dQ_dQg dQ_dTap;
        dV_dA dV_dV dV_dQg dV_dTap_qg;
        dV_dA_tap dV_dV_tap dV_dQg_tap dV_dTap;
    ]
end

# function active_power_injection(power_flow_case::PowerFlowCase, bus_idx::Int)
#     Ybus = admittance_matrix(power_flow_case)
#     Gbus = real.(Ybus)
#     Bbus = imag.(Ybus)
#     P = Gbus[bus_idx, bus_idx] * (power_flow_case.buses[bus_idx].voltage_magnitude)^2
#     for circuit in power_flow_case.circuits
#         if circuit.from_bus_idx == bus_idx
#             to_idx = circuit.to_bus_idx
#             P += Gbus[bus_idx, to_idx] *
#             power_flow_case.buses[bus_idx].voltage_magnitude * power_flow_case.buses[to_idx].voltage_magnitude *
#             cos(power_flow_case.buses[bus_idx].voltage_angle - power_flow_case.buses[to_idx].voltage_angle) +
#             Bbus[bus_idx, to_idx] * power_flow_case.buses[bus_idx].voltage_magnitude * power_flow_case.buses[to_idx].voltage_magnitude *
#             sin(power_flow_case.buses[bus_idx].voltage_angle - power_flow_case.buses[to_idx].voltage_angle)
#         end
#     end
#     return P
# end

# function reactive_power_injection(power_flow_case::PowerFlowCase, bus_idx::Int)
#     Ybus = admittance_matrix(power_flow_case)
#     Gbus = real.(Ybus)
#     Bbus = imag.(Ybus)
#     Q = -Bbus[bus_idx, bus_idx] * (power_flow_case.buses[bus_idx].voltage_magnitude)^2
#     for circuit in power_flow_case.circuits
#         if circuit.from_bus_idx == bus_idx
#             to_idx = circuit.to_bus_idx
#             Q += Gbus[bus_idx, to_idx] *
#             power_flow_case.buses[bus_idx].voltage_magnitude * power_flow_case.buses[to_idx].voltage_magnitude *
#             sin(power_flow_case.buses[bus_idx].voltage_angle - power_flow_case.buses[to_idx].voltage_angle) -
#             Bbus[bus_idx, to_idx] * power_flow_case.buses[bus_idx].voltage_magnitude * power_flow_case.buses[to_idx].voltage_magnitude *
#             cos(power_flow_case.buses[bus_idx].voltage_angle - power_flow_case.buses[to_idx].voltage_angle)
#         end
#     end
#     return Q
# end

function initialize_voltage_magnitude(power_flow_case::PowerFlowCase)
    v = zeros(length(power_flow_case.buses))

    for (i, bus) in enumerate(power_flow_case.buses)
        if bus_is_slack(bus) || bus_is_pv(bus)
            v[i] = bus.voltage_magnitude
        else
            v[i] = 1.0 # flat start
        end
    end

    return v
end

function initialize_voltage_angle(power_flow_case::PowerFlowCase)
    a = zeros(length(power_flow_case.buses))

    for (i, bus) in enumerate(power_flow_case.buses)
        if bus_is_slack(bus)
            a[i] = bus.voltage_angle
        else
            a[i] = 0.0 # flat start
        end
    end

    return a
end

function specified_power_injection(power_flow_case::PowerFlowCase)
    P = zeros(length(power_flow_case.buses))
    Q = zeros(length(power_flow_case.buses))

    for (i, bus) in enumerate(power_flow_case.buses)
        if bus_is_pq(bus) || bus_is_pv(bus) || bus_is_p(bus) || bus_is_pqv(bus)
            P[i] = bus.active_power_generation - bus.active_power_load
        end

        if bus_is_pq(bus) || bus_is_pqv(bus)
            Q[i] = bus.reactive_power_generation - bus.reactive_power_load
        end
    end

    return P, Q
end
