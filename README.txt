ECE241 Project - Milestone 1 - Maze generator / solver
Abhijith Balagurusamy, Ali Alali
=====================================================================

IMPORTANT: this code was written without access to ModelSim or Quartus.
Run every testbench (step 1) BEFORE the lab and fix anything the tools
report. The algorithm of the generator was checked with a software model,
but the Verilog itself has not been compiled.

FILES
  Design - Abhi          lfsr16.v  maze_ram.v  stack_ram.v  dfs_generator.v
                         rate_divider.v
  Design - Ali           ps2_rx.v  key_decoder.v  vga_tile_draw.v
                         control_fsm.v  hex7seg.v
  Design - shared        milestone1_top.v   (top-level entity)
  Memory files           maze_init.hex  (hard-coded maze, used by maze_ram)
                         maze_init.mif  (same data in .mif form)
                         black.mif      (VGA adapter background)
  Testbenches            tb_<module>.v  + tb_<module>.do   (one per stage)
                         tb_vga_adapter_stub.v  (simulation only!)
                         run_all.do

1. MODELSIM
   - Open ModelSim, File > Change Directory to this folder.
   - Transcript:  do tb_lfsr16.do      (or any other tb_*.do)
   - Each testbench prints ok/FAIL lines and a final
     "=== tb_xxx: ALL TESTS PASSED ===". Waves are added automatically.
   - do run_all.do   runs all nine.
   - maze_init.hex must be in the folder ModelSim runs from.

2. QUARTUS (DE1-SoC, 5CSEMA5F31C6)
   - New project, top-level entity: milestone1_top
   - Add: the 11 design .v files above (NOT the tb_ files)
   - Add the course VGA adapter files: vga_adapter.v, vga_address_translator.v,
     vga_controller.v, vga_pll.v   (starter code - cite it, it is not ours)
   - Put maze_init.hex and black.mif in the project folder.
   - Import the DE1-SoC pin assignments (DE1_SoC.qsf) as in the labs.
   - If your VGA adapter uses the port names color / write and the parameter
     COLOR_DEPTH, add  `define VGA_NEW_ADAPTER  at the top of milestone1_top.v
     (or set it under Assignments > Settings > Verilog HDL Input > Macro).
   - Compile, program.

3. BOARD CONTROLS
   KEY[0] reset | KEY[1] generate | SW[9] full speed
   Keyboard: G generate, 1/2/3/4 speed (slow, medium, fast, instant), S (M2)
   HEX1-0 last scan code | HEX2 speed | HEX5-3 stack depth
   LEDR[1:0] control state | LEDR[2] done | LEDR[3] S toggle
   LEDR[4] PS/2 error | LEDR[9] busy
