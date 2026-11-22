do compile.do
foreach tb {tb_lfsr16 tb_ps2_keys tb_control tb_dfs_generator tb_lee_solver tb_maze_top} {
    vsim -quiet $tb
    run -all
    quit -sim
}
