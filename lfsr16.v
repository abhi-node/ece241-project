`timescale 1ns / 1ns
module lfsr16 (
    input  wire        clk,
    input  wire        resetn,
    input  wire        load,
    input  wire [15:0] seed,
    output reg  [15:0] q
);
    localparam [15:0] DEFAULT_SEED = 16'hACE1;

    wire feedback = q[15] ^ q[13] ^ q[12] ^ q[10];

    always @(posedge clk) begin
        if (!resetn)
            q <= DEFAULT_SEED;
        else if (load)
            q <= (seed == 16'd0) ? DEFAULT_SEED : seed;
        else
            q <= {q[14:0], feedback};
    end
endmodule
