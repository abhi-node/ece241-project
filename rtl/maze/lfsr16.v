`timescale 1ns / 1ns
module lfsr16 (
    input  wire        clk,
    input  wire        resetn,
    output reg  [15:0] q
);
    localparam [15:0] SEED = 16'hACE1;

    wire feedback = q[15] ^ q[13] ^ q[12] ^ q[10];

    always @(posedge clk) begin
        if (!resetn) q <= SEED;
        else         q <= {q[14:0], feedback};
    end
endmodule
