function solve_power_flow(power_flow_case::PowerFlowCase)
    max_iterations = power_flow_case.max_iterations
    tolerance = power_flow_case.tolerance
    log_path = power_flow_case.log_path

    log = isempty(log_path) ? devnull : open(log_path, "w")

    n_buses = length(power_flow_case.buses)
    n_qg_vc = num_controlled_voltages_by_reactive_power(power_flow_case)
    Ybus = admittance_matrix(power_flow_case)
    
    # initialize voltage magnitudes and angles
    v = initialize_voltage_magnitude(power_flow_case)
    a = initialize_voltage_angle(power_flow_case)
    qg_vc = initialize_reactive_power_that_controls_voltage(power_flow_case)

    # helper vectors to store bus type indices
    slack_indices = findall(bus -> bus_is_slack(bus), power_flow_case.buses)
    p_indices = findall(bus -> bus_is_p(bus), power_flow_case.buses)
    pv_indices = findall(bus -> bus_is_pv(bus), power_flow_case.buses)
    pq_indices = findall(bus -> bus_is_pq(bus), power_flow_case.buses)
    pqv_indices = findall(bus -> bus_is_pqv(bus), power_flow_case.buses)

    # indices for voltage updates
    angle_indices = sort(vcat(p_indices, pv_indices, pq_indices, pqv_indices))
    voltage_indices = sort(vcat(p_indices, pq_indices))

    for iter in 1:max_iterations
        println(log, "Iteration $iter")

        # specified power injection
        Pesp, Qesp = specified_power_injection(power_flow_case)
        
        # calculate power injection based on current voltage estimates
        Scalc = power_injection(v, a, Ybus)
        Pcalc = real.(Scalc)
        Qcalc = imag.(Scalc)

        # mismatch vectors
        ## regular power flow
        P_mismatch = Pesp - Pcalc
        P_mismatch[slack_indices] .= 0.0
        Q_mismatch = Qesp - Qcalc
        Q_mismatch[slack_indices] .= 0.0
        Q_mismatch[pv_indices] .= 0.0
        ## reactive power that controls voltage
        Qg_vc_mismatch = reactive_power_control_mismatch(power_flow_case, Qcalc, qg_vc)
        ## total mismatch vector
        mismatch = vcat(P_mismatch, Q_mismatch, Qg_vc_mismatch)
        println(log, "  Mismatch: $mismatch")

        # check for convergence
        if maximum(abs.(mismatch)) < tolerance
            println(log, stdout, "Power flow converged in $iter iterations.")
            close(log)
            return v, a
        end

        # construct Jacobian matrix
        J = jacobian(
            power_flow_case,
            Ybus,
            Scalc,
            v,
            a,
            reactive_power_voltage_control = qg_vc,
        )
        println(log, "  Jacobian: $J")

        # update voltage magnitudes and angles
        update = SparseArrays.sparse(J) \ mismatch
        println(log, "  Update: $update")
        a[angle_indices] += update[angle_indices]
        v[voltage_indices] += update[n_buses .+ voltage_indices]
        qg_vc += update[2 * n_buses .+ (1:n_qg_vc)]
    end
    
    println(log, stdout, "[ERROR] Power flow did not converge within $max_iterations iterations.")
    close(log)
    return v, a
end
