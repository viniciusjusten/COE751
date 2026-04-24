@enumx Bus_type begin
    PQ = 0
    PV = 1
    Slack = 2
end

Base.@kwdef mutable struct Bus
    name::String = ""
    type::Bus_type.T = Bus_type.PQ # 1: PQ, 2: PV, 3: Slack
    # operative states
    voltage_magnitude::Float64 = 1.0 # p.u.
    voltage_angle::Float64 = 0.0 # rad
    active_power_load::Float64 = 0.0 # p.u.
    reactive_power_load::Float64 = 0.0 # p.u.
    active_power_generation::Float64 = 0.0 # p.u.
    reactive_power_generation::Float64 = 0.0 # p.u.
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
end

Base.@kwdef mutable struct PowerFlowCase
    name::String = ""
    base_power::Float64 = 100.0 # MVA
    buses::Vector{Bus} = Bus[]
    circuits::Vector{Circuit} = Circuit[]
    max_iterations::Int = 100
    tolerance::Float64 = 1e-6
    log_path::String = ""
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
