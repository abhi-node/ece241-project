/*
 * vga_adapter (simulation stub)
 *
 * Stands in for the course vga_adapter in simulation only, because the real
 * one needs Intel's altsyncram and altpll models. It has the same ports and
 * parameters, captures every write into a 160x120 frame buffer, and drives
 * the VGA pins to constants. Never add this file to the Quartus project.
 */
`timescale 1ns / 1ns
module vga_adapter #(
    parameter RESOLUTION       = "160x120",
    parameter COLOR_DEPTH      = 3,
    parameter BACKGROUND_IMAGE = "black.mif"
) (
    input  wire                   resetn,
    input  wire                   clock,
    input  wire [COLOR_DEPTH-1:0] color,
    input  wire [7:0]             x,
    input  wire [6:0]             y,
    input  wire                   write,
    output wire [7:0]             VGA_R,
    output wire [7:0]             VGA_G,
    output wire [7:0]             VGA_B,
    output wire                   VGA_HS,
    output wire                   VGA_VS,
    output wire                   VGA_BLANK_N,
    output wire                   VGA_SYNC_N,
    output wire                   VGA_CLK
);
    reg [COLOR_DEPTH-1:0] frame [0:19199];
    integer i;

    initial for (i = 0; i < 19200; i = i + 1) frame[i] = 0;

    always @(posedge clock)
        if (write && x < 160 && y < 120)
            frame[y * 160 + x] <= color;

    assign VGA_R       = 8'd0;
    assign VGA_G       = 8'd0;
    assign VGA_B       = 8'd0;
    assign VGA_HS      = 1'b1;
    assign VGA_VS      = 1'b1;
    assign VGA_BLANK_N = 1'b1;
    assign VGA_SYNC_N  = 1'b1;
    assign VGA_CLK     = clock;
endmodule
