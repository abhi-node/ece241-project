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

    wire fall = (clk_sync[2:1] == 2'b10);
    wire dat  = dat_sync[1];

    reg [3:0]              bit_cnt;
    reg [10:0]             shift;
    reg [TIMEOUT_BITS-1:0] idle_cnt;

    wire start_ok  = (shift[1] == 1'b0);
    wire stop_ok   = (dat == 1'b1);
    wire parity_ok = (^shift[10:2]) == 1'b1;

    always @(posedge clk) begin
        scan_valid  <= 1'b0;
        frame_error <= 1'b0;

        if (!resetn) begin
            bit_cnt   <= 4'd0;
            shift     <= 11'd0;
            idle_cnt  <= {TIMEOUT_BITS{1'b0}};
            scan_code <= 8'h00;
        end
        else if (fall) begin
            idle_cnt <= {TIMEOUT_BITS{1'b0}};
            shift    <= {dat, shift[10:1]};
            if (bit_cnt == 4'd10) begin
                bit_cnt <= 4'd0;
                if (start_ok && stop_ok && parity_ok) begin
                    scan_code  <= shift[9:2];
                    scan_valid <= 1'b1;
                end
                else
                    frame_error <= 1'b1;
            end
            else
                bit_cnt <= bit_cnt + 4'd1;
        end
        else if (bit_cnt != 4'd0) begin
            idle_cnt <= idle_cnt + 1'b1;
            if (&idle_cnt)
                bit_cnt <= 4'd0;
        end
        else
            idle_cnt <= {TIMEOUT_BITS{1'b0}};
    end
endmodule
