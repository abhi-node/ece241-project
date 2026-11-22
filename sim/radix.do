radix define control_state {
    3'd0 "IDLE",
    3'd1 "GEN_START",
    3'd2 "GENERATING",
    3'd3 "SOLVE_START",
    3'd4 "SOLVING",
    -default unsigned
}
radix define generator_state {
    4'd0 "IDLE",
    4'd1 "CLEAR",
    4'd2 "OPEN_START",
    4'd3 "READ",
    4'd4 "CHECK",
    4'd5 "PICK",
    4'd6 "CARVE_WALL",
    4'd7 "CARVE_CELL",
    4'd8 "BACKTRACK",
    4'd9 "RESUME",
    4'd10 "MARK_START",
    4'd11 "MARK_END",
    -default unsigned
}
radix define solver_state {
    4'd0 "IDLE",
    4'd1 "CLEAN_READ",
    4'd2 "CLEAN_FIX",
    4'd3 "SEED",
    4'd4 "POP",
    4'd5 "LOAD",
    4'd6 "PROBE",
    4'd7 "EXPAND",
    4'd8 "TRACE_READ",
    4'd9 "TRACE_STEP",
    4'd10 "TRACE_MARK",
    4'd11 "FINISH",
    -default unsigned
}
radix define tile {
    3'd0 "WALL",
    3'd1 "PATH",
    3'd2 "START",
    3'd3 "END",
    3'd4 "VISITED",
    3'd5 "SOLUTION",
    -default unsigned
}
radix define direction {
    2'd0 "N",
    2'd1 "E",
    2'd2 "S",
    2'd3 "W",
    -default unsigned
}
radix define speed {
    2'd0 "SLOW",
    2'd1 "MEDIUM",
    2'd2 "FAST",
    2'd3 "INSTANT",
    -default unsigned
}
radix define colour {
    3'b001 "BLUE",
    3'b111 "WHITE",
    3'b010 "GREEN",
    3'b100 "RED",
    3'b011 "CYAN",
    3'b110 "YELLOW",
    3'b101 "MAGENTA",
    3'b000 "BLACK",
    -default binary
}
