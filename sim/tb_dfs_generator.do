do compile.do
do radix.do
vsim -quiet tb_dfs_generator
add wave -divider "Generator"
add wave -label clk                         /tb_dfs_generator/clk
add wave -label start                       /tb_dfs_generator/start
add wave -label state -radix generator_state /tb_dfs_generator/DUT/state
add wave -label row -radix unsigned         /tb_dfs_generator/DUT/row
add wave -label col -radix unsigned         /tb_dfs_generator/DUT/col
add wave -label checking -radix direction   /tb_dfs_generator/DUT/check_dir
add wave -label "unvisited NESW" -radix binary /tb_dfs_generator/DUT/unvisited
add wave -label chosen -radix direction     /tb_dfs_generator/DUT/chosen_dir
add wave -label stack_depth -radix unsigned /tb_dfs_generator/DUT/sp
add wave -divider "Maze RAM port A"
add wave -label "addr row" -radix unsigned  {/tb_dfs_generator/ram_addr[10:6]}
add wave -label "addr col" -radix unsigned  {/tb_dfs_generator/ram_addr[5:0]}
add wave -label write                       /tb_dfs_generator/ram_we
add wave -label write_tile -radix tile      /tb_dfs_generator/ram_din
add wave -label read_tile -radix tile       /tb_dfs_generator/ram_q
add wave -label done                        /tb_dfs_generator/done
run -all
wave zoom range 40.5us 44.5us
