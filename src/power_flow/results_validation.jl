function _check_p_injection!(violations::Vector{String}, bus::Bus, P_calc::Float64, tol::Float64)
    P_spec = bus.active_power_generation - bus.active_power_load
    diff = abs(P_calc - P_spec)
    if diff > tol
        push!(violations, "P injection: calc=$P_calc, spec=$P_spec, |diff|=$diff")
    end
    return nothing
end

function _check_q_injection!(violations::Vector{String}, Q_calc::Float64, Q_spec::Float64, tol::Float64)
    diff = abs(Q_calc - Q_spec)
    if diff > tol
        push!(violations, "Q injection: calc=$Q_calc, spec=$Q_spec, |diff|=$diff")
    end
    return nothing
end

function _check_v_magnitude!(violations::Vector{String}, bus::Bus, v_calc::Float64, tol::Float64)
    diff = abs(v_calc - bus.voltage_magnitude)
    if diff > tol
        push!(violations, "V magnitude: calc=$v_calc, spec=$(bus.voltage_magnitude), |diff|=$diff")
    end
    return nothing
end

function _check_v_angle!(violations::Vector{String}, bus::Bus, a_calc::Float64, tol::Float64)
    diff = abs(a_calc - bus.voltage_angle)
    if diff > tol
        push!(violations, "V angle: calc=$a_calc, spec=$(bus.voltage_angle), |diff|=$diff")
    end
    return nothing
end

function _check_q_limits!(violations::Vector{String}, bus::Bus, Q_calc::Float64, tol::Float64)
    Qmin = bus.min_reactive_power_injection
    Qmax = bus.max_reactive_power_injection
    if !isfinite(Qmin) && !isfinite(Qmax)
        return nothing
    end
    Qg = Q_calc + bus.reactive_power_load
    if isfinite(Qmin) && Qg < Qmin - tol
        push!(violations, "Q below Qmin: Qg=$Qg, Qmin=$Qmin, diff=$(Qmin - Qg)")
    end
    if isfinite(Qmax) && Qg > Qmax + tol
        push!(violations, "Q above Qmax: Qg=$Qg, Qmax=$Qmax, diff=$(Qg - Qmax)")
    end
    return nothing
end

# For buses converted to PQ due to Q limit violation, returns the effective Q_spec based on the
# active limit, since bus.reactive_power_generation is not updated when the bus type changes.
function _effective_q_spec(power_flow_case::PowerFlowCase, bus_idx::Int)::Float64
    bus = power_flow_case.buses[bus_idx]
    for limit in power_flow_case.caches.limited_reactive_power_injection
        if limit.bus_idx == bus_idx
            if limit.limit_violation == LimitViolation.BelowMinimum
                return limit.min_reactive_power_injection - bus.reactive_power_load
            end
            if limit.limit_violation == LimitViolation.AboveMaximum
                return limit.max_reactive_power_injection - bus.reactive_power_load
            end
        end
    end
    return bus.reactive_power_generation - bus.reactive_power_load
end

function validate_bus(
    power_flow_case::PowerFlowCase,
    bus_idx::Int,
    v::Vector{Float64},
    a::Vector{Float64},
    P_calc::Vector{Float64},
    Q_calc::Vector{Float64},
)::Bool
    bus = power_flow_case.buses[bus_idx]
    tol = power_flow_case.tolerance
    violations = String[]

    if bus_is_pq(bus)
        _check_p_injection!(violations, bus, P_calc[bus_idx], tol)
        _check_q_injection!(violations, Q_calc[bus_idx], _effective_q_spec(power_flow_case, bus_idx), tol)
    elseif bus_is_pv(bus)
        _check_p_injection!(violations, bus, P_calc[bus_idx], tol)
        _check_v_magnitude!(violations, bus, v[bus_idx], tol)
        _check_q_limits!(violations, bus, Q_calc[bus_idx], tol)
    elseif bus_is_slack(bus)
        _check_v_magnitude!(violations, bus, v[bus_idx], tol)
        _check_v_angle!(violations, bus, a[bus_idx], tol)
    elseif bus_is_p(bus)
        _check_p_injection!(violations, bus, P_calc[bus_idx], tol)
        _check_q_limits!(violations, bus, Q_calc[bus_idx], tol)
    elseif bus_is_pqv(bus)
        _check_p_injection!(violations, bus, P_calc[bus_idx], tol)
        _check_q_injection!(violations, Q_calc[bus_idx], _effective_q_spec(power_flow_case, bus_idx), tol)
        _check_v_magnitude!(violations, bus, v[bus_idx], tol)
    end

    if !isempty(violations)
        for msg in violations
            @warn "Bus $(bus.name) [$(bus.type)] (index $bus_idx): $msg"
        end
        return false
    end
    return true
end

function validate_power_flow_solution(
    power_flow_case::PowerFlowCase,
    v::Vector{Float64},
    a::Vector{Float64},
)::Bool
    Ybus = admittance_matrix(power_flow_case)
    S_calc = power_injection(v, a, Ybus)
    P_calc = real.(S_calc)
    Q_calc = imag.(S_calc)
    consistent = true
    for bus_idx in eachindex(power_flow_case.buses)
        if !validate_bus(power_flow_case, bus_idx, v, a, P_calc, Q_calc)
            consistent = false
        end
    end
    return consistent
end
