`timescale 1ns / 1ns
module control_fsm (
    input  wire       clk,
    input  wire       resetn,
    input  wire       go_generate,
    input  wire       go_solve,
    input  wire       gen_done,
    input  wire       solve_done,
    output wire       gen_start,
    output wire       solve_start,
    output wire       busy,
    output wire [2:0] state_out
);
    localparam [2:0] IDLE        = 3'd0,
                     GEN_START   = 3'd1,
                     GENERATING  = 3'd2,
                     SOLVE_START = 3'd3,
                     SOLVING     = 3'd4;

    reg [2:0] state;
    reg [2:0] next;

    always @(*) begin
        next = state;
        case (state)
            IDLE:        if (go_generate)    next = GEN_START;
                         else if (go_solve)  next = SOLVE_START;
            GEN_START:                       next = GENERATING;
            GENERATING:  if (gen_done)       next = IDLE;
            SOLVE_START:                     next = SOLVING;
            SOLVING:     if (solve_done)     next = IDLE;
            default:                         next = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) state <= IDLE;
        else         state <= next;
    end

    assign gen_start   = (state == GEN_START);
    assign solve_start = (state == SOLVE_START);
    assign busy        = (state != IDLE);
    assign state_out   = state;
endmodule
