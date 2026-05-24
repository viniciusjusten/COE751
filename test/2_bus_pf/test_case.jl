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
        active_power_load = 0.3,
        reactive_power_load = -0.07,
    ),
]

circuits = [
    COE751.Circuit(
        name = "Line 1-2",
        from_bus_idx = 1,
        to_bus_idx = 2,
        resistance = 0.2,
        reactance = 1.0,
        shunt_susceptance = 0.02,
    ),
]

power_flow_case = COE751.PowerFlowCase(
    name = "2-bus system",
    base_power = 100.0,
    buses = buses,
    circuits = circuits,
    # log_path = joinpath(@__DIR__, "slides_pt2_ex2_pg_49_v2.solver"),
    tolerance = 1e-6,
    max_iterations = 20,
)

v, a = COE751.solve_power_flow(power_flow_case)

@testset "2-bus power flow" begin
    @test isapprox(v[1], 1.0; atol=1e-6)
    @test isapprox(a[1], 0.0; atol=1e-6)
    @test isapprox(v[2], 0.9751628372170976; atol=1e-6)
    @test isapprox(a[2], -0.331961594895515; atol=1e-6)
end