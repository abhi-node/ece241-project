`timescale 1ns / 1ns
module sync_ram #(
    parameter ADDR_W = 9,
    parameter DATA_W = 11
) (
    input  wire              clk,
    input  wire [ADDR_W-1:0] addr,
    input  wire [DATA_W-1:0] din,
    input  wire              we,
    output reg  [DATA_W-1:0] q
);
    reg [DATA_W-1:0] mem [0:(1 << ADDR_W) - 1];

    always @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        q <= mem[addr];
    end
endmodule
