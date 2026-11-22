# dfs_generator

**File:** `rtl/maze/dfs_generator.v`. **Started by:** `control_fsm.gen_start`. **Uses:** `maze_ram` port A, `sync_ram` (stack), `lfsr16`, `tick`.

## What it does

Carves a random **perfect maze** (no loops, every cell reachable) using depth-first search with an explicit stack.

## Ports

| Port | Meaning |
| --- | --- |
| `start`, `tick`, `random_dir` | Go; animation step; 2 random bits |
| `ram_addr`, `ram_din`, `ram_we`, `ram_q` | Maze RAM port A |
| `busy`, `done` | Running; finished (stays high until next start) |
| `stack_depth` | Stack pointer, shown on HEX in debug view |

## The algorithm

Picture an explorer with a pickaxe and a ball of string.

1. Fill everything with rock (WALL), and open the start cell (1,1).
2. Look at the 4 cells **two** tiles away. Which ones are in bounds and still solid?
3. If any are: pick one at random, dig through the wall between, step in, and lay string behind you (push).
4. If none are: follow the string back one cell (pop) and go to step 2.
5. When the string is fully wound up (stack empty), every cell has been dug. Paint START and END.

You only ever dig into solid rock, so you never break into an existing corridor. That's why there are no loops.

## States

| State | Does | Next |
| --- | --- | --- |
| `CLEAR` | Write WALL to address `clear_addr`, count 0→2047 | `OPEN_START` |
| `OPEN_START` | Write PATH at (1,1), reset position and stack | `READ` |
| `READ` | Present address of neighbour `check_dir` | `CHECK` |
| `CHECK` | `unvisited[check_dir] = in_bounds && tile == WALL` | `READ` x4, then `PICK` |
| `PICK` | None unvisited → `BACKTRACK`; else wait for `tick`, choose | `CARVE_WALL` |
| `CARVE_WALL` | Write PATH one tile away | `CARVE_CELL` |
| `CARVE_CELL` | Write PATH two tiles away, push (row, col), move there | `READ` |
| `BACKTRACK` | Stack empty → `MARK_START`; else read stack[sp-1], sp-- | `RESUME` |
| `RESUME` | Move to the popped position | `READ` |
| `MARK_START`, `MARK_END` | Paint START and END, raise `done` | `IDLE` |

## Key code

**One "probe" calculator serves every state.** It looks in `probe_dir`, 1 or 2 tiles away, and also says whether that is still inside the border:

```verilog
wire       carving   = (state == CARVE_WALL) || (state == CARVE_CELL);
wire [1:0] probe_dir = carving ? chosen_dir : check_dir;
wire [1:0] distance  = (state == CARVE_WALL) ? 2'd1 : 2'd2;
...
NORTH: begin probe_row = row - distance; probe_in_bounds = (row > 5'd1); end
```

**Random pick with a guaranteed hit.** Start at the random direction and rotate through the other three. The first unvisited one wins. `PICK` only gets here if at least one is unvisited.

```verilog
if      (unvisited[try0]) random_unvisited = try0;
else if (unvisited[try1]) random_unvisited = try1;
...
```

**Stack.** A push happens in `CARVE_CELL` (store where you are *before* moving). A pop reads address `sp-1` in `BACKTRACK`, and the data arrives in `RESUME`.

```verilog
.addr ((state == BACKTRACK) ? sp - 9'd1 : sp),
.din  ({row, col}),
.we   (state == CARVE_CELL),
```

**RAM writes in one combinational block.** The address defaults to the probe tile, and each state overrides only what it needs:

```verilog
ram_addr = {probe_row, probe_col};
case (state)
    CLEAR:      begin ram_addr = clear_addr; ram_din = T_WALL; ram_we = 1'b1; end
    CARVE_WALL: begin                        ram_din = T_PATH; ram_we = 1'b1; end
```

## Numbers

266 cells, 265 walls knocked out, 531 open tiles. About 7,900 clocks at instant speed. Maximum stack depth is around 200, well under 512.
