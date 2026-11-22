# Conceptual Design

Read these in order. Each step zooms in further.

1. **[overview.md](overview.md)**: what the project does, the demo, and the one idea that makes it work.
2. **[architecture.md](architecture.md)**: every module as a box, the signals between them, and how a key press becomes pixels.
3. **[modules/](modules/)**: one page per Verilog file. Each page covers what the file does, its ports, how it works, and the important pieces of code.

| Module page | File | Group |
| --- | --- | --- |
| [maze_top](modules/maze_top.md) | `rtl/maze_top.v` | Top level |
| [control_fsm](modules/control_fsm.md) | `rtl/control/control_fsm.v` | Control |
| [rate_divider](modules/rate_divider.md) | `rtl/control/rate_divider.v` | Control |
| [cycle_counter](modules/cycle_counter.md) | `rtl/control/cycle_counter.v` | Control |
| [maze_ram](modules/maze_ram.md) | `rtl/maze/maze_ram.v` | Maze |
| [sync_ram](modules/sync_ram.md) | `rtl/maze/sync_ram.v` | Maze |
| [lfsr16](modules/lfsr16.md) | `rtl/maze/lfsr16.v` | Maze |
| [dfs_generator](modules/dfs_generator.md) | `rtl/maze/dfs_generator.v` | Maze |
| [lee_solver](modules/lee_solver.md) | `rtl/maze/lee_solver.v` | Maze |
| [ps2_rx](modules/ps2_rx.md) | `rtl/input/ps2_rx.v` | Input |
| [key_decoder](modules/key_decoder.md) | `rtl/input/key_decoder.v` | Input |
| [vga_tile_draw](modules/vga_tile_draw.md) | `rtl/display/vga_tile_draw.v` | Display |
| [hex7seg](modules/hex7seg.md) | `rtl/display/hex7seg.v` | Display |
| [vga_adapter](modules/vga_adapter.md) | `rtl/vga_adapter/*.v` | Course-provided |

For running the testbenches and reading their waveforms, see [../simulations/](../simulations/README.md).
