buses = [
    COE751.Bus(
        name = "Bus 1",
        type = COE751.Bus_type.Slack,
        voltage_magnitude = 1.0,
        voltage_angle = 0.0,
    ),
    COE751.Bus(
        name = "Bus 2",
        type = COE751.Bus_type.PQ,
        active_power_load = 0.05,
        reactive_power_load = 0.02,
    ),
    COE751.Bus(
        name = "Bus 3",
        type = COE751.Bus_type.PV,
        active_power_load = 0.15,
        voltage_magnitude = 0.98,
    ),
]

circuits = [
    COE751.Circuit(
        name = "Line 1-2",
        from_bus_idx = 1,
        to_bus_idx = 2,
        resistance = 0.1,
        reactance = 1.0,
        shunt_susceptance = 0.01,
    ),
    COE751.Circuit(
        name = "Line 1-3",
        from_bus_idx = 1,
        to_bus_idx = 3,
        resistance = 0.2,
        reactance = 2.0,
        shunt_susceptance = 0.02,
    ),
    COE751.Circuit(
        name = "Line 2-3",
        from_bus_idx = 2,
        to_bus_idx = 3,
        resistance = 0.1,
        reactance = 1.0,
        shunt_susceptance = 0.01,
    ),
]

power_flow_case = COE751.PowerFlowCase(
    name = "3-bus system",
    base_power = 100.0,
    buses = buses,
    circuits = circuits,
    log_path = joinpath(@__DIR__, "monticelli_chap_5.solver"),
    tolerance = 1e-6,
    max_iterations = 20,
)

v, a = COE751.solve_power_flow(power_flow_case)
