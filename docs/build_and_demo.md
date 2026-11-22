# Build and Demo

## 1. Simulate first

Every testbench prints `ok` / `FAIL` lines and finishes with `=== tb_name: ALL TESTS PASSED ===`.

| Tool | Command |
| --- | --- |
| Icarus Verilog | `sim/run_all.sh` (logs land in `sim/out/`) |
| ModelSim, one testbench with waves | File > Change Directory > `sim/`, then `do tb_lee_solver.do` (or any `tb_*.do`) |
| ModelSim, all six | `do run_all.do` |

| Testbench | What it proves |
| --- | --- |
| `tb_lfsr16` | Full 65,535-state period, never stuck at zero |
| `tb_ps2_keys` | Real PS/2 frames decode; held keys give one command; bad parity is rejected |
| `tb_control` | One start pulse per request; requests are ignored while busy; tick rates are correct |
| `tb_dfs_generator` | Two generated mazes are both perfect mazes, and they differ |
| `tb_lee_solver` | Path matches a reference shortest distance, re-solve works, a walled-off END is reported as not found, cycle count is the same at any speed |
| `tb_maze_top` | Whole system: solve, generate, solve. Every screen pixel matches maze RAM. The final screen is saved to `sim/out/frame.ppm` |

[simulations/](simulations/README.md) has a guide for each testbench: what it tests, what every wave means, and what to look for.

`tb_maze_top` uses `sim/stubs/vga_adapter_stub.v` in place of the real adapter. Never add the stub to Quartus.

## 2. Compile in Quartus

1. File > Open Project, and pick `quartus/maze.qpf`. The device (5CSEMA5F31C6), the top level (`maze_top`) and all source files are already set; Project > Add/Remove Files shows the list.
2. Assignments > Import Assignments, and select the course `DE1_SoC.qsf` for the pin locations. This only has to be done once.
3. Processing > Start Compilation.

To build a project from scratch instead: File > New Project Wizard, with the working directory set to the `quartus/` folder. Name the project `maze`, set the top level to `maze_top`, and choose the device 5CSEMA5F31C6. Then add every `.v` file under `rtl/`, including `rtl/vga_adapter/`. Do not add anything from `sim/`.

The memory files are found relative to the `quartus/` folder (`../mem/maze_init.hex`, `../mem/black.mif`). Keep the folder structure as it is.

| Message | Meaning |
| --- | --- |
| PLL warnings, `VGA_SYNC_N` stuck at VCC | Expected from the course adapter. Ignore |
| Cannot open `maze_init.hex` / `black.mif` | The project was moved out of `quartus/`. Restore the folder layout |
| Inferring latch | Should never appear. Report which module |

## 3. Program

1. Plug in the USB-Blaster cable, VGA monitor, PS/2 keyboard and power.
2. Tools > Programmer > Hardware Setup > DE-SoC.
3. Auto Detect > `5CSEMA5`. Select the FPGA device > Change File > `quartus/output_files/maze.sof`.
4. Tick Program/Configure > Start.

## 4. Demo checklist

| Do | Expect |
| --- | --- |
| After programming | Blue/white maze, green square top-left, red square bottom-right. HEX reads `000000` |
| Press `S` | Cyan floods out from green. When it reaches red, a yellow line traces back. `LEDR[4]` lights. HEX shows the solve cycle count |
| Press `S` again | The old colours clear and the same solve replays. HEX shows the same count |
| Press `G` | Screen turns blue, then a white maze is carved out. `LEDR[9]` is on while busy, and `LEDR[3]` lights when done |
| Press `1` / `2` / `3` / `4`, then `G` or `S` | Slow / medium / fast / instant animation |
| `SW[0]` up | HEX5-4 last scan code, HEX3 speed, HEX2-0 stack depth (while generating) or path length |
| `KEY[1]` / `KEY[2]` | Same as `G` / `S` (backup if the keyboard fails) |
| `SW[9]` up | Instant speed regardless of keyboard |
| `KEY[0]` | Reset. The maze stays on screen; RAM is not cleared |

## 5. If it doesn't work

| Symptom | Check |
| --- | --- |
| Black screen | Monitor input, VGA cable, adapter files in the project, pin assignments imported |
| Magenta tiles | A tile code above 5 is in maze RAM. Check `maze_init.hex` |
| All blue at power-up | `maze_init.hex` not found. Check the folder layout and recompile |
| `SW[0]` up shows HEX5-4 stuck at `00` | Keyboard not seen. Check the PS/2 port and the pins. `LEDR[8]` on means frames arrive but fail parity |
| `G` / `S` do nothing but the buttons work | Keyboard path. Demo with the buttons and show `tb_ps2_keys` |
| Generate never finishes | Note `LEDR[2:0]` (control state) and the stack depth view, then compare with `tb_dfs_generator` |
