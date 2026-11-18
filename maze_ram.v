`timescale 1ns / 1ns
module maze_ram #(
    parameter INIT_FILE = "maze_init.hex"
) (
    input  wire        clk,
    input  wire [10:0] addr_a,
    input  wire [2:0]  din_a,
    input  wire        we_a,
    output reg  [2:0]  q_a,
    input  wire [10:0] addr_b,
    output reg  [2:0]  q_b
);
    reg [2:0] mem [0:2047];

    initial begin
        $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk) begin
        if (we_a)
            mem[addr_a] <= din_a;
        q_a <= mem[addr_a];
    end

    always @(posedge clk) begin
        q_b <= mem[addr_b];
    end
endmodule
