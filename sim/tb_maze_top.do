do compile.do
do radix.do
vsim -quiet tb_maze_top
add wave -divider "Board inputs"
add wave -label clk                           /tb_maze_top/clk
add wave -label reset_n                       {/tb_maze_top/KEY[0]}
add wave -label generate_btn                  {/tb_maze_top/KEY[1]}
add wave -label solve_btn                     {/tb_maze_top/KEY[2]}
add wave -divider "Control"
add wave -label state -radix control_state    /tb_maze_top/DUT/control_state
add wave -label generator -radix generator_state /tb_maze_top/DUT/GENERATOR/state
add wave -label solver -radix solver_state    /tb_maze_top/DUT/SOLVER/state
add wave -label tick                          /tb_maze_top/DUT/tick
add wave -divider "Maze RAM port A"
add wave -label owner_is_solver               /tb_maze_top/DUT/solve_busy
add wave -label write                         /tb_maze_top/DUT/MAZE/we_a
add wave -label write_tile -radix tile        /tb_maze_top/DUT/MAZE/din_a
add wave -divider "Display"
add wave -label x -radix unsigned             /tb_maze_top/DUT/vga_x
add wave -label y -radix unsigned             /tb_maze_top/DUT/vga_y
add wave -label colour -radix colour          /tb_maze_top/DUT/vga_color
add wave -label plot                          /tb_maze_top/DUT/vga_write
add wave -divider "Outputs"
add wave -label solve_cycles -radix unsigned  /tb_maze_top/DUT/solve_cycles
add wave -label path_length -radix unsigned   /tb_maze_top/DUT/path_length
add wave -label LEDR -radix binary            /tb_maze_top/LEDR
run -all
wave zoom full
