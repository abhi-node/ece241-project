# lee_solver

**File:** `rtl/maze/lee_solver.v`. **Started by:** `control_fsm.solve_start`. **Uses:** `maze_ram` port A, two `sync_ram`s (queue and parent), `tick`.

## What it does

Finds the shortest path from START to END with **Lee's algorithm**: a breadth-first flood out from the start, then a backtrace from the end.

## Ports

| Port | Meaning |
| --- | --- |
| `start`, `tick` | Go; animation step |
| `ram_addr`, `ram_din`, `ram_we`, `ram_q` | Maze RAM port A |
| `busy`, `done`, `found` | Running; finished; a path exists |
| `working` | Doing real work (drives `cycle_counter`) |
| `path_length` | Number of yellow tiles |

## The algorithm

1. **Clean:** turn any cyan or yellow left from the last solve back to white.
2. **Flood:** put START in a queue. Repeatedly take the oldest tile out and look at its 4 neighbours. Each white neighbour turns cyan, joins the back of the queue, and gets an arrow pointing back to the tile that found it.
3. **Backtrace:** when a neighbour is END, follow the arrows from END back to START, painting each tile yellow.

The queue is first-in first-out, so tiles come out in order of distance (ring 1, then ring 2...). That makes the first route to reach END a shortest one.

Classic Lee's algorithm stores a distance number in every tile. Storing just a 2-bit arrow (the parent direction) does the same backtrace for much less memory.

## States

| Phase | State | Does |
| --- | --- | --- |
| Clean | `CLEAN_READ` → `CLEAN_FIX` | Read tile; if VISITED/SOLUTION write PATH. All 2048 tiles |
| Seed | `SEED` | queue[0] = START; head = 0, tail = 1 |
| Flood | `POP` | Queue empty → `FINISH` (not found). Else wait for `tick` |
| | `LOAD` | `cur` = queue[head], head++ |
| | `PROBE` → `EXPAND` | x4 directions: present neighbour; then act on what's there |
| Trace | `TRACE_READ` | Wait for `tick`, read parent[cur] |
| | `TRACE_STEP` | `cur` = neighbour in the parent direction |
| | `TRACE_MARK` | At START → `FINISH`; else paint SOLUTION |
| | `FINISH` | `done` = 1 |

## Key code

**One neighbour calculator.** During `TRACE_STEP` it follows the parent arrow; otherwise it follows `dir`.

```verilog
wire [1:0] step_dir = (state == TRACE_STEP) ? parent_q : dir;
...
NORTH: neighbour = {cur_row - 5'd1, cur_col};
```

**What `EXPAND` decides:**

```verilog
wire [1:0] back_to_cur = dir ^ 2'b10;
wire       found_end   = (state == EXPAND) && (ram_q == T_END);
wire       found_open  = (state == EXPAND) && (ram_q == T_PATH);
```

On `found_open`, three writes happen in the same clock, one in each memory. The maze tile becomes VISITED:

```verilog
EXPAND:     begin                        ram_din = T_VISITED;  ram_we = found_open;   end
```

The neighbour is added to the queue at `tail`:

```verilog
.addr ((state == SEED) ? 11'd0 : (state == EXPAND) ? tail : head),
.din  ((state == SEED) ? START_ADDR : neighbour),
.we   ((state == SEED) || found_open),
```

And the arrow back to `cur` is stored for the neighbour:

```verilog
.addr ((state == TRACE_READ) ? cur : neighbour),
.din  (back_to_cur),
.we   (found_open || found_end),
```

A tile becomes VISITED the moment it is queued, so it can never be queued twice.

**A queue with no wrap-around.** Each tile is queued at most once, and 1,131 tiles < 2,048 slots. So `head` and `tail` just count up and "empty" is simply `head == tail`.

**Cycle counting that ignores animation:**

```verilog
wire stalled = !tick && (((state == POP) && !queue_empty) || (state == TRACE_READ));
assign working = busy && (state != CLEAN_READ) && (state != CLEAN_FIX) && !stalled;
```

## Numbers

On the power-up maze the path is 181 tiles and the solve takes 2,924 working cycles (about 7,000 clocks including the clean sweep).
