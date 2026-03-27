import Pkg
Pkg.instantiate()

using Revise

Pkg.activate(dirname(@__DIR__))
Pkg.instantiate()

using COE751
@info("""
This session is using COE751 with Revise.jl.
For more information visit https://timholy.github.io/Revise.jl/stable/.
""")
