`timescale 1ns / 1ns
module stack_ram (
    input  wire        clk,
    input  wire [8:0]  addr,
    input  wire [10:0] din,
    input  wire        we,
    output reg  [10:0] q
);
    reg [10:0] mem [0:511];

    always @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        q <= mem[addr];
    end
endmodule
