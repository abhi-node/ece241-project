`timescale 1ns / 1ns
module key_decoder (
    input  wire       clk,
    input  wire       resetn,
    input  wire [7:0] scan_code,
    input  wire       scan_valid,
    output reg        key_g,
    output reg        key_s,
    output reg  [1:0] speed_sel,
    output reg  [7:0] last_make
);
    localparam [7:0] SC_BREAK = 8'hF0,
                     SC_EXT   = 8'hE0,
                     SC_G     = 8'h34,
                     SC_S     = 8'h1B,
                     SC_1     = 8'h16,
                     SC_2     = 8'h1E,
                     SC_3     = 8'h26,
                     SC_4     = 8'h25;

    reg break_next;
    reg g_held;
    reg s_held;

    always @(posedge clk) begin
        key_g <= 1'b0;
        key_s <= 1'b0;

        if (!resetn) begin
            break_next <= 1'b0;
            g_held     <= 1'b0;
            s_held     <= 1'b0;
            speed_sel  <= 2'd1;
            last_make  <= 8'h00;
        end
        else if (scan_valid) begin
            if (scan_code == SC_BREAK) begin
                break_next <= 1'b1;
            end
            else if (scan_code == SC_EXT) begin
            end
            else if (break_next) begin
                break_next <= 1'b0;
                if (scan_code == SC_G) g_held <= 1'b0;
                if (scan_code == SC_S) s_held <= 1'b0;
            end
            else begin
                last_make <= scan_code;
                case (scan_code)
                    SC_G: begin
                        if (!g_held) key_g <= 1'b1;
                        g_held <= 1'b1;
                    end
                    SC_S: begin
                        if (!s_held) key_s <= 1'b1;
                        s_held <= 1'b1;
                    end
                    SC_1: speed_sel <= 2'd0;
                    SC_2: speed_sel <= 2'd1;
                    SC_3: speed_sel <= 2'd2;
                    SC_4: speed_sel <= 2'd3;
                    default: begin end
                endcase
            end
        end
    end
endmodule
