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

power_flow_case = COE751.build_power_flow_case(
    name = "3-bus system",
    base_power = 100.0,
    buses = buses,
    circuits = circuits,
    tolerance = 1e-6,
    max_iterations = 20,
)

v, a = COE751.solve_power_flow(power_flow_case)

@testset "3-bus power flow" begin
    @test isapprox(v[1], 1.0; atol=1e-6)
    @test isapprox(a[1], 0.0; atol=1e-6)
    @test isapprox(v[2], 0.9827352748157293; atol=1e-6)
    @test isapprox(a[2], -0.11528763833756042; atol=1e-6)
    @test isapprox(v[3], 0.98; atol=1e-6)
    @test isapprox(a[3], -0.1808690118245363; atol=1e-6)
end
