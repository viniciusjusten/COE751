function newton_raphson(F, dF, x0, y; tol = 1e-8, max_iter = 1000, digits = 6)
    x = x0
    for i in 1:max_iter
        dy = y - F(x)
        if maximum(abs.(dy)) < tol
            println("Converged in $i iterations with y tolerance $tol.")
            return round.(x; digits)
        end
        dfx = dF(x)
        # if abs(dfx) < tol
        #     error("Derivative is too small. No solution found.")
        # end
        dx = dfx \ dy
        x_new = x .+ dx
        println("Current solution: $x_new")
        if maximum(abs.(x_new .- x)) < tol
            println("Converged in $i iterations with x tolerance $tol.")
            return round.(x_new; digits)
        end
        x = x_new
    end
    error("Maximum iterations reached. No solution found.")
    return round.(x; digits)
end
