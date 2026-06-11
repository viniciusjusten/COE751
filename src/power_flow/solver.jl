function solve_power_flow(power_flow_case::PowerFlowCase)
    max_iterations = power_flow_case.max_iterations
    tolerance = power_flow_case.tolerance
    log_path = power_flow_case.log_path

    log = isempty(log_path) ? devnull : open(log_path, "w")

    n_buses = length(power_flow_case.buses)
    n_qg_vc = num_controlled_voltages_by_reactive_power(power_flow_case)
    n_tap_vc = num_controlled_voltages_by_tap(power_flow_case)
    Ybus = admittance_matrix(power_flow_case)
    
    # initialize voltage magnitudes and angles
    v = initialize_voltage_magnitude(power_flow_case)
    a = initialize_voltage_angle(power_flow_case)
    qg_vc = initialize_reactive_power_that_controls_voltage(power_flow_case)
    tap_vc = initialize_tap_transformer_control(power_flow_case)
    previous_tap = zeros(n_tap_vc)

    # helper vectors to store bus type indices
    slack_indices = findall(bus -> bus_is_slack(bus), power_flow_case.buses)
    p_indices = findall(bus -> bus_is_p(bus), power_flow_case.buses)
    pv_indices = findall(bus -> bus_is_pv(bus), power_flow_case.buses)
    pq_indices = findall(bus -> bus_is_pq(bus), power_flow_case.buses)
    pqv_indices = findall(bus -> bus_is_pqv(bus), power_flow_case.buses)

    # indices for voltage updates
    angle_indices = sort(vcat(p_indices, pv_indices, pq_indices, pqv_indices))
    voltage_indices = sort(vcat(p_indices, pq_indices, pqv_indices))

    for iter in 1:max_iterations
        println(log, "Iteration $iter")
        @info("Iteration $iter")

        if iter > 1 && !isempty(tap_vc)
            # update tap ratios in Ybus based on current tap_vc values
            Ybus = update_tap_transformer_admittances(
                Ybus,
                power_flow_case,
                previous_tap,
                tap_vc,
            )
        end

        # specified power injection
        Pesp, Qesp = specified_power_injection(power_flow_case)
        
        # calculate power injection based on current voltage estimates
        Scalc = power_injection(v, a, Ybus)
        Pcalc = real.(Scalc)
        Qcalc = imag.(Scalc)

        # if buses have reactive power limits, check for violations, update bus types, and adjust Qcalc accordingly
        if case_has_any_reactive_power_limit(power_flow_case) && iter > 2
            # update bus type and caches
            reactive_power_limits!(power_flow_case, Qcalc)

            # update bus type indices for mismatch vector construction
            p_indices = findall(bus -> bus_is_p(bus), power_flow_case.buses)
            pv_indices = findall(bus -> bus_is_pv(bus), power_flow_case.buses)
            pq_indices = findall(bus -> bus_is_pq(bus), power_flow_case.buses)
            pqv_indices = findall(bus -> bus_is_pqv(bus), power_flow_case.buses)
            angle_indices = sort(vcat(p_indices, pv_indices, pq_indices, pqv_indices))
            voltage_indices = sort(vcat(p_indices, pq_indices, pqv_indices))
        end

        # mismatch vectors
        ## regular power flow
        P_mismatch = Pesp - Pcalc
        P_mismatch[slack_indices] .= 0.0
        Q_mismatch = Qesp - Qcalc
        Q_mismatch[slack_indices] .= 0.0
        Q_mismatch[pv_indices] .= 0.0
        ## reactive power that controls voltage
        Qg_vc_mismatch = reactive_power_control_mismatch(power_flow_case, Qcalc)
        for (i, vbcq) in enumerate(power_flow_case.caches.voltage_controlled_by_reactive_power)
            if vbcq.disabled
                continue
            end
            controlling_bus_idx = vbcq.controlling_bus_idx
            Q_mismatch[controlling_bus_idx] = Qg_vc_mismatch[i]
        end
        vc_qg_mismatch = voltage_controlled_by_reactive_power_mismatch(power_flow_case, v)
        for (i, vbcq) in enumerate(power_flow_case.caches.voltage_controlled_by_reactive_power)
            if vbcq.disabled
                vc_qg_mismatch[i] = 0.0
            end
        end
        ## tap transformer control
        vc_tap_mismatch = voltage_controlled_by_tap_mismatch(power_flow_case, v)
        ## limit mismatch
        if case_has_any_reactive_power_limit(power_flow_case) && iter > 2
            Q_mismatch = update_Q_lim_mismatch(power_flow_case, Q_mismatch, Qcalc)
        end
        ## total mismatch vector
        mismatch = vcat(P_mismatch, Q_mismatch, vc_qg_mismatch, vc_tap_mismatch)
        println(log, "  Mismatch: $mismatch")

        # check for convergence
        # TODO - check if we need to also check that voltages at buses with reactive power limits satisfy their specified voltage magnitudes
        if maximum(abs.(mismatch)) < tolerance# && bus_with_reactive_power_limits_satisfies_voltage(power_flow_case, v, tolerance)
            println(log, stdout, "Power flow converged in $iter iterations.")
            close(log)
            case_back_to_original_buses!(power_flow_case)
            return v, a
        end

        # construct Jacobian matrix
        J = jacobian(
            power_flow_case,
            Ybus,
            Scalc,
            v,
            a;
            reactive_power_voltage_control = qg_vc,
            tap_transformer_control = tap_vc,
        )
        println(log, "  Jacobian: $J")

        # store previous tap ratios for the next iteration's Ybus update
        previous_tap .= deepcopy(tap_vc)

        # update voltage magnitudes and angles
        update = SparseArrays.sparse(J) \ mismatch
        println(log, "  Update: $update")
        a[angle_indices] += update[angle_indices]
        v[voltage_indices] += update[n_buses .+ voltage_indices]
        delta_qg_vc = update[2 * n_buses .+ (1:n_qg_vc)]
        qg_vc += delta_qg_vc
        tap_vc += update[2 * n_buses + n_qg_vc .+ (1:n_tap_vc)]

        # update caches
        update_reactive_injection_that_controls_voltage!(power_flow_case, delta_qg_vc)

        # after updating voltages, check if any PQ buses that were previously converted from PV due to reactive power limits can be converted back to PV
        if case_has_any_reactive_power_limit(power_flow_case) && iter > 2
            check_if_PQ_buses_can_go_back_to_PV!(power_flow_case, v)
        end

        @info("")
    end
    
    println(log, stdout, "[ERROR] Power flow did not converge within $max_iterations iterations.")
    close(log)
    case_back_to_original_buses!(power_flow_case)
    return v, a
end
