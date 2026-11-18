`timescale 1ns / 1ns
module control_fsm (
    input  wire       clk,
    input  wire       resetn,
    input  wire       go_gen,
    input  wire       gen_done,
    output wire       gen_start,
    output wire       busy,
    output wire [1:0] state_out
);
    localparam [1:0] C_IDLE  = 2'd0,
                     C_START = 2'd1,
                     C_GEN   = 2'd2,
                     C_READY = 2'd3;

    reg [1:0] state;
    reg [1:0] next;

    always @(*) begin
        next = state;
        case (state)
            C_IDLE:  if (go_gen)   next = C_START;
            C_START:               next = C_GEN;
            C_GEN:   if (gen_done) next = C_READY;
            C_READY: if (go_gen)   next = C_START;
            default:               next = C_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) state <= C_IDLE;
        else         state <= next;
    end

    assign gen_start = (state == C_START);
    assign busy      = (state == C_START) || (state == C_GEN);
    assign state_out = state;
endmodule
