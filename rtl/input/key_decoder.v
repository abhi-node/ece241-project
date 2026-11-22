/*
 * key_decoder
 *
 * Turns raw PS/2 scan codes into commands. Pressing a key sends its make code,
 * holding it repeats the make code, and releasing it sends F0 then the make
 * code again. So the decoder:
 *
 *   - remembers that the last byte was F0, and treats the next byte as a
 *     release instead of a press;
 *   - keeps a "held" flag for G and S so auto-repeat produces exactly one
 *     command pulse per physical press.
 *
 *   G  -> key_generate pulse        1 -> speed 0 (slow)
 *   S  -> key_solve pulse           2 -> speed 1 (medium)
 *                                   3 -> speed 2 (fast)
 *                                   4 -> speed 3 (instant)
 *
 * last_make holds the most recent make code for the debug HEX view.
 */
`timescale 1ns / 1ns
module key_decoder (
    input  wire       clk,
    input  wire       resetn,
    input  wire [7:0] scan_code,
    input  wire       scan_valid,
    output reg        key_generate,
    output reg        key_solve,
    output reg  [1:0] speed_sel,
    output reg  [7:0] last_make
);
    localparam [7:0] SC_BREAK  = 8'hF0,
                     SC_EXTEND = 8'hE0,
                     SC_G      = 8'h34,
                     SC_S      = 8'h1B,
                     SC_1      = 8'h16,
                     SC_2      = 8'h1E,
                     SC_3      = 8'h26,
                     SC_4      = 8'h25;

    reg release_next;
    reg g_held;
    reg s_held;

    always @(posedge clk) begin
        key_generate <= 1'b0;
        key_solve    <= 1'b0;

        if (!resetn) begin
            release_next <= 1'b0;
            g_held       <= 1'b0;
            s_held       <= 1'b0;
            speed_sel    <= 2'd1;
            last_make    <= 8'h00;
        end
        else if (scan_valid) begin
            if (scan_code == SC_BREAK)
                release_next <= 1'b1;
            else if (scan_code == SC_EXTEND)
                release_next <= release_next;
            else if (release_next) begin
                release_next <= 1'b0;
                if (scan_code == SC_G) g_held <= 1'b0;
                if (scan_code == SC_S) s_held <= 1'b0;
            end
            else begin
                last_make <= scan_code;
                case (scan_code)
                    SC_G: begin
                        key_generate <= !g_held;
                        g_held       <= 1'b1;
                    end
                    SC_S: begin
                        key_solve <= !s_held;
                        s_held    <= 1'b1;
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
