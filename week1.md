# Quartus steps for the Milestone 1 demo

The code has not been compiled yet. Do steps 1-5 tonight or early, not in the lab.

## 1. Simulate first (ModelSim)

1. Unzip the code. In ModelSim: File > Change Directory to that folder.
2. Transcript: `do run_all.do`
3. Every testbench should print `ALL TESTS PASSED`. Fix any errors before going to Quartus.

## 2. Create the project

1. File > New Project Wizard. Put the project in a new folder.
2. Top-level entity name: `milestone1_top`
3. Device: `5CSEMA5F31C6` (DE1-SoC).

## 3. Add files

Copy into the project folder, then Project > Add/Remove Files:

- `milestone1_top.v`
- `lfsr16.v`, `maze_ram.v`, `stack_ram.v`, `dfs_generator.v`, `rate_divider.v`
- `ps2_rx.v`, `key_decoder.v`, `vga_tile_draw.v`, `control_fsm.v`, `hex7seg.v`
- Course VGA adapter: `vga_adapter.v`, `vga_address_translator.v`, `vga_controller.v`, `vga_pll.v`

Copy into the project folder only (do not need adding): `maze_init.hex`, `black.mif`

Do NOT add any `tb_*.v` file, especially `tb_vga_adapter_stub.v`.

## 4. Pin assignments

Assignments > Import Assignments > select the course `DE1_SoC.qsf`.

## 5. Compile

Processing > Start Compilation.

| Error | Fix |
| --- | --- |
| Port `colour` / `plot` / `VGA_BLANK` does not exist on `vga_adapter` | Add `` `define VGA_NEW_ADAPTER `` as the first line of `milestone1_top.v`, then compare that instantiation with your adapter's port list |
| Cannot open `maze_init.hex` or `black.mif` | File is not in the project folder |
| `vga_adapter` module not found | Adapter files not added |
| Syntax error in one of our files | Fix it, re-run that module's testbench, recompile |

Check the warnings for "inferring latch". There should be none.

## 6. Program the board

1. Plug in: USB-Blaster cable, VGA monitor, PS/2 keyboard, power.
2. Tools > Programmer > Hardware Setup > DE-SoC.
3. Auto Detect > `5CSEMA5`. Select the FPGA device > Change File > `output_files/milestone1_top.sof`.
4. Tick Program/Configure > Start.

## 7. Check the demo

| Do | Expect |
| --- | --- |
| After programming | Blue/white maze on screen, green top-left, red bottom-right. HEX reads `000100` |
| Press any key | HEX1-0 shows its scan code (G = `34`) |
| Press G | Screen turns blue, a white path carves out over about 8 s. HEX5-3 counts up and down. LEDR[9] on |
| Finished | LEDR[9] off, LEDR[2] on, HEX5-3 back to `000` |
| Press 1 / 2 / 3 / 4, then G | Slow / medium / fast / instant |
| KEY[1] | Same as G (backup if the keyboard fails) |
| SW[9] up | Instant generation |
| KEY[0] | Reset |

## 8. If it does not work

| Symptom | Check |
| --- | --- |
| Black screen | Monitor input; adapter files; `black.mif`; adapter port names |
| All blue at start | `maze_init.hex` was not found: put it in the project folder, recompile |
| HEX1-0 stays `00` | Keyboard in the PS/2 port; pin assignments imported. LEDR[4] on = frames arriving but failing parity |
| G does nothing but KEY[1] works | Keyboard path. Demo with KEY[1] and show the `tb_ps2_rx` simulation |
| Maze never finishes | Note LEDR[1:0] and HEX5-3, compare with `tb_dfs_generator` |

## 9. Bring to the lab

- The compiled project on a USB stick or your laptop.
- The milestone PDF, submitted to Quercus before the lab, with screenshots pasted in.
- A phone video of the demo working, as a backup.
