/*
 * maze_ram
 *
 * The single source of truth for the maze: 2048 words of 3 bits, one word per
 * tile. Address = {row[4:0], col[5:0]}; the visible maze is 29 rows x 39 cols.
 *
 * Tile codes (shared by every module that touches the maze):
 *   0 WALL   1 PATH   2 START   3 END   4 VISITED (solver)   5 SOLUTION (solver)
 *
 * Port A (read/write) belongs to whichever algorithm is running: the DFS
 * generator or the Lee solver. Port B (read only) belongs to the VGA tile
 * drawer, which repaints the screen from this RAM forever. Because the two
 * sides use separate ports, the algorithms never have to tell the display that
 * anything changed. Both ports return data one clock after the address.
 *
 * At power-up the RAM is loaded with a hard-coded maze from INIT_FILE so the
 * screen shows something before the first generate.
 */
`timescale 1ns / 1ns
module maze_ram #(
    parameter INIT_FILE = "../mem/maze_init.hex"
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

    initial $readmemh(INIT_FILE, mem);

    always @(posedge clk) begin
        if (we_a)
            mem[addr_a] <= din_a;
        q_a <= mem[addr_a];
    end

    always @(posedge clk)
        q_b <= mem[addr_b];
endmodule
