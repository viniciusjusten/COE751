# IEEE 14 Bus Test Case - Winter 1962
# Caso 1: CREM ativo (controle remoto de tensão por injeção reativa)
# Dados extraídos do arquivo IEEE14_Caso1.pwf (ANAREDE/CEPEL)
# Potência base: 100 MVA
#
# CREM ativo:
#   Barra 6 (tipo P): controla remotamente a tensão da barra 12 (PQV) em 1.070 pu
#   Barra 8 (tipo P): controla remotamente a tensão da barra 7 (PQV) em 1.090 pu
#
# Shunt de linha (modelo pi):
#   shunt_susceptance = Bsh_total/2 (pu), pois admittance_matrix soma em CADA extremidade
#   Bsh_total = Mvar_PWF / 100
#
# Shunt de barra 9: Sh = 19 Mvar = 0.19 pu

using Printf

buses = [
    COE751.Bus(
        name = "Barra-01--HV",
        type = COE751.Bus_type.Slack,
        voltage_magnitude = 1.060,
        voltage_angle = 0.0,
    ),
    COE751.Bus(
        name = "Barra-02--HV",
        type = COE751.Bus_type.PV,
        voltage_magnitude = 1.045,
        active_power_generation = 0.400,
        active_power_load = 0.217,
        min_reactive_power_injection = -0.4,
        max_reactive_power_injection = 0.5,
    ),
    COE751.Bus(
        name = "Barra-03--HV",
        type = COE751.Bus_type.PV,
        voltage_magnitude = 1.010,
        active_power_generation = 0.0,
        active_power_load = 0.942,
        min_reactive_power_injection = 0.0,
        max_reactive_power_injection = 0.4,
    ),
    COE751.Bus(
        name = "Barra-04--HV",
        type = COE751.Bus_type.PQ,
        active_power_load = 0.478,
        reactive_power_load = -0.039,
    ),
    COE751.Bus(
        name = "Barra-05--HV",
        type = COE751.Bus_type.PQ,
        active_power_load = 0.076,
        reactive_power_load = 0.016,
    ),
    COE751.Bus(
        name = "Barra-06--LV",
        type = COE751.Bus_type.P,
        voltage_magnitude = 1.070,
        # active_power_generation = 0.0,
        # active_power_load = 0.112,
        # reactive_power_load = 0.075,
        controlled_bus = 12,
        min_reactive_power_injection = -0.06,
        max_reactive_power_injection = 0.24,
    ),
    COE751.Bus(
        name = "Barra-07--ZV",
        type = COE751.Bus_type.PQV,
        voltage_magnitude = 1.000,
        active_power_generation = 0.0,
        reactive_power_generation = 0.0,
        active_power_load = 0.0,
        reactive_power_load = 0.0,
    ),
    COE751.Bus(
        name = "Barra-08--TV",
        type = COE751.Bus_type.P,
        voltage_magnitude = 1.090,
        active_power_generation = 0.0,
        # reactive_power_generation = -0.276,
        active_power_load = 0.0,
        # reactive_power_load = 0.0,
        controlled_bus = 7,
        min_reactive_power_injection = -0.06,
        max_reactive_power_injection = 0.24,
    ),
    COE751.Bus(
        name = "Barra-09--LV",
        type = COE751.Bus_type.PQ,
        active_power_generation = 0.0,
        reactive_power_generation = 0.0,
        active_power_load = 0.295,
        reactive_power_load = 0.166,
        shunt_susceptance = 0.19,
    ),
    COE751.Bus(
        name = "Barra-10--LV",
        type = COE751.Bus_type.PQ,
        active_power_generation = 0.0,
        reactive_power_generation = 0.0,
        active_power_load = 0.090,
        reactive_power_load = 0.058,
    ),
    COE751.Bus(
        name = "Barra-11--LV",
        type = COE751.Bus_type.PQ,
        active_power_generation = 0.0,
        reactive_power_generation = 0.0,
        active_power_load = 0.035,
        reactive_power_load = 0.018,
    ),
    COE751.Bus(
        name = "Barra-12--LV",
        type = COE751.Bus_type.PQV,
        voltage_magnitude = 1.070,
        active_power_generation = 0.0,
        reactive_power_generation = 0.0,
        active_power_load = 0.061,
        reactive_power_load = 0.016,
    ),
    COE751.Bus(
        name = "Barra-13--LV",
        type = COE751.Bus_type.PQ,
        active_power_generation = 0.0,
        reactive_power_generation = 0.0,
        active_power_load = 0.135,
        reactive_power_load = 0.058,
    ),
    COE751.Bus(
        name = "Barra-14--LV",
        type = COE751.Bus_type.PQ,
        active_power_generation = 0.0,
        reactive_power_generation = 0.0,
        active_power_load = 0.149,
        reactive_power_load = 0.050,
    ),
]

circuits = [
    # Linhas de transmissão
    # shunt_susceptance = Bsh_total/2 (pu) pois admittance_matrix soma em CADA extremidade
    # Bsh_total = Mvar_PWF / 100
    COE751.Circuit(name = "L1-2",   from_bus_idx =  1, to_bus_idx =  2, resistance = 0.01938, reactance = 0.05917, shunt_susceptance = 0.0264),
    COE751.Circuit(name = "L1-5",   from_bus_idx =  1, to_bus_idx =  5, resistance = 0.05403, reactance = 0.22304, shunt_susceptance = 0.0246),
    COE751.Circuit(name = "L2-3",   from_bus_idx =  2, to_bus_idx =  3, resistance = 0.04699, reactance = 0.19797, shunt_susceptance = 0.0219),
    COE751.Circuit(name = "L2-4",   from_bus_idx =  2, to_bus_idx =  4, resistance = 0.05811, reactance = 0.17632, shunt_susceptance = 0.0170),
    COE751.Circuit(name = "L2-5",   from_bus_idx =  2, to_bus_idx =  5, resistance = 0.05695, reactance = 0.17388, shunt_susceptance = 0.0173),
    COE751.Circuit(name = "L3-4",   from_bus_idx =  3, to_bus_idx =  4, resistance = 0.06701, reactance = 0.17103, shunt_susceptance = 0.0064),
    COE751.Circuit(name = "L4-5",   from_bus_idx =  4, to_bus_idx =  5, resistance = 0.01335, reactance = 0.04211),
    # Transformadores com tap fixo
    COE751.Circuit(name = "T4-7",   from_bus_idx =  4, to_bus_idx =  7, resistance = 0.0, reactance = 0.20912, tap_ratio = 1/0.978),
    COE751.Circuit(name = "T4-9",   from_bus_idx =  4, to_bus_idx =  9, resistance = 0.0, reactance = 0.55618, tap_ratio = 1/0.969),
    COE751.Circuit(name = "T5-6",   from_bus_idx =  5, to_bus_idx =  6, resistance = 0.0, reactance = 0.25202, tap_ratio = 1/0.932),
    COE751.Circuit(name = "L6-11",  from_bus_idx =  6, to_bus_idx = 11, resistance = 0.09498, reactance = 0.19890),
    COE751.Circuit(name = "L6-12",  from_bus_idx =  6, to_bus_idx = 12, resistance = 0.12291, reactance = 0.25581),
    COE751.Circuit(name = "L6-13",  from_bus_idx =  6, to_bus_idx = 13, resistance = 0.06615, reactance = 0.13027),
    COE751.Circuit(name = "T7-8",   from_bus_idx =  7, to_bus_idx =  8, resistance = 0.0,     reactance = 0.17615),
    COE751.Circuit(name = "T7-9",   from_bus_idx =  7, to_bus_idx =  9, resistance = 0.0,     reactance = 0.11001),
    COE751.Circuit(name = "L9-10",  from_bus_idx =  9, to_bus_idx = 10, resistance = 0.03181, reactance = 0.08450),
    COE751.Circuit(name = "L9-14",  from_bus_idx =  9, to_bus_idx = 14, resistance = 0.12711, reactance = 0.27038),
    COE751.Circuit(name = "L10-11", from_bus_idx = 10, to_bus_idx = 11, resistance = 0.08205, reactance = 0.19207),
    COE751.Circuit(name = "L12-13", from_bus_idx = 12, to_bus_idx = 13, resistance = 0.22092, reactance = 0.19988),
    COE751.Circuit(name = "L13-14", from_bus_idx = 13, to_bus_idx = 14, resistance = 0.17093, reactance = 0.34802),
]

power_flow_case = COE751.build_power_flow_case(
    name = "IEEE 14 Bus - Caso 1 (CREM)",
    base_power = 100.0,
    buses = buses,
    circuits = circuits,
    log_path = joinpath(@__DIR__, "ieee14.solver"),
    tolerance = 1e-3,
    max_iterations = 20,
)

_v, _a = COE751.solve_power_flow(power_flow_case)
Ybus = COE751.admittance_matrix(power_flow_case)
Sinj = COE751.power_injection(_v, _a, Ybus)
Pinj = real.(Sinj)
Qinj = imag.(Sinj)

P = power_flow_case.base_power * Pinj
Q = power_flow_case.base_power * Qinj

v = round.(_v, digits=3)
a = round.(rad2deg.(_a), digits=1)

COE751.bus_results(
    power_flow_case,
    v,
    a,
    P,
    Q,
)

summary_path = joinpath(@__DIR__, "res_barra.sum")
COE751.summary_per_bus(
    summary_path,
    power_flow_case,
    v,
    a,
    P,
    Q,
)

consistent = COE751.validate_power_flow_solution(power_flow_case, _v, _a)
if consistent
    println()
    println("Dados calculados consistentes com os especificados")
end
