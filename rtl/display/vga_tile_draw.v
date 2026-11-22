/*
 * vga_tile_draw
 *
 * Copies the maze RAM onto the screen, forever. It never knows or cares when
 * the maze changes; it just keeps repainting, about 2,600 full frames per
 * second, so any tile an algorithm writes shows up almost instantly.
 *
 * Geometry: the course VGA adapter runs at 160x120. Each tile is a 4x4 pixel
 * block, the maze is 39x29 tiles = 156x116 pixels, and a 2-pixel border
 * centres it on the screen.
 *
 * It is two nested counters with a two-state FSM on top:
 *   FETCH  present {row, col} to maze RAM port B (data arrives next clock)
 *   PLOT   16 clocks: write the tile's colour to the adapter at every pixel
 *          (px, py) of the 4x4 block, then advance to the next tile
 * The RAM address does not change during PLOT, so tile_q stays valid for the
 * whole block. 17 clocks per tile x 1131 tiles = 19,227 clocks per frame.
 *
 * Outputs connect straight to the course vga_adapter's x, y, color and write
 * ports (3-bit colour = {R, G, B}).
 */
`timescale 1ns / 1ns
module vga_tile_draw (
    input  wire        clk,
    input  wire        resetn,
    output wire [10:0] tile_addr,
    input  wire [2:0]  tile_q,
    output wire [7:0]  x,
    output wire [6:0]  y,
    output reg  [2:0]  color,
    output wire        write,
    output reg         frame_done
);
    localparam [4:0] ROWS     = 5'd29;
    localparam [5:0] COLS     = 6'd39;
    localparam [7:0] X_OFFSET = 8'd2;
    localparam [6:0] Y_OFFSET = 7'd2;

    localparam [2:0] T_WALL     = 3'd0,
                     T_PATH     = 3'd1,
                     T_START    = 3'd2,
                     T_END      = 3'd3,
                     T_VISITED  = 3'd4,
                     T_SOLUTION = 3'd5;

    localparam [2:0] BLUE    = 3'b001,
                     WHITE   = 3'b111,
                     GREEN   = 3'b010,
                     RED     = 3'b100,
                     CYAN    = 3'b011,
                     YELLOW  = 3'b110,
                     MAGENTA = 3'b101;

    localparam FETCH = 1'b0,
               PLOT  = 1'b1;

    reg       state;
    reg [4:0] row;
    reg [5:0] col;
    reg [1:0] px;
    reg [1:0] py;

    wire last_pixel = (px == 2'd3) && (py == 2'd3);
    wire last_col   = (col == COLS - 6'd1);
    wire last_row   = (row == ROWS - 5'd1);

    assign tile_addr = {row, col};
    assign x         = X_OFFSET + {col, 2'b00} + {6'd0, px};
    assign y         = Y_OFFSET + {row, 2'b00} + {5'd0, py};
    assign write     = (state == PLOT);

    always @(*) begin
        case (tile_q)
            T_WALL:     color = BLUE;
            T_PATH:     color = WHITE;
            T_START:    color = GREEN;
            T_END:      color = RED;
            T_VISITED:  color = CYAN;
            T_SOLUTION: color = YELLOW;
            default:    color = MAGENTA;
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            state      <= FETCH;
            row        <= 5'd0;
            col        <= 6'd0;
            px         <= 2'd0;
            py         <= 2'd0;
            frame_done <= 1'b0;
        end
        else begin
            frame_done <= 1'b0;
            case (state)
                FETCH: state <= PLOT;

                PLOT: begin
                    px <= px + 2'd1;
                    if (px == 2'd3)
                        py <= py + 2'd1;
                    if (last_pixel) begin
                        state <= FETCH;
                        col   <= last_col ? 6'd0 : col + 6'd1;
                        if (last_col) begin
                            row        <= last_row ? 5'd0 : row + 5'd1;
                            frame_done <= last_row;
                        end
                    end
                end
            endcase
        end
    end
endmodule
