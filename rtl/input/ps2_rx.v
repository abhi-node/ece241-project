/*
 * ps2_rx
 *
 * Receives one byte at a time from a PS/2 keyboard. The keyboard drives its
 * own clock (about 10-17 kHz) and sends 11-bit frames, data changing while the
 * PS/2 clock is high and valid on its falling edge:
 *
 *   start(0)  d0 d1 d2 d3 d4 d5 d6 d7  odd-parity  stop(1)
 *
 * Both PS/2 lines are first passed through flip-flop synchronisers because
 * they are not related to CLOCK_50. A falling edge on the synchronised PS/2
 * clock shifts the data bit into an 11-bit register from the top, so after ten
 * bits the start bit sits at shift[1], the data byte at shift[9:2] and the
 * parity bit at shift[10]; the stop bit is checked live on the eleventh edge.
 * A good frame produces a one-clock scan_valid pulse; a bad one pulses
 * frame_error.
 *
 * If the keyboard goes quiet mid-frame (a missed edge, a hot-plug) the idle
 * counter fills up and resets the bit counter, so one glitch cannot leave the
 * receiver permanently misaligned.
 */
`timescale 1ns / 1ns
module ps2_rx #(
    parameter TIMEOUT_BITS = 17
) (
    input  wire       clk,
    input  wire       resetn,
    input  wire       ps2_clk,
    input  wire       ps2_dat,
    output reg  [7:0] scan_code,
    output reg        scan_valid,
    output reg        frame_error
);
    reg [2:0] clk_sync;
    reg [1:0] dat_sync;

    always @(posedge clk) begin
        if (!resetn) begin
            clk_sync <= 3'b111;
            dat_sync <= 2'b11;
        end
        else begin
            clk_sync <= {clk_sync[1:0], ps2_clk};
            dat_sync <= {dat_sync[0],   ps2_dat};
        end
    end

    wire ps2_falling_edge = (clk_sync[2:1] == 2'b10);
    wire ps2_bit          = dat_sync[1];

    reg [3:0]              bit_count;
    reg [10:0]             shift;
    reg [TIMEOUT_BITS-1:0] idle_count;

    wire start_ok  = (shift[1] == 1'b0);
    wire stop_ok   = (ps2_bit == 1'b1);
    wire parity_ok = (^shift[10:2] == 1'b1);
    wire last_bit  = (bit_count == 4'd10);

    always @(posedge clk) begin
        scan_valid  <= 1'b0;
        frame_error <= 1'b0;

        if (!resetn) begin
            bit_count  <= 4'd0;
            shift      <= 11'd0;
            idle_count <= {TIMEOUT_BITS{1'b0}};
            scan_code  <= 8'h00;
        end
        else if (ps2_falling_edge) begin
            idle_count <= {TIMEOUT_BITS{1'b0}};
            shift      <= {ps2_bit, shift[10:1]};
            if (last_bit) begin
                bit_count <= 4'd0;
                if (start_ok && stop_ok && parity_ok) begin
                    scan_code  <= shift[9:2];
                    scan_valid <= 1'b1;
                end
                else
                    frame_error <= 1'b1;
            end
            else
                bit_count <= bit_count + 4'd1;
        end
        else if (bit_count != 4'd0) begin
            idle_count <= idle_count + 1'b1;
            if (&idle_count)
                bit_count <= 4'd0;
        end
        else
            idle_count <= {TIMEOUT_BITS{1'b0}};
    end
endmodule
