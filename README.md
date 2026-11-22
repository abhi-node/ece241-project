# FPGA Maze Generator and Solver

ECE 241 project by Abhijith Balagurusamy and Ali Alali.

The DE1-SoC generates a random maze with stack-based depth-first search, solves it with Lee's algorithm (breadth-first flood plus backtrace), and animates both on a VGA monitor. A PS/2 keyboard picks generate, solve and animation speed. The HEX displays show how many clock cycles the solve took.

## Repository layout

```
rtl/                    synthesizable Verilog
  maze_top.v            top-level entity: wires everything to the board pins
  control/              control_fsm, rate_divider, cycle_counter
  maze/                 maze_ram, sync_ram, lfsr16, dfs_generator, lee_solver
  input/                ps2_rx, key_decoder
  display/              vga_tile_draw, hex7seg
  vga_adapter/          course-provided VGA adapter (not our code)
mem/                    maze_init.hex (power-up maze), black.mif (VGA background)
sim/                    testbenches (tb_*.v) + ModelSim wave scripts (tb_*.do), VGA stub
quartus/                Quartus project (maze.qpf / maze.qsf)
docs/
  design/               conceptual design: overview, architecture, one page per module
  build_and_demo.md     Quartus steps, demo checklist, troubleshooting
  simulations/          one guide per testbench: what it tests, every wave explained
  proposal.md           original project proposal
attribution/            who did what (abhi.md, ali.md)
```

The Verilog has no comments; every file is explained in [docs/design/modules/](docs/design/modules/). Start at [docs/design/](docs/design/README.md).

## How it fits together

```
 PS/2 keyboard ─► ps2_rx ─► key_decoder ─┐
 KEY[1], KEY[2] ─────────────────────────┤ go_generate / go_solve
                                         ▼
                                    control_fsm ── gen_start ──► dfs_generator ─┐
                                         │                          ▲           │ port A
                                         └──── solve_start ──► lee_solver ──────┤ (one owner
                                                                    ▲           │  at a time)
 rate_divider ── tick ──────────────────────────────────────────────┤           ▼
 lfsr16 ──────── random direction ──► dfs_generator            maze_ram (2048 x 3 bits)
                                                                                │ port B
                                                                                ▼
                                                      vga_tile_draw ─► vga_adapter ─► monitor
 lee_solver ── working ──► cycle_counter ──► hex7seg ─► HEX5-0
```

The key idea: **the maze RAM is the only shared state.** The generator and solver edit tiles through port A. The VGA drawer reads port B and repaints the whole screen about 2,600 times a second without being told anything changed. The control FSM lets only one algorithm run at a time, so port A only ever has one writer. The rate divider slows the algorithms down so you can watch them.

See [docs/design/architecture.md](docs/design/architecture.md) for the full walkthrough.

## Controls

| Input | Action |
| --- | --- |
| `KEY[0]` | Reset |
| `G` or `KEY[1]` | Generate a new maze |
| `S` or `KEY[2]` | Solve the current maze |
| `1` `2` `3` `4` | Speed: slow (8 steps/s), medium (32), fast (128), instant |
| `SW[9]` | Force instant speed |
| `SW[0]` | HEX view: off = solve cycles; on = scan code, speed, stack depth / path length |

| Colour | Tile |
| --- | --- |
| Blue | Wall |
| White | Open path |
| Green / Red | Start (top-left) / End (bottom-right) |
| Cyan | Explored by the solver |
| Yellow | Shortest path |

## Quick start

Simulation in ModelSim: change directory to `sim/`, then `do tb_maze_top.do` (or any `tb_*.do`) for labelled waves, or `do run_all.do` to run everything. With Icarus Verilog: `sim/run_all.sh`. See [docs/simulations](docs/simulations/README.md).

Board: open `quartus/maze.qpf`, import the course `DE1_SoC.qsf` pin assignments, compile, program. Full steps are in [docs/build_and_demo.md](docs/build_and_demo.md).
