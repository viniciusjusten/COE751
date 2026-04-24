P = [-.5, -1.0] # P2, P3

x12 = 1/3
x13 = 1/2
x23 = 1/2

B = [
    inv(x12)+inv(x23) -inv(x23);
    -inv(x23) inv(x13)+inv(x23)
]

T = B \ P

P12 = (0 - T[1]) / x12
P13 = (0 - T[2]) / x13
P23 = (T[1] - T[2]) / x23

println("θ1 = 0 deg")
println("θ2 = $(rad2deg(T[1])) deg")
println("θ3 = $(rad2deg(T[2])) deg")
println("P12 = $P12 p.u.")
println("P13 = $P13 p.u.")
println("P23 = $P23 p.u.")