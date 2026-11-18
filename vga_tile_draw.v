`timescale 1ns / 1ns
module vga_tile_draw (
    input  wire        clk,
    input  wire        resetn,
    output wire [10:0] tile_addr,
    input  wire [2:0]  tile_q,
    output wire [7:0]  x,
    output wire [6:0]  y,
    output reg  [2:0]  colour,
    output wire        plot,
    output reg         frame_done
);
    localparam [4:0] ROWS  = 5'd29;
    localparam [5:0] COLS  = 6'd39;
    localparam [7:0] X_OFF = 8'd2;
    localparam [6:0] Y_OFF = 7'd2;

    localparam D_FETCH = 1'b0,
               D_PLOT  = 1'b1;

    reg       state;
    reg [4:0] trow;
    reg [5:0] tcol;
    reg [1:0] px;
    reg [1:0] py;

    assign tile_addr = {trow, tcol};
    assign x         = X_OFF + {tcol, 2'b00} + {6'b000000, px};
    assign y         = Y_OFF + {trow, 2'b00} + {5'b00000,  py};
    assign plot      = (state == D_PLOT);

    always @(*) begin
        case (tile_q)
            3'd0:    colour = 3'b001;
            3'd1:    colour = 3'b111;
            3'd2:    colour = 3'b010;
            3'd3:    colour = 3'b100;
            3'd4:    colour = 3'b011;
            3'd5:    colour = 3'b110;
            default: colour = 3'b101;
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            state      <= D_FETCH;
            trow       <= 5'd0;
            tcol       <= 6'd0;
            px         <= 2'd0;
            py         <= 2'd0;
            frame_done <= 1'b0;
        end
        else begin
            frame_done <= 1'b0;
            case (state)
                D_FETCH: begin
                    state <= D_PLOT;
                end

                D_PLOT: begin
                    px <= px + 2'd1;
                    if (px == 2'd3) begin
                        py <= py + 2'd1;
                        if (py == 2'd3) begin
                            state <= D_FETCH;
                            if (tcol == COLS - 6'd1) begin
                                tcol <= 6'd0;
                                if (trow == ROWS - 5'd1) begin
                                    trow       <= 5'd0;
                                    frame_done <= 1'b1;
                                end
                                else
                                    trow <= trow + 5'd1;
                            end
                            else
                                tcol <= tcol + 6'd1;
                        end
                    end
                end
            endcase
        end
    end
endmodule
