# Abhijith Balagurusamy: Contributions

Abhi's side of the project is the maze itself: storing it, generating it, and solving it.

## Modules

| Module | File | What it does |
| --- | --- | --- |
| Maze RAM | `rtl/maze/maze_ram.v` | Dual-port 2048 x 3-bit tile memory shared by every part of the design; power-up maze from `mem/maze_init.hex` |
| Generic RAM | `rtl/maze/sync_ram.v` | Parameterised single-port block RAM used for the stack, queue and parent table |
| LFSR | `rtl/maze/lfsr16.v` | 16-bit maximal-length random number source |
| DFS generator | `rtl/maze/dfs_generator.v` | Stack-based depth-first search maze carving, with stack pointer and backtracking |
| Lee solver | `rtl/maze/lee_solver.v` | BFS flood fill with a FIFO queue and parent-direction table, then a backtrace FSM that paints the shortest path |
| Rate divider | `rtl/control/rate_divider.v` | Animation tick generator, four speeds |
| Power-up maze | `mem/maze_init.hex` | Hard-coded maze so the display could be tested before the generator existed |

## Design decisions

- **Tile maze instead of wall bits.** Every tile is either wall or open, so generating, solving and drawing all reduce to "read a tile, write a tile".
- **One RAM, two ports.** The algorithms write through port A and the display reads through port B, so the two sides never need a handshake.
- **Parent table instead of distance numbers.** Classic Lee's algorithm stores a distance in every tile. Storing the 2-bit direction back to the parent gives the same backtrace for a fraction of the memory.
- **Linear queue.** Each tile is enqueued at most once, so a 2048-entry queue never wraps and the head/tail logic is two counters.
- **Clean sweep before each solve**, so a maze can be solved repeatedly without regenerating.

## Verification

- `sim/tb_lfsr16.v`: full period and no lock-up.
- `sim/tb_dfs_generator.v`: perfect-maze check (all 266 cells open, 531 open tiles, border intact), and two runs give different mazes.
- `sim/tb_lee_solver.v`: path length matches a reference shortest distance, the yellow tiles form one unbroken chain, re-solve works, a walled-off end is reported as no path, and the cycle count does not depend on animation speed.

## Timeline

| Week | Work |
| --- | --- |
| Nov 9 | Maze RAM, LFSR and DFS generator written; power-up maze file |
| Nov 16 | Generator integrated with display and control; Lee solver (flood + backtrace) written and simulated; rate divider |

## Shared work

Top-level integration (`rtl/maze_top.v`), the system testbench (`sim/tb_maze_top.v`), debugging, and documentation.
