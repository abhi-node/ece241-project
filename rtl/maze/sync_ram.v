/*
 * sync_ram
 *
 * Generic single-port block RAM. One address, one read or write per clock.
 * The read data appears on q one clock after the address is presented, which
 * is how the FPGA's M10K blocks behave, so every FSM that uses this module
 * spends one state presenting an address and the next state using q.
 *
 * Used three times: the DFS backtracking stack, the BFS queue and the BFS
 * parent-direction table.
 */
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
