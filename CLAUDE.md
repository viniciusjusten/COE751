# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Julia package implementing Newton-Raphson AC power flow with augmented voltage controls (CREM and CTAP) and reactive power limits (QLIM), validated against IEEE 14-bus cases from ANAREDE/CEPEL.

## Commands

**Run all tests:**
```
julia --project=. -e "using Pkg; Pkg.test()"
```

**Run a single test file** (must be invoked via the test runner to have `COE751` loaded):
```
julia --project=. -e "using Pkg; Pkg.test()" -- test/ieee_14_base_case/
```
Or use the Revise workflow and manually `include("test/...")` after loading the module.

**Run a case study** (e.g., IEEE-14 Case 3):
```
julia --project=. ieee-14/case3/ieee14.jl
```

**Interactive development with Revise** (auto-reloads source on file save):
```
julia revise/revise.jl
```

## Architecture

### Newton-Raphson with augmented variables

The solver in [solver.jl](src/power_flow/solver.jl) runs Newton-Raphson on an augmented system with three classes of extra variables beyond the standard (V, θ):

| Control | Variable | Equation added |
|---|---|---|
| CREM (remote Q) | Qg of type-P bus | V_controlled = V_spec |
| CTAP (transformer tap) | tap ratio | V_controlled = V_spec |
| QLIM | none (bus type switch) | PV ↔ PQ conversion |

**Augmented Jacobian structure** — `(2n + n_qgvc + n_tapvc)²`:
```
[ H    N    dP/dQg    dP/dTap     ]
[ M    L    dQ/dQg    dQ/dTap     ]
[ dV/dA  dV/dV  0        0        ]  ← CREM voltage rows
[ dV/dA  dV/dV  0        0        ]  ← CTAP voltage rows
```
Slack/PV bus constraints are enforced with large diagonal penalties (1e12) rather than row elimination.

### Bus types

- **Slack**: θ and V fixed (reference bus)
- **PV**: P and V specified; angle and Qg calculated
- **PQ**: P and Q specified; V and angle calculated
- **P** (CREM): P specified; Qg is the free variable that controls a remote PQV bus voltage
- **PQV**: P and Q specified; V held at spec by either a P-bus (CREM) or a transformer tap (CTAP)

QLIM converts PV↔PQ and P↔PQ dynamically during iterations when reactive limits are violated. Bus types are restored to originals after convergence via `case_back_to_original_buses!`.

### Ybus model for transformers

Off-nominal transformer with tap `t` on the from-bus side (standard π model):
```
Y[from,from] += t² × y      Y[to,to] += y
Y[from,to]   -= t × y       Y[to,from] -= t × y
```
`Circuit.tap_ratio` stores `1 / tap_pwf` (inverse of the ANAREDE tap value).

For CTAP, the Ybus is updated incrementally each iteration starting at iteration 2 via `update_tap_transformer_admittances`. `previous_tap` tracks what tap ratio is currently reflected in Ybus so only the delta is applied.

### Key data structures (`collections.jl`)

- `Bus`: holds type, V spec, P/Q generation and load, Q limits, controlled bus index, shunt
- `Circuit`: holds impedance, tap, phase shift, controlled bus index
- `PowerFlowCase`: buses + circuits + `Caches` (pre-built control/limit lists) + solver settings
- `Caches`: holds `voltage_controlled_by_reactive_power`, `voltage_controlled_by_tap`, `limited_reactive_power_injection` — populated once at `build_power_flow_case` time

### File map

| File | Responsibility |
|---|---|
| `collections.jl` | All structs, `build_power_flow_case`, bus-type predicates |
| `solver.jl` | Main NR loop, convergence check, Ybus update timing |
| `newton_raphson.jl` | Jacobian assembly, `admittance_matrix`, `specified_power_injection`, flat-start initializers |
| `remote_voltage_control/reactive_injection.jl` | CREM mismatch and Jacobian helpers |
| `remote_voltage_control/tap_transformer.jl` | CTAP mismatch and incremental Ybus update |
| `limits/reactive_injection.jl` | QLIM bus-type switching, limit mismatch, PV recovery logic |
| `outputs.jl` | Console and `.sum` file report formatting |
| `results_validation.jl` | Post-solve consistency checks |

### Case studies (`ieee-14/`)

Each subfolder contains an `ieee14.jl` (builds and solves the case) and the corresponding ANAREDE `.pwf` file. Cases build on each other:
- `base/`: plain NR, no controls
- `case1/`: CREM active (buses 6 and 8 control remote voltages)
- `case2/`: CREM + QLIM
- `case3/`: CREM + CTAP (T4-9 controls bus 9; T5-6 controls bus 5)

### Convention notes

- All internal quantities in per-unit (base 100 MVA)
- Line shunt susceptance: each end of the π model receives `Bsh_total / 2`; the `shunt_susceptance` field in `Circuit` is already halved
- Solver log written to `*.solver`; per-bus summary written to `res_barra.sum`