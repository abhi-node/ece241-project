# Project Proposal: ECE 241

**Group members:** Abhijith Balagurusamy, Ali Alali

## Summary

A maze generator and solver that runs entirely on the FPGA. The board generates a random maze with stack DFS and solves it with Lee's algorithm. The VGA animates the maze and the solving, the PS/2 keyboard controls generate, solve and animation speed, and the HEX displays show the clock cycles taken to solve.

## Schedule

| Week | Abhi | Ali |
| --- | --- | --- |
| Nov 9 | Sim maze RAM and DFS maze generator | Sim VGA hard-coded maze from file and PS/2 input |
| Nov 16 | DFS maze gen on board; sim BFS solving | On board: PS/2 input and VGA draw; sim control FSM |
| Nov 23 | On board: BFS solver + rate divider; polish | On board: PS/2 linked to FSM + stat counters; polish |
| Nov 30 | More maze generation algorithms, UI touch-ups; slides and practice | Performance improvements; slides and practice |

## Division of work

| Member | Tasks |
| --- | --- |
| Abhi | LFSR random generator; DFS maze generator (stack RAM and pointer); BFS solver and backtrace FSM; maze RAM and access |
| Ali | VGA tile drawing FSM; control FSM; PS/2 keyboard decoder; HEX stat counters; cursor wall editing |

**Shared:** integration, debugging, polish, presentation slides.
**Stretch:** racing solver, algorithm racing.
