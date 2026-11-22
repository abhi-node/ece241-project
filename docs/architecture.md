# Architecture

## The one idea

The maze is a picture stored in memory. One part of the circuit edits the picture; another part copies it to the screen, non-stop. They never talk to each other. Everything else decides *when* to edit and *what* to edit.

Picture a whiteboard with a camera pointed at it. The generator and solver take turns drawing on the board. The VGA drawer is the camera. The viewer sees each change appear live, and nobody ever has to say "I changed something".

## Shared conventions

**Grid.** 29 rows x 39 columns of tiles. Each tile is 4x4 pixels on the 160x120 VGA adapter, so the maze is 156x116 pixels, centred with a 2-pixel border.

**Address.** `{row[4:0], col[5:0]}`, 11 bits. Row 1, column 1 is address 65. Addresses with column 39-63 or row 29-31 exist but are never drawn.

**Cells and walls.** Tiles with odd row and odd column are *cells* (14 x 19 = 266 of them). Tiles between two cells are walls the generator may knock out. Tiles with even row and even column are always wall. The outer ring is always wall.

**Tile codes (3 bits).**

| Code | Name | Written by | Colour |
| --- | --- | --- | --- |
| 0 | WALL | generator (clear) | blue |
| 1 | PATH | generator (carve), solver (clean) | white |
| 2 | START (1,1) | generator | green |
| 3 | END (27,37) | generator | red |
| 4 | VISITED | solver (flood) | cyan |
| 5 | SOLUTION | solver (backtrace) | yellow |

**Directions.** 0 north (row-1), 1 east (col+1), 2 south (row+1), 3 west (col-1). Turning around is `dir ^ 2`.

**Clock and reset.** Everything runs on `CLOCK_50`. `KEY[0]` is an active-low synchronous reset. Every block RAM returns data one clock after the address, so every FSM spends one state presenting an address and the next state using the data.

## Data flow

1. A key press reaches `ps2_rx` as an 11-bit serial frame and becomes a byte. `key_decoder` turns bytes into a one-clock `key_generate` or `key_solve` pulse, or a new `speed_sel`. `KEY[1]` and `KEY[2]` are synchronised and edge-detected in `maze_top` as backups.
2. `control_fsm` accepts the request only when idle and sends a one-clock `gen_start` or `solve_start`.
3. The chosen algorithm runs. It owns maze RAM port A (`maze_top` gives the port to the solver while `solve_busy`, otherwise to the generator). Each animated step waits for a `tick` from `rate_divider`.
4. `vga_tile_draw` loops over all 1,131 tiles forever, reading port B and writing 16 pixels per tile into the course `vga_adapter`. The adapter's own controller scans its frame buffer out to the monitor at 60 Hz.
5. When the algorithm finishes it raises `done`; `control_fsm` returns to idle. During a solve, `cycle_counter` counts every clock the solver is doing real work, and the HEX displays show the result.

## Modules

### Maze (Abhi)

**`maze_ram`**: the whiteboard. 2048 x 3-bit dual-port RAM. Port A reads and writes for the algorithms; port B is read-only for the display. Two ports mean the display never waits for the algorithms or blocks them. Preloaded from `mem/maze_init.hex` so a maze is visible at power-up.

**`sync_ram`**: a generic single-port RAM with width and depth parameters. Used for the DFS stack (512 x 11), the BFS queue (2048 x 11) and the BFS parent table (2048 x 2).

**`lfsr16`**: the dice. A 16-bit maximal-length LFSR that shifts every clock. The sequence is fixed, but it is sampled at whatever clock cycle the human pressed G, and that timing is the real randomness.

**`dfs_generator`**: the explorer with a pickaxe and a ball of string.
- Clear every tile to WALL, open the start cell.
- Look two tiles away in each direction. Is the neighbour cell in bounds and still WALL?
- If any are, wait for a tick, pick one using the LFSR, knock out the wall between, open the cell, push where you were, and move.
- If none are, pop the stack and look again from there.
- When the stack is empty every cell has been reached. Mark START and END.

It only ever digs into solid rock, so it never joins two corridors. The result has no loops and reaches every cell, which means exactly one route between any two tiles. The testbench checks this: 266 cells + 265 knocked-out walls = 531 open tiles. That is a spanning tree.

**`lee_solver`**: flood, then follow the arrows back.
- *Clean*: sweep all 2048 tiles and turn old VISITED/SOLUTION tiles back to PATH, so S can be pressed again.
- *Flood (BFS)*: put START in the queue. Repeatedly dequeue a tile and probe its 4 neighbours. Each PATH neighbour becomes VISITED (cyan) and is enqueued, and the parent table stores the direction back to the tile it came from. The flood spreads outward one ring at a time, so every tile is first reached by a shortest route.
- *Backtrace*: when a probe hits END, read END's parent direction, step that way, paint SOLUTION (yellow), and repeat until START.

The queue's head and tail only ever count up, because each tile is enqueued at most once and 1,131 < 2,048. That means there is no wrap-around logic. `working` is low while cleaning and while waiting for a tick, so the HEX cycle count is the same at every animation speed.

### Input, control and display (Ali)

**`ps2_rx`**: the listener. Synchronises the keyboard's clock and data lines, shifts in one bit on each falling PS/2 clock edge, and checks the start, stop and odd-parity bits. A timeout resets the bit counter if the keyboard goes quiet mid-frame, so one glitch can't misalign every later byte.

**`key_decoder`**: the interpreter. A release is `F0` + code, and holding a key auto-repeats the make code. A "release next" flag and per-key "held" flags turn this into exactly one command per physical press.

**`control_fsm`**: the referee. Five states (IDLE, GEN_START, GENERATING, SOLVE_START, SOLVING). Requests are accepted only in IDLE, so a second G halfway through a generate can't corrupt the maze.

**`rate_divider`**: the slow-motion dial. Counts clocks and pulses `tick` every 6.25M / 1.5625M / 390,625 / 1 clocks.

**`cycle_counter`**: the stopwatch. Clears on `solve_start`, counts while the solver is working, and saturates rather than wrapping.

**`vga_tile_draw`**: the camera. Two states: FETCH presents the tile address, then PLOT writes the tile's colour to 16 pixels. The address does not change during PLOT, so the RAM output stays valid for the whole block. One frame is 17 x 1,131 = 19,227 clocks, which is about 2,600 frames per second.

**`hex7seg`**: one hex digit to seven active-low segments.

### Course-provided

**`vga_adapter`**, **`vga_controller`**, **`vga_address_translator`**, **`vga_pll`**: the ECE 241 VGA adapter. It holds a 160x120 x 3-bit frame buffer. Writing `color` at (`x`, `y`) with `write` high updates one pixel. Its controller scans the buffer out to the monitor. These files are unmodified.

### Top level

**`maze_top`** wires the modules together and to the board pins. It adds only glue logic: the push-button synchronisers, the port A multiplexer, status LEDs and the HEX view switch.

## Resource budget

| Memory | Size | Bits |
| --- | --- | --- |
| VGA frame buffer | 19,200 x 3 | 57,600 |
| Maze RAM | 2,048 x 3 | 6,144 |
| BFS queue | 2,048 x 11 | 22,528 |
| BFS parent table | 2,048 x 2 | 4,096 |
| DFS stack | 512 x 11 | 5,632 |

The total is about 96 kbit. The Cyclone V on the DE1-SoC has about 4 Mbit of M10K memory.

## Timing (instant speed, measured in simulation)

| Operation | Clocks | Time at 50 MHz |
| --- | --- | --- |
| Generate | ~7,900 | 0.16 ms |
| Solve, including the 4,096-clock clean sweep | ~6,000-7,000 | ~0.13 ms |
| Solve, working cycles only (shown on HEX) | ~2,000-3,000 | ~0.05 ms |
| One full screen repaint | 19,227 | 0.38 ms |

## Why it is split this way

Each module does one job and talks to its neighbours through a few signals. That lets two people build halves separately and test each piece alone in simulation. When something breaks, you find the fault by asking "which box stopped doing its job?"
