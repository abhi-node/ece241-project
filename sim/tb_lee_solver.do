do compile.do
do radix.do
vsim -quiet tb_lee_solver
add wave -divider "Solver"
add wave -label clk                          /tb_lee_solver/clk
add wave -label start                        /tb_lee_solver/start
add wave -label tick                         /tb_lee_solver/tick
add wave -label state -radix solver_state    /tb_lee_solver/DUT/state
add wave -label "cur row" -radix unsigned    {/tb_lee_solver/DUT/cur[10:6]}
add wave -label "cur col" -radix unsigned    {/tb_lee_solver/DUT/cur[5:0]}
add wave -label probing -radix direction     /tb_lee_solver/DUT/dir
add wave -divider "Queue"
add wave -label head -radix unsigned         /tb_lee_solver/DUT/head
add wave -label tail -radix unsigned         /tb_lee_solver/DUT/tail
add wave -divider "Backtrace"
add wave -label parent_dir -radix direction  /tb_lee_solver/DUT/parent_q
add wave -label path_length -radix unsigned  /tb_lee_solver/path_length
add wave -divider "Maze RAM port A"
add wave -label "addr row" -radix unsigned   {/tb_lee_solver/ram_addr[10:6]}
add wave -label "addr col" -radix unsigned   {/tb_lee_solver/ram_addr[5:0]}
add wave -label write                        /tb_lee_solver/ram_we
add wave -label write_tile -radix tile       /tb_lee_solver/ram_din
add wave -label read_tile -radix tile        /tb_lee_solver/ram_q
add wave -divider "Result"
add wave -label working                      /tb_lee_solver/working
add wave -label done                         /tb_lee_solver/done
add wave -label found                        /tb_lee_solver/found
run -all
wave zoom range 82us 86us
