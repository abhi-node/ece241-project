/*
 * lfsr16
 *
 * 16-bit Fibonacci linear-feedback shift register (taps 16, 14, 13, 11), a
 * maximal-length sequence of 65535 states. It shifts every clock whether or
 * not anyone is listening, so the value the generator samples depends on the
 * exact clock cycle a human pressed G: that timing is the real source of
 * randomness. The all-zero state would lock up, so it is never loaded.
 */
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
