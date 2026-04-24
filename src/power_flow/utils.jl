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
        Y[from, from] += y + circuit.shunt_conductance + im * circuit.shunt_susceptance
        Y[to, to] += y + circuit.shunt_conductance + im * circuit.shunt_susceptance
        Y[from, to] -= y * circuit.tap_ratio * exp(im * circuit.phase_shift)
        Y[to, from] -= y * circuit.tap_ratio * exp(-im * circuit.phase_shift)
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
    admittance::Matrix{ComplexF64},
    power_injection::Vector{ComplexF64},
    voltage_magnitudes::Vector{Float64},
    voltage_angles::Vector{Float64},
)    
    P = real.(power_injection)
    Q = imag.(power_injection)

    G = real.(admittance)
    B = imag.(admittance)

    v = voltage_magnitudes
    a = voltage_angles

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

    return [H N; M L]
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
        if bus_is_pq(bus) || bus_is_pv(bus)
            P[i] = bus.active_power_generation - bus.active_power_load
        end
        
        if bus_is_pq(bus)
            Q[i] = bus.reactive_power_generation - bus.reactive_power_load
        end
    end

    return P, Q
end
