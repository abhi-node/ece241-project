do compile.do
do radix.do
vsim -quiet tb_ps2_keys
add wave -divider "PS/2 wires"
add wave -label ps2_clk        /tb_ps2_keys/ps2_clk
add wave -label ps2_data       /tb_ps2_keys/ps2_dat
add wave -divider "Receiver"
add wave -label bit_count -radix unsigned /tb_ps2_keys/RX/bit_count
add wave -label byte -radix hex           /tb_ps2_keys/scan_code
add wave -label byte_ready                /tb_ps2_keys/scan_valid
add wave -label bad_frame                 /tb_ps2_keys/frame_error
add wave -divider "Decoder"
add wave -label release_next              /tb_ps2_keys/KEYS/release_next
add wave -label g_held                    /tb_ps2_keys/KEYS/g_held
add wave -label GENERATE                  /tb_ps2_keys/key_generate
add wave -label SOLVE                     /tb_ps2_keys/key_solve
add wave -label speed -radix speed        /tb_ps2_keys/speed_sel
add wave -label last_key -radix hex       /tb_ps2_keys/last_make
run -all
wave zoom full
