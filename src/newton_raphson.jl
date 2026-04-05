function newton_raphson(
    F,
    dF,
    x0,
    y; tol = 1e-8,
    max_iter = 1000,
    digits = 6,
    log_path = "",
)
    log = isempty(log_path) ? devnull : open(log_path, "w")

    x = x0
    for i in 1:max_iter
        println(log, "Iteration $i:")
        dy = y - F(x)
        println(log, "  Mismatch: $dy")
        if maximum(abs.(dy)) < tol
            println(log, stdout, "Converged in $i iterations with y tolerance $tol.")
            close(log)
            return round.(x; digits)
        end
        dfx = dF(x)
        println(log, "  Jacobian: $dfx")
        # if abs(dfx) < tol
        #     error("Derivative is too small. No solution found.")
        # end
        dx = dfx \ dy
        x_new = x .+ dx
        println(log, "  Update: $dx")
        println(log, "  New solution: $x_new")
        if maximum(abs.(x_new .- x)) < tol
            println(log, stdout, "Converged in $i iterations with x tolerance $tol.")
            close(log)
            return round.(x_new; digits)
        end
        x = x_new
    end
    @error("Maximum iterations reached. No solution found.")
    close(log)
    return round.(x; digits)
end
