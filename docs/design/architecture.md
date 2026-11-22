# Architecture

## Block diagram

```
 PS/2 keyboard ─► ps2_rx ─► key_decoder ─┐ key_generate / key_solve
 KEY[1], KEY[2] ─► (sync + edge detect) ─┤
                                         ▼
                                   control_fsm
                                    │        │
                          gen_start │        │ solve_start
                                    ▼        ▼
 lfsr16 ─ random_dir ─► dfs_generator    lee_solver ─ working ─► cycle_counter ─► hex7seg ─► HEX
 rate_divider ─ tick ─►      │                │
                             └──► mux ◄───────┘   (solver owns port A while busy)
                                   │ port A (read/write)
                                   ▼
                               maze_ram ──── port B (read only) ──► vga_tile_draw ──► vga_adapter ──► monitor
```

## The four groups

| Group | Modules | Job |
| --- | --- | --- |
| **Input** | `ps2_rx`, `key_decoder` | Keyboard wires → one-clock command pulses + speed setting |
| **Control** | `control_fsm`, `rate_divider`, `cycle_counter` | Who runs, how fast, how long it took |
| **Maze** | `maze_ram`, `sync_ram`, `lfsr16`, `dfs_generator`, `lee_solver` | Store, generate and solve the maze |
| **Display** | `vga_tile_draw`, `hex7seg`, `vga_adapter` | Maze → screen; numbers → 7-segment |

`maze_top` wires them together and holds a little glue logic.

## Each module in one sentence

| Module | Sentence |
| --- | --- |
| `ps2_rx` | Turns the keyboard's serial clock and data wires into bytes |
| `key_decoder` | Turns bytes into "generate", "solve" and speed commands, one per key press |
| `control_fsm` | Accepts a request only when idle, so only one algorithm ever touches the maze |
| `rate_divider` | Pulses `tick` 8, 32, 128 or 50 million times a second; the algorithms step only on a tick |
| `cycle_counter` | Counts the clocks the solver spends working; shown on HEX |
| `maze_ram` | The maze: one 3-bit tile code per address, two ports so drawing and editing never collide |
| `sync_ram` | A plain block RAM, used for the generator's stack and the solver's queue and arrows |
| `lfsr16` | A free-running pseudo-random number; the press timing makes it unpredictable |
| `dfs_generator` | Carves a random perfect maze using a stack |
| `lee_solver` | Floods from start with a queue, then traces back the shortest path |
| `vga_tile_draw` | Endlessly reads every tile and paints it as a 4x4 block of colour |
| `hex7seg` | One hex digit → seven segments |
| `vga_adapter` | Course-provided: frame buffer + VGA timing to drive the monitor |

## Shared rules every module follows

**Tile codes** (3 bits, stored in `maze_ram`):

| Code | 0 | 1 | 2 | 3 | 4 | 5 |
| --- | --- | --- | --- | --- | --- | --- |
| Name | WALL | PATH | START | END | VISITED | SOLUTION |
| Colour | blue | white | green | red | cyan | yellow |

**Address** = `{row[4:0], col[5:0]}`, 11 bits. Rows 0-28 and columns 0-38 are used. Start is (1,1); end is (27,37).

**Cells vs walls:** tiles at odd row *and* odd column are rooms ("cells"). The tiles between them are walls that can be knocked out. The border is always wall.

**Directions:** 0 = N, 1 = E, 2 = S, 3 = W. Reversing a direction is `dir ^ 2`.

**RAM latency:** every RAM gives its data one clock *after* the address. That's why every FSM has pairs of states like READ → CHECK: one state asks, the next uses the answer.

**Clock / reset:** everything runs on the 50 MHz `CLOCK_50`, and `KEY[0]` is an active-low synchronous reset.

## Following one key press all the way through

1. You press **S**. The keyboard sends an 11-bit frame for `1B`. `ps2_rx` assembles it and pulses `scan_valid`.
2. `key_decoder` sees `1B` while S isn't already held, and pulses `key_solve` for one clock.
3. `control_fsm` is IDLE, so it goes to SOLVE_START and pulses `solve_start`.
4. `lee_solver` starts. While it is `busy`, the mux in `maze_top` gives it maze RAM port A. `cycle_counter` clears.
5. The solver cleans old colours, then floods. Each step waits for `tick` and writes VISITED tiles, then SOLUTION tiles on the way back.
6. Meanwhile `vga_tile_draw` keeps reading port B. Every new cyan or yellow tile appears on the next repaint, well under a millisecond later.
7. The solver raises `done`. `control_fsm` returns to IDLE, the LEDs show found or not found, and the HEX displays show the cycle count.

Generate follows the same path with `G` → `key_generate` → `gen_start` → `dfs_generator`.

## Memory budget

| Memory | Words x bits | Used by |
| --- | --- | --- |
| VGA frame buffer | 19,200 x 3 | `vga_adapter` |
| Maze RAM | 2,048 x 3 | everyone |
| Queue | 2,048 x 11 | `lee_solver` |
| Parent arrows | 2,048 x 2 | `lee_solver` |
| Stack | 512 x 11 | `dfs_generator` |

That's about 96 kbit in total, out of roughly 4 Mbit on the chip.

## Speed (instant mode)

| Operation | Clocks | Time |
| --- | --- | --- |
| Generate | ~7,900 | 0.16 ms |
| Solve (including the clean sweep) | ~6,000-7,000 | 0.13 ms |
| One screen repaint | 19,227 | 0.38 ms |

Next: [modules/](README.md).
