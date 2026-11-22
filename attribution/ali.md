# Ali Alali: Contributions

Ali's side of the project is everything between the maze and the person: keyboard input, control, the screen and the statistics.

## Modules

| Module | File | What it does |
| --- | --- | --- |
| PS/2 receiver | `rtl/input/ps2_rx.v` | Synchronises the keyboard lines, shifts in 11-bit frames, checks start/stop/parity, and recovers from glitches with a timeout |
| Key decoder | `rtl/input/key_decoder.v` | Make/break tracking and held-key filtering; G, S and 1-4 become commands |
| Control FSM | `rtl/control/control_fsm.v` | Lets one algorithm run at a time; turns requests into start pulses |
| Cycle counter | `rtl/control/cycle_counter.v` | Counts the clock cycles the solve takes, shown on the HEX displays |
| VGA tile drawer | `rtl/display/vga_tile_draw.v` | Repaints the maze RAM onto the course VGA adapter as 4x4-pixel tiles, forever |
| HEX decoder | `rtl/display/hex7seg.v` | One hex digit to seven segments |
| Background image | `mem/black.mif` | Initial VGA frame buffer contents |

## Design decisions

- **Continuous repaint instead of change tracking.** The drawer does not know when the maze changes. It just redraws everything about 2,600 times a second, so the display logic is two counters and a two-state FSM.
- **Own PS/2 receiver** instead of the course controller, with a timeout so one missed edge can't misalign every later byte.
- **Held-key flags** so keyboard auto-repeat can't fire dozens of generates.
- **Cycle count that ignores the animation.** The counter only runs while the solver is doing real work, so the number on the HEX displays measures the algorithm, not the chosen speed.

## Verification

- `sim/tb_ps2_keys.v`: real PS/2 waveforms; one command per press, release handling, extended keys ignored, bad parity rejected.
- `sim/tb_control.v`: one start pulse per request, requests ignored while busy, generate wins a tie, tick rates are correct.
- `sim/tb_maze_top.v`: every pixel on the captured screen matches the maze RAM after solve, generate and solve.

## Timeline

| Week | Work |
| --- | --- |
| Nov 9 | VGA tile drawer against the hard-coded maze; PS/2 receiver and key decoder |
| Nov 16 | Control FSM extended for solving; HEX statistics and cycle counter; VGA adapter hookup fixed to match the course adapter's real ports (`color`, `write`, `COLOR_DEPTH`) |

## Shared work

Top-level integration (`rtl/maze_top.v`), the system testbench (`sim/tb_maze_top.v`), debugging, and documentation.

## Not our code

`rtl/vga_adapter/` (`vga_adapter.v`, `vga_controller.v`, `vga_address_translator.v`, `vga_pll.v`) is the ECE 241 course-provided VGA adapter, used unmodified.
