#!/bin/sh
cd "$(dirname "$0")"
mkdir -p out
RTL="../rtl/maze/*.v ../rtl/control/*.v ../rtl/input/*.v ../rtl/display/*.v"
status=0
for tb in tb_lfsr16 tb_ps2_keys tb_control tb_dfs_generator tb_lee_solver tb_maze_top; do
    extra=""
    [ "$tb" = tb_maze_top ] && extra="../rtl/maze_top.v stubs/vga_adapter_stub.v"
    iverilog -g2005 -Wall -Wno-timescale -o "out/$tb.vvp" "$tb.v" $RTL $extra || { status=1; continue; }
    vvp -n "out/$tb.vvp" > "out/$tb.log"
    grep -E "^(ok|FAIL|===)" "out/$tb.log"
    grep -q "ALL TESTS PASSED" "out/$tb.log" || status=1
done
exit $status
