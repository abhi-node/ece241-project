# Simulations

Six self-checking testbenches live in `sim/`. Each comes as a pair: `tb_<name>.v` is the testbench and `tb_<name>.do` is the ModelSim script that compiles everything, opens the testbench, sets up a labelled waveform and runs it to the end.

| Testbench | Guide | What it covers | Sim time |
| --- | --- | --- | --- |
| `tb_lfsr16` | [lfsr16.md](lfsr16.md) | Random number source | 1.3 ms |
| `tb_ps2_keys` | [ps2_keys.md](ps2_keys.md) | Keyboard wire → commands | ~10 ms |
| `tb_control` | [control.md](control.md) | Control FSM and rate divider | 8 µs |
| `tb_dfs_generator` | [dfs_generator.md](dfs_generator.md) | Maze generation | ~330 µs |
| `tb_lee_solver` | [lee_solver.md](lee_solver.md) | Maze solving | ~660 µs |
| `tb_maze_top` | [maze_top.md](maze_top.md) | The whole board, end to end | ~3.6 ms |

## Running in ModelSim

1. Start ModelSim (the Intel FPGA edition from the labs is fine).
2. File > Change Directory, and pick the project's `sim/` folder. Every path in the scripts is relative to it.
3. In the Transcript, type one of:
   ```
   do tb_lee_solver.do
   ```
   The wave window opens with grouped, renamed signals, and the run stops at the end with a `$stop`. The transcript shows `ok` / `FAIL` lines and a final `=== tb_lee_solver: ALL TESTS PASSED ===`.
4. To run all six with no waves: `do run_all.do`.

If ModelSim asks "Are you sure you want to finish?", you hit Run again after the `$stop`. Answer No, and the waves stay up.

## Running without ModelSim

`sim/run_all.sh` runs every testbench with Icarus Verilog (`brew install icarus-verilog`) and prints just the result lines. Full logs go to `sim/out/`.

## How the waveforms are laid out

The internal signal names (`scan_valid`, `ram_we`, `check_dir`) are long and only mean something if you've read the code. The `.do` scripts relabel every wave and group them under dividers:

- **Labels are plain words.** `ram_we` is shown as `write`, `scan_valid` as `byte_ready`, and so on. Each guide has a table that maps every label to the real signal.
- **State machines show state names, not numbers.** `sim/radix.do` defines custom radixes, so a state shows as `CARVE_WALL` instead of `6`, a tile as `VISITED`, a direction as `N/E/S/W`, a colour as `CYAN`.
- **Addresses are split into row and column.** A maze address is `{row, col}`, so the scripts show the two halves as separate waves.
- **Each script zooms to the interesting part.** Use View > Zoom > Zoom Full to see the whole run.

To use the same names on a wave you add yourself, right-click it > Radix and pick `solver_state`, `tile`, `direction`, and so on.

## Shared files

| File | Purpose |
| --- | --- |
| `sim/compile.do` | Recreates the `work` library and compiles all RTL and testbenches |
| `sim/radix.do` | Named radixes for states, tiles, directions, speeds, colours |
| `sim/stubs/vga_adapter_stub.v` | Fake VGA adapter for `tb_maze_top`. It records pixels into an array instead of driving a monitor. Simulation only, never add it to Quartus |
| `mem/maze_init.hex` | The power-up maze, loaded by the generator, solver and top-level testbenches |
