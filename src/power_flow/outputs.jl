function bus_results(
    power_flow_case::PowerFlowCase,
    v::Vector{Float64},
    a::Vector{Float64},
    P::Vector{Float64},
    Q::Vector{Float64},
)
    println("\n=============== Resultados: $(power_flow_case.name) ===============")
    println("Barra | Nome           | V (pu)  | θ (graus) |  P (MW)  | Q (Mvar)")
    println("------|----------------|---------|-----------|----------|----------")
    for (i, bus) in enumerate(power_flow_case.buses)
        @printf("%5d | %-14s |   %.3f | %8.1f  | %8.3f | %8.3f\n", i, bus.name, v[i], a[i], P[i], Q[i])
    end

    return nothing
end

function summary_per_bus(
    summary_path::String,
    power_flow_case::PowerFlowCase,
    v::Vector{Float64},
    a::Vector{Float64},
    P::Vector{Float64},
    Q::Vector{Float64},
)
    Sb = power_flow_case.base_power

    # mapeia barra controlada -> índice da barra controladora (tipo P)
    pqv_controller = Dict{Int,Int}()
    for (i, bus) in enumerate(power_flow_case.buses)
        if bus.controlled_bus != 0
            pqv_controller[bus.controlled_bus] = i
        end
    end

    # mapeia barra controlada -> VoltageControlledByTap
    tap_controller = Dict{Int,VoltageControlledByTap}()
    for vct in power_flow_case.caches.voltage_controlled_by_tap
        tap_controller[vct.controlled_bus_idx] = vct
    end

    open(summary_path, "w") do io
        println(io, "\n============================================================")
        println(io, "Sumário por Barra: IEEE 14 Bus - Caso 2 (QLIM em PV, CREM)")
        println(io, "============================================================")

        for (i, bus) in enumerate(power_flow_case.buses)
            Pl_MW   = bus.active_power_load         * Sb
            Ql_Mvar = bus.reactive_power_load       * Sb
            Pg_spec = bus.active_power_generation   * Sb
            Qg_spec = bus.reactive_power_generation * Sb
            Pg_calc = P[i] + Pl_MW      # P_inj = Pg - Pl  =>  Pg = P_inj + Pl
            Qg_calc = Q[i] + Ql_Mvar    # Q_inj = Qg - Ql  =>  Qg = Q_inj + Ql

            has_qlim  = isfinite(bus.min_reactive_power_injection) || isfinite(bus.max_reactive_power_injection)
            has_shunt = bus.shunt_susceptance != 0.0

            type_label = if bus.type == COE751.Bus_type.Slack
                "Slack"
            elseif bus.type == COE751.Bus_type.PV
                has_qlim ? "PV (com limite de Q)" : "PV"
            elseif bus.type == COE751.Bus_type.PQ
                has_shunt ? "PQ (com shunt)" : "PQ"
            elseif bus.type == COE751.Bus_type.PQV
                ctrl_i = get(pqv_controller, i, 0)
                if ctrl_i != 0
                    "PQV — tensão controlada pela barra $(lpad(ctrl_i, 2, '0')) ($(power_flow_case.buses[ctrl_i].name))"
                else
                    tap = tap_controller[i]
                    from_i = tap.controlling_bus_from_idx
                    to_i   = tap.controlling_bus_to_idx
                    "PQV — tensão controlada por transformador (barra $(lpad(from_i, 2, '0')) → barra $(lpad(to_i, 2, '0')))"
                end
            elseif bus.type == COE751.Bus_type.P
                cb = bus.controlled_bus
                "P/CREM — controla remotamente a barra $(lpad(cb, 2, '0')) ($(power_flow_case.buses[cb].name))"
            end

            println(io, "\nBarra $(lpad(i, 2, '0')) — $(bus.name) [$type_label]")

            if bus.type == COE751.Bus_type.Slack
                @printf(io, "  Especificado: V = %.3f pu  |  θ = %.1f° (referência)\n",
                    bus.voltage_magnitude, rad2deg(bus.voltage_angle))
                @printf(io, "  Calculado:    V = %.3f pu  |  θ = %7.3f°\n", v[i], a[i])
                @printf(io, "                P_inj = %8.3f MW   |  Q_inj = %8.3f Mvar  (injeção líquida)\n", P[i], Q[i])
                @printf(io, "                Pg    = %8.3f MW   |  Qg    = %8.3f Mvar  (geração)\n", Pg_calc, Qg_calc)

            elseif bus.type == COE751.Bus_type.PV
                # P totalmente especificado (Pg e Pl); Q: apenas Ql, Qg calculado
                P_inj_spec = Pg_spec - Pl_MW
                @printf(io, "  Especificado: V = %.3f pu\n", bus.voltage_magnitude)
                @printf(io, "                P: Pg = %8.3f MW   (geração)  |  Pl = %8.3f MW   (carga)  |  P_inj = %8.3f MW\n",
                    Pg_spec, Pl_MW, P_inj_spec)
                @printf(io, "                Q:                              |  Ql = %8.3f Mvar (carga)  [Qg calculado]\n",
                    Ql_Mvar)
                if has_qlim
                    qmin_s = isfinite(bus.min_reactive_power_injection) ?
                        @sprintf("%.1f", bus.min_reactive_power_injection * Sb) : "-Inf"
                    qmax_s = isfinite(bus.max_reactive_power_injection) ?
                        @sprintf("%.1f", bus.max_reactive_power_injection * Sb) : "+Inf"
                    println(io, "                Qlim = [$qmin_s, $qmax_s] Mvar")
                end
                @printf(io, "  Calculado:    V = %.3f pu  |  θ = %7.3f°\n", v[i], a[i])
                @printf(io, "                P_inj = %8.3f MW   |  Q_inj = %8.3f Mvar  (injeção líquida)\n", P[i], Q[i])
                @printf(io, "                Pg    = %8.3f MW   |  Qg    = %8.3f Mvar  (geração)\n", Pg_calc, Qg_calc)

            elseif bus.type == COE751.Bus_type.PQ
                # P e Q totalmente especificados
                P_inj_spec = Pg_spec - Pl_MW
                Q_inj_spec = Qg_spec - Ql_Mvar
                @printf(io, "  Especificado: P: Pg = %8.3f MW   (geração)  |  Pl = %8.3f MW   (carga)  |  P_inj = %8.3f MW\n",
                    Pg_spec, Pl_MW, P_inj_spec)
                @printf(io, "                Q: Qg = %8.3f Mvar (geração)  |  Ql = %8.3f Mvar (carga)  |  Q_inj = %8.3f Mvar\n",
                    Qg_spec, Ql_Mvar, Q_inj_spec)
                if has_shunt
                    @printf(io, "                Shunt capacitivo: B = %.3f pu = %.1f Mvar (a V = 1 pu)\n",
                        bus.shunt_susceptance, bus.shunt_susceptance * Sb)
                end
                @printf(io, "  Calculado:    V = %.3f pu  |  θ = %7.3f°\n", v[i], a[i])
                @printf(io, "                P_inj = %8.3f MW   |  Q_inj = %8.3f Mvar  (injeção líquida)\n", P[i], Q[i])

            elseif bus.type == COE751.Bus_type.PQV
                # P e Q totalmente especificados; V fixo por controle remoto ou transformador
                P_inj_spec = Pg_spec - Pl_MW
                Q_inj_spec = Qg_spec - Ql_Mvar
                ctrl_i = get(pqv_controller, i, 0)
                if ctrl_i != 0
                    @printf(io, "  Especificado: V = %.3f pu (controlada pela barra %s — %s)\n",
                        bus.voltage_magnitude, lpad(ctrl_i, 2, '0'), power_flow_case.buses[ctrl_i].name)
                else
                    tap    = tap_controller[i]
                    from_i = tap.controlling_bus_from_idx
                    to_i   = tap.controlling_bus_to_idx
                    @printf(io, "  Especificado: V = %.3f pu (controlada por transformador: barra %s → barra %s)\n",
                        bus.voltage_magnitude, lpad(from_i, 2, '0'), lpad(to_i, 2, '0'))
                end
                @printf(io, "                P: Pg = %8.3f MW   (geração)  |  Pl = %8.3f MW   (carga)  |  P_inj = %8.3f MW\n",
                    Pg_spec, Pl_MW, P_inj_spec)
                @printf(io, "                Q: Qg = %8.3f Mvar (geração)  |  Ql = %8.3f Mvar (carga)  |  Q_inj = %8.3f Mvar\n",
                    Qg_spec, Ql_Mvar, Q_inj_spec)
                @printf(io, "  Calculado:    V = %.3f pu  |  θ = %7.3f°\n", v[i], a[i])
                @printf(io, "                P_inj = %8.3f MW   |  Q_inj = %8.3f Mvar  (injeção líquida)\n", P[i], Q[i])

            elseif bus.type == COE751.Bus_type.P
                # P especificado (Pg e Pl); Qg calculado pelo controle remoto de tensão
                P_inj_spec = Pg_spec - Pl_MW
                @printf(io, "  Especificado: P: Pg = %8.3f MW   (geração)  |  Pl = %8.3f MW   (carga)  |  P_inj = %8.3f MW\n",
                    Pg_spec, Pl_MW, P_inj_spec)
                if Ql_Mvar != 0.0
                    @printf(io, "                Q:                              |  Ql = %8.3f Mvar (carga)  [Qg calculado]\n",
                        Ql_Mvar)
                end
                @printf(io, "  Calculado:    V = %.3f pu  |  θ = %7.3f°\n", v[i], a[i])
                @printf(io, "                P_inj = %8.3f MW   |  Q_inj = %8.3f Mvar  (injeção líquida)\n", P[i], Q[i])
                @printf(io, "                Pg    = %8.3f MW   |  Qg    = %8.3f Mvar  (geração)\n", Pg_calc, Qg_calc)
            end
        end
        println(io, "")
    end

    return nothing
end
