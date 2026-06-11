function num_buses_with_reactive_power_limits(power_flow_case::PowerFlowCase)
    return length(power_flow_case.caches.limited_reactive_power_injection)
end

function case_has_any_reactive_power_limit(power_flow_case::PowerFlowCase)
    return !isempty(power_flow_case.caches.limited_reactive_power_injection)
end

function find_voltage_control(power_flow_case::PowerFlowCase, controlling_bus_idx::Int)
    for vc in power_flow_case.caches.voltage_controlled_by_reactive_power
        if vc.controlling_bus_idx == controlling_bus_idx
            return vc
        end
    end
    return nothing
end

function reactive_power_limits!(
    power_flow_case::PowerFlowCase,
    Qcalc::Vector{Float64},
)
    for limit in power_flow_case.caches.limited_reactive_power_injection
        bus_idx = limit.bus_idx
        Qg = Qcalc[bus_idx] + power_flow_case.buses[bus_idx].reactive_power_load
        @info("barra $(bus_idx)")
        @info("Qg: $(Qg)")
        @info("Limites: [$(limit.min_reactive_power_injection), $(limit.max_reactive_power_injection)]")
        if limit.skip_limit_check
            continue
        end
        tol = power_flow_case.tolerance
        Qmin = limit.min_reactive_power_injection
        Qmax = limit.max_reactive_power_injection
        if Qg < Qmin - tol
            @info("  Limit violation: Below minimum")
            limit.limit_violation = LimitViolation.BelowMinimum
            power_flow_case.buses[bus_idx].type = Bus_type.PQ
            if limit.original_bus_type == Bus_type.P
                disable_p_bus_voltage_control!(power_flow_case, bus_idx)
            end
        elseif Qg > Qmax + tol
            @info("  Limit violation: Above maximum")
            limit.limit_violation = LimitViolation.AboveMaximum
            power_flow_case.buses[bus_idx].type = Bus_type.PQ
            if limit.original_bus_type == Bus_type.P
                disable_p_bus_voltage_control!(power_flow_case, bus_idx)
            end
        # else
        #     limit.limit_violation = LimitViolation.NoViolation
        end
    end
    return nothing
end

function disable_p_bus_voltage_control!(power_flow_case::PowerFlowCase, p_bus_idx::Int)
    vc = find_voltage_control(power_flow_case, p_bus_idx)
    if vc !== nothing
        vc.disabled = true
        power_flow_case.buses[vc.controlled_bus_idx].type = Bus_type.PQ
        @info("  P bus $(p_bus_idx) control disabled, PQV bus $(vc.controlled_bus_idx) → PQ")
    end
    return nothing
end

function update_Q_lim_mismatch(
    power_flow_case::PowerFlowCase,
    Q_mismatch::Vector{Float64},
    Qcalc::Vector{Float64},
)
    for limit in power_flow_case.caches.limited_reactive_power_injection
        bus_idx = limit.bus_idx
        if limit.limit_violation == LimitViolation.BelowMinimum
            Q_mismatch[bus_idx] = limit.min_reactive_power_injection - power_flow_case.buses[bus_idx].reactive_power_load - Qcalc[bus_idx]
        elseif limit.limit_violation == LimitViolation.AboveMaximum
            Q_mismatch[bus_idx] = limit.max_reactive_power_injection - power_flow_case.buses[bus_idx].reactive_power_load - Qcalc[bus_idx]
        end
    end
    return Q_mismatch
end

function check_if_PQ_buses_can_go_back_to_PV!(
    power_flow_case::PowerFlowCase,
    voltage_magnitudes::Vector{Float64},
)
    for limit in power_flow_case.caches.limited_reactive_power_injection
        bus_idx = limit.bus_idx
        tol = power_flow_case.tolerance

        if limit.original_bus_type == Bus_type.P
            vc = find_voltage_control(power_flow_case, bus_idx)
            if vc === nothing || !vc.disabled
                continue
            end
            controlled_bus_idx = vc.controlled_bus_idx
            vcalc = voltage_magnitudes[controlled_bus_idx]
            vesp = power_flow_case.buses[controlled_bus_idx].voltage_magnitude
            @info("Check de tensão barra P $(bus_idx) → barra PQV $(controlled_bus_idx)")
            @info("tensão: $(vcalc), tensão especificada: $(vesp)")
            can_recover = false
            if limit.limit_violation == LimitViolation.BelowMinimum && (vcalc < vesp - tol || vcalc < vesp + tol)
                can_recover = true
            end
            if limit.limit_violation == LimitViolation.AboveMaximum && (vcalc > vesp - tol || vcalc > vesp + tol)
                can_recover = true
            end
            if can_recover
                power_flow_case.buses[bus_idx].type = Bus_type.P
                power_flow_case.buses[controlled_bus_idx].type = Bus_type.PQV
                vc.disabled = false
                limit.skip_limit_check = true
                @info("  P bus $(bus_idx) can go back to P, PQV bus $(controlled_bus_idx) restored")
            end
        else
            vcalc = voltage_magnitudes[bus_idx]
            vesp = power_flow_case.buses[bus_idx].voltage_magnitude
            @info("Check de tensão")
            @info("barra $(bus_idx)")
            @info("tensão: $(vcalc)")
            @info("tensão especificada: $(vesp))")
            if limit.limit_violation == LimitViolation.BelowMinimum
                if vcalc < vesp - tol || vcalc < vesp + tol
                    power_flow_case.buses[bus_idx].type = limit.original_bus_type
                    limit.skip_limit_check = true
                    @info("  Bus $(bus_idx) can go back to PV")
                end
            end
            if limit.limit_violation == LimitViolation.AboveMaximum
                if vcalc > vesp - tol || vcalc > vesp + tol
                    power_flow_case.buses[bus_idx].type = limit.original_bus_type
                    limit.skip_limit_check = true
                    @info("  Bus $(bus_idx) can go back to PV")
                end
            end
        end
    end
    return nothing
end

function bus_with_reactive_power_limits_satisfies_voltage(
    power_flow_case::PowerFlowCase,
    voltage_magnitude::Vector{Float64},
    tolerance::Float64,
)
    if isempty(power_flow_case.caches.limited_reactive_power_injection)
        return true
    end
    voltage_error = Float64[]
    for limit in power_flow_case.caches.limited_reactive_power_injection
        bus_idx = limit.bus_idx
        if limit.original_bus_type == Bus_type.P
            vc = find_voltage_control(power_flow_case, bus_idx)
            if vc === nothing
                continue
            end
            if vc.disabled
                return false
            end
            controlled_bus_idx = vc.controlled_bus_idx
            push!(voltage_error, voltage_magnitude[controlled_bus_idx] - power_flow_case.buses[controlled_bus_idx].voltage_magnitude)
        else
            push!(voltage_error, voltage_magnitude[bus_idx] - power_flow_case.buses[bus_idx].voltage_magnitude)
        end
    end
    if isempty(voltage_error)
        return true
    end
    return maximum(abs.(voltage_error)) < tolerance
end

function case_back_to_original_buses!(
    power_flow_case::PowerFlowCase,
)
    for limit in power_flow_case.caches.limited_reactive_power_injection
        bus_idx = limit.bus_idx
        if power_flow_case.buses[bus_idx].type != limit.original_bus_type
            power_flow_case.buses[bus_idx].type = limit.original_bus_type
            @warn("Barra $(bus_idx) não retornou para o tipo original: $(limit.original_bus_type)")
        end
        for vc in power_flow_case.caches.voltage_controlled_by_reactive_power
            if vc.controlling_bus_idx == bus_idx
                controlled_bus_idx = vc.controlled_bus_idx
                if power_flow_case.buses[controlled_bus_idx].type != Bus_type.PQV
                    power_flow_case.buses[controlled_bus_idx].type = Bus_type.PQV
                    @warn("Barra controlada $(controlled_bus_idx) não retornou para PQV")
                end
            end
        end
    end
    return nothing
end
