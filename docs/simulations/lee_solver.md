# tb_lee_solver: maze solving

**Run:** `do tb_lee_solver.do`

## What is being tested

`lee_solver` finding the shortest route through the power-up maze (`mem/maze_init.hex`) with Lee's algorithm.

| Phase | States | Does |
| --- | --- | --- |
| Clean | CLEAN_READ, CLEAN_FIX | Visits all 2048 tiles and turns VISITED/SOLUTION from a previous solve back into PATH |
| Seed | SEED | Puts the start tile in the queue |
| Flood | POP, LOAD, PROBE, EXPAND | Takes the oldest tile from the queue (`cur`) and probes its 4 neighbours. Each PATH neighbour becomes VISITED, has "the way back to `cur`" written into the parent table, and joins the back of the queue |
| Backtrace | TRACE_READ, TRACE_STEP, TRACE_MARK | When a probe finds END: read the way back, step there, paint it SOLUTION. Repeat until START |
| Finish | FINISH | Raise `done` |

Because the queue is first-in first-out, tiles are reached in order of distance from the start (a growing ring). So the first time END is reached is along a shortest route.

## What the testbench does

1. Computes the shortest START→END distance its own way, by repeatedly relaxing distances in a loop. This is the reference answer.
2. Solves. It checks `found`, that `path_length` = reference - 1, that the number of yellow tiles matches, and that the yellow tiles form one unbroken chain: each has exactly 2 route neighbours, and START and END each have 1.
3. Solves again, which checks that the clean phase works and the cycle count is identical.
4. Solves with `tick` only every 8th clock (slow animation). The `working` cycle count must still be identical.
5. Walls off END and solves. `found` must be 0.

## Waves

| Label | Signal | Meaning |
| --- | --- | --- |
| `start`, `tick` | same | Start pulse; animation step enable |
| `state` | `DUT/state` | State name (see table above) |
| `cur row`, `cur col` | `DUT/cur` | Tile being expanded (flood) or traced (backtrace) |
| `probing` | `DUT/dir` | Neighbour direction being probed |
| `head`, `tail` | `DUT/head`, `DUT/tail` | Queue read and write positions. `tail - head` = tiles waiting |
| `parent_dir` | `DUT/parent_q` | Direction back toward START, read during the backtrace |
| `path_length` | `path_length` | Yellow tiles painted so far |
| `addr row`, `addr col` | `ram_addr` | Maze tile being read or written |
| `write`, `write_tile`, `read_tile` | `ram_we`, `ram_din`, `ram_q` | Maze RAM traffic |
| `working` | `working` | High when doing algorithm work. This drives the HEX cycle count |
| `done`, `found` | same | Result |

## What to look for

The script zooms to 82-86 µs, just after the clean phase, where the flood starts.

- The pattern POP, LOAD, then PROBE/EXPAND ×4. Each EXPAND that reads `PATH` writes `VISITED` and bumps `tail`.
- `head` chases `tail`. The flood ends when END is found (or, in the walled-off run, when `head` catches `tail`).
- Zoom out to find the backtrace: `state` alternates TRACE_READ/STEP/MARK, `parent_dir` steers `cur` back to (1,1), and `path_length` counts up to 181.
- `working` is low through the whole clean phase. In the slow-tick run, it also drops while sitting in POP waiting for `tick`.

## Expected transcript

```
reference shortest distance START->END = 182
ok: solver finished in 7020 clocks (2924 working)
ok: found = 1
ok: path_length vs reference = 181
ok: yellow tiles = 181
ok: yellow tiles without exactly 2 route neighbours = 0
ok: route neighbours of START = 1
ok: route neighbours of END = 1
... (repeated for the re-solve and the slow run)
ok: working cycles at 1/8 speed = 2924
ok: found with END walled off = 0
=== tb_lee_solver: ALL TESTS PASSED ===
```
