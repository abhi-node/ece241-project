do compile.do
do radix.do
vsim -quiet tb_control
add wave -divider "Requests in"
add wave -label clk                       /tb_control/clk
add wave -label go_generate               /tb_control/go_generate
add wave -label go_solve                  /tb_control/go_solve
add wave -label gen_done                  /tb_control/gen_done
add wave -label solve_done                /tb_control/solve_done
add wave -divider "Control FSM"
add wave -label state -radix control_state /tb_control/state
add wave -label busy                      /tb_control/busy
add wave -label GEN_START                 /tb_control/gen_start
add wave -label SOLVE_START               /tb_control/solve_start
add wave -divider "Rate divider"
add wave -label speed -radix speed        /tb_control/speed_sel
add wave -label count -radix unsigned     /tb_control/RATE/count
add wave -label tick                      /tb_control/tick
run -all
wave zoom range 0ns 600ns
