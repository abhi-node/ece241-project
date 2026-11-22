# tb_dfs_generator: maze generation

**Run:** `do tb_dfs_generator.do`

## What is being tested

`dfs_generator` carving a maze into `maze_ram` with depth-first search, at full speed (`tick` tied high). The LFSR supplies the random directions.

The algorithm, one state at a time:

| State | Does |
| --- | --- |
| CLEAR | Writes WALL to all 2048 tiles (one per clock) |
| OPEN_START | Opens tile (1,1) |
| READ → CHECK | ×4: looks 2 tiles away in direction N/E/S/W. A neighbour is *unvisited* if it is in bounds and still WALL. READ presents the address and CHECK uses the answer, because the RAM takes a clock |
| PICK | No unvisited neighbours → BACKTRACK. Otherwise choose one at random |
| CARVE_WALL | Opens the tile between here and the chosen cell |
| CARVE_CELL | Opens the chosen cell, pushes the current position on the stack, moves there |
| BACKTRACK → RESUME | Pops the previous position off the stack and checks again from there |
| MARK_START, MARK_END | Paints the green start and red end tiles, then done |

## What the testbench does

Generates twice, with a 777-clock gap so the LFSR is in a different place. After each run it checks the result is a perfect maze:

- every one of the 266 cells (odd row, odd column) is open
- the border and every even-row/even-column post is wall
- exactly 531 tiles are open = 266 cells + 265 knocked-out walls. A tree always has one fewer link than nodes, so this proves the maze is connected and has no loops
- start and end are marked

It also checks the two mazes differ, then prints the second one as ASCII art in the transcript.

## Waves

| Label | Signal | Meaning |
| --- | --- | --- |
| `start` | `start` | One-clock start pulse |
| `state` | `DUT/state` | State name (see table above) |
| `row`, `col` | `DUT/row`, `DUT/col` | The explorer's current cell |
| `checking` | `DUT/check_dir` | Direction being probed in READ/CHECK |
| `unvisited NESW` | `DUT/unvisited` | 4 bits, one per direction. Bit 0 = N, bit 3 = W |
| `chosen` | `DUT/chosen_dir` | Direction picked in PICK |
| `stack_depth` | `DUT/sp` | Stack pointer: how far the explorer is from the start along its string |
| `addr row`, `addr col` | `ram_addr[10:6]`, `ram_addr[5:0]` | Tile being read or written |
| `write` | `ram_we` | High when writing a tile |
| `write_tile` | `ram_din` | Tile being written (WALL, PATH, START, END) |
| `read_tile` | `ram_q` | Tile read back (valid in CHECK) |
| `done` | `done` | Goes high when the maze is finished |

## What to look for

The script zooms to 40.5-44.5 µs, right where CLEAR ends and carving starts.

- `state` cycles READ, CHECK ×4, then PICK, CARVE_WALL, CARVE_CELL.
- In CARVE_WALL the address is 1 tile from (`row`, `col`). In CARVE_CELL it is 2 tiles away, and `stack_depth` goes up by one.
- After CARVE_CELL, `row`/`col` jump by 2 in the `chosen` direction.
- Zoom out to see `stack_depth` rise and fall like a mountain range as the explorer digs and backtracks. It returns to 0 just before `done`.

## Expected transcript

```
ok: generated in 7891 clocks, max stack depth 196
ok: 531 open tiles, all 266 cells carved, border intact
ok: generated in 7891 clocks, max stack depth 199
ok: 531 open tiles, all 266 cells carved, border intact
ok: second maze differs in 240 tiles
#######################################
#S    #   #       # ...
=== tb_dfs_generator: ALL TESTS PASSED ===
```
Exact numbers depend on the random directions.
