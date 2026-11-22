if {[file exists work]} { vdel -lib work -all }
vlib work
vlog -quiet ../rtl/maze/*.v ../rtl/control/*.v ../rtl/input/*.v ../rtl/display/*.v
vlog -quiet ../rtl/maze_top.v stubs/vga_adapter_stub.v
vlog -quiet tb_*.v
file mkdir out
