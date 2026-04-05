Ybus = [
    (.2-im)/1.04+im*0.02 -(.2-im)/1.04;
    -(.2-im)/1.04 (.2-im)/1.04+im*0.02
    ]
Gbus = real.(Ybus)
Bbus = imag.(Ybus)

# x = [t2, v2]
function F(x)
    t2, v2 = x
    t1 = 0
    v1 = 1
    P2 = v2^2*Gbus[2,2] + v1*v2*(Gbus[2, 1]*cos(t2-t1) + Bbus[2, 1]*sin(t2-t1))
    Q2 = -v2^2*Bbus[2,2] + v1*v2*(Gbus[2, 1]*sin(t2-t1) - Bbus[2, 1]*cos(t2-t1))
    return [P2; Q2]
end

function dF(x)
    t2, v2 = x
    t1 = 0
    v1 = 1
    dP2_dt2 = v1*v2*(Bbus[2, 1]*cos(t2-t1) - Gbus[2, 1]*sin(t2-t1))
    dP2_dv2 = 2*v2*Gbus[2,2] + v1*(Gbus[2, 1]*cos(t2-t1) + Bbus[2, 1]*sin(t2-t1))
    dQ2_dt2 = v1*v2*(Bbus[2, 1]*sin(t2-t1) + Gbus[2, 1]*cos(t2-t1))
    dQ2_dv2 = -2*v2*Bbus[2,2] + v1*(Gbus[2, 1]*sin(t2-t1) - Bbus[2, 1]*cos(t2-t1))
    return [dP2_dt2 dP2_dv2; dQ2_dt2 dQ2_dv2]
end

y = [-.3; 0.07]

x0 = [0.0; 1.0]

COE751.newton_raphson(F, dF, x0, y; log_path = raw"D:\codes\COE751\examples\slides_pt2_ex2_pg_49_solver.solver")
