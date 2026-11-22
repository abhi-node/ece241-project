# tb_maze_top: the whole board

**Run:** `do tb_maze_top.do`

## What is being tested

Everything in `maze_top` working together: buttons, control FSM, generator, solver, the shared maze RAM and the VGA drawer. The only fake part is the VGA adapter. `sim/stubs/vga_adapter_stub.v` has the same ports as the course adapter, but it records every pixel into a 160x120 array instead of driving a monitor (the real one needs Intel PLL and RAM models).

`SW[9]` is held up, so everything runs at instant speed.

## What the testbench does

It presses buttons like a person would:

| Step | Action | Checks |
| --- | --- | --- |
| 1 | Release reset, wait two frames | Screen matches the power-up maze |
| 2 | Press KEY[2] (solve) | Finishes, LEDR[4] (path found) on, screen matches RAM |
| 3 | Press KEY[1] (generate) | Finishes, LEDR[3] (maze generated) on, screen matches RAM |
| 4 | Press KEY[2] (solve) | Finishes, LEDR[4] on, screen matches RAM |

"Screen matches RAM" means all 19,200 pixels are checked. Each one must have the colour of its tile, and the 2-pixel border must be black. At the end the screen is written to `sim/out/frame.ppm`, which most image viewers open.

## Waves

| Label | Signal | Meaning |
| --- | --- | --- |
| `reset_n`, `generate_btn`, `solve_btn` | `KEY[0]`, `KEY[1]`, `KEY[2]` | Push buttons (active low) |
| `state` | `DUT/control_state` | Control FSM state |
| `generator` | `DUT/GENERATOR/state` | Generator state |
| `solver` | `DUT/SOLVER/state` | Solver state |
| `tick` | `DUT/tick` | Animation tick (always high at instant speed) |
| `owner_is_solver` | `DUT/solve_busy` | Which algorithm drives maze RAM port A |
| `write`, `write_tile` | `MAZE/we_a`, `MAZE/din_a` | Tiles being written by whichever algorithm owns the port |
| `x`, `y`, `colour`, `plot` | `vga_x`, `vga_y`, `vga_color`, `vga_write` | Pixels the drawer sends to the adapter |
| `solve_cycles` | `DUT/solve_cycles` | The number shown on HEX5-0 |
| `path_length` | `DUT/path_length` | Yellow tiles in the solution |
| `LEDR` | `LEDR` | Status LEDs |

## What to look for

- With the default Zoom Full you can see the three bursts of activity: solve, generate, solve. `state` goes IDLE → SOLVE_START → SOLVING → IDLE, and so on.
- `owner_is_solver` is high only during the solves.
- `x`/`y`/`plot` never stop. The drawer repaints continuously whatever the algorithms are doing.
- `solve_cycles` freezes at its final value when each solve ends.

## Expected transcript

```
ok: power-up screen matches maze RAM
ok: solve power-up maze finished after 7015 clocks
solve cycles on HEX: 2924, path length 181
ok: solved power-up screen matches maze RAM
ok: generate finished after 7886 clocks
ok: generated screen matches maze RAM
ok: solve new maze finished after 6129 clocks
solve cycles on HEX: 2038, path length 145
ok: solved new maze screen matches maze RAM
wrote out/frame.ppm
=== tb_maze_top: ALL TESTS PASSED ===
```
The second solve's numbers change with every generated maze.
