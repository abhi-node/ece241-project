do compile.do
do radix.do
vsim -quiet tb_lfsr16
add wave -divider "LFSR"
add wave -label clk            /tb_lfsr16/clk
add wave -label reset_n        /tb_lfsr16/resetn
add wave -label random -radix hex /tb_lfsr16/q
add wave -label "random[1:0]" -radix unsigned {/tb_lfsr16/q[1:0]}
run -all
wave zoom range 0ns 1000ns
