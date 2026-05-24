@enumx Bus_type begin
    PQ = 0
    PV = 1
    Slack = 2
    P = 3
    PQV = 4
end

Base.@kwdef mutable struct Bus
    name::String = ""
    type::Bus_type.T = Bus_type.PQ
    # operative states
    voltage_magnitude::Float64 = 1.0 # p.u.
    voltage_angle::Float64 = 0.0 # rad
    active_power_load::Float64 = 0.0 # p.u.
    reactive_power_load::Float64 = 0.0 # p.u.
    active_power_generation::Float64 = 0.0 # p.u.
    reactive_power_generation::Float64 = 0.0 # p.u.
    # control
    controlled_bus::Int = 0 # controlled by reactive power injection
end

Base.@kwdef mutable struct Circuit
    name::String = ""
    from_bus_idx::Int = 0
    to_bus_idx::Int = 0
    resistance::Float64 = 0.0 # p.u.
    reactance::Float64 = 0.0 # p.u.
    shunt_conductance::Float64 = 0.0 # p.u.
    shunt_susceptance::Float64 = 0.0 # p.u.
    tap_ratio::Float64 = 1.0
    phase_shift::Float64 = 0.0 # rad
    # control
    controlled_bus::Int = 0 # controlled by tap transformer
end

Base.@kwdef mutable struct VoltageControlledByReactivePower
    controlling_bus_idx::Int = 0
    controlled_bus_idx::Int = 0
end

Base.@kwdef mutable struct VoltageControlledByTap
    controlling_circuit_idx::Int = 0
    controlling_bus_from_idx::Int = 0
    controlling_bus_to_idx::Int = 0
    controlled_bus_idx::Int = 0
end

Base.@kwdef mutable struct Caches
    voltage_controlled_by_reactive_power::Vector{VoltageControlledByReactivePower} = VoltageControlledByReactivePower[]
    voltage_controlled_by_tap::Vector{VoltageControlledByTap} = VoltageControlledByTap[]
end

Base.@kwdef mutable struct PowerFlowCase
    name::String = ""
    base_power::Float64 = 100.0 # MVA
    buses::Vector{Bus} = Bus[]
    circuits::Vector{Circuit} = Circuit[]
    max_iterations::Int = 100
    tolerance::Float64 = 1e-6
    log_path::String = ""
    caches::Caches = Caches()
end

function load_voltage_controlled_by_reactive_power!(power_flow_case::PowerFlowCase)
    for bus in power_flow_case.buses
        controlled_bus_idx = bus.controlled_bus
        if controlled_bus_idx != 0
            if !bus_is_p(bus)
                error("Only P buses can control voltage through reactive power. Bus $(bus.name) is of type $(bus.type) and controls bus $(controlled_bus_idx).")
            end
            if !bus_is_pqv(power_flow_case.buses[controlled_bus_idx])
                error("Only PQV buses can have their voltage controlled by reactive power. Bus $(power_flow_case.buses[controlled_bus_idx].name) is of type $(power_flow_case.buses[controlled_bus_idx].type) and is controlled by bus $(bus.name).")
            end
            push!(
                power_flow_case.caches.voltage_controlled_by_reactive_power,
                VoltageControlledByReactivePower(bus_idx, controlled_bus_idx),
            )
        end
    end
    return nothing
end

function load_voltage_controlled_by_tap!(power_flow_case::PowerFlowCase)
    for circuit in power_flow_case.circuits
        controlled_bus_idx = circuit.controlled_bus
        if controlled_bus_idx != 0
            if !bus_is_pqv(power_flow_case.buses[controlled_bus_idx])
                error("Only PQV buses can have their voltage controlled by tap transformers. Bus $(power_flow_case.buses[controlled_bus_idx].name) is of type $(power_flow_case.buses[controlled_bus_idx].type) and is controlled by circuit $(circuit.name).")
            end
            push!(
                power_flow_case.caches.voltage_controlled_by_tap,
                VoltageControlledByTap(
                    circuit_idx,
                    circuit.from_bus_idx,
                    circuit.to_bus_idx,
                    controlled_bus_idx,
                ),
            )
        end
    end
    return nothing
end

function PowerFlowCase(
    name::String = "",
    base_power::Float64 = 100.0, # MVA
    buses::Vector{Bus} = Bus[],
    circuits::Vector{Circuit} = Circuit[],
    max_iterations::Int = 100,
    tolerance::Float64 = 1e-6,
    log_path::String = "",
)
    pfc = PowerFlowCase(
        name,
        base_power,
        buses,
        circuits,
        max_iterations,
        tolerance,
        log_path,
    )
    load_voltage_controlled_by_reactive_power!(pfc)
    load_voltage_controlled_by_tap!(pfc)
    return pfc
end

function bus_is_pq(bus::Bus)
    return bus.type == Bus_type.PQ
end

function bus_is_pv(bus::Bus)
    return bus.type == Bus_type.PV
end

function bus_is_slack(bus::Bus)
    return bus.type == Bus_type.Slack
end

function bus_is_p(bus::Bus)
    return bus.type == Bus_type.P
end

function bus_is_pqv(bus::Bus)
    return bus.type == Bus_type.PQV
end

function pq_buses(power_flow_case::PowerFlowCase)
    return filter(bus -> bus_is_pq(bus), power_flow_case.buses)
end

function pv_buses(power_flow_case::PowerFlowCase)
    return filter(bus -> bus_is_pv(bus), power_flow_case.buses)
end

function slack_buses(power_flow_case::PowerFlowCase)
    return filter(bus -> bus_is_slack(bus), power_flow_case.buses)
end

function num_pq_buses(power_flow_case::PowerFlowCase)
    return length(pq_buses(power_flow_case))
end

function num_pv_buses(power_flow_case::PowerFlowCase)
    return length(pv_buses(power_flow_case))
end

function num_slack_buses(power_flow_case::PowerFlowCase)
    return length(slack_buses(power_flow_case))
end
