/*
 * rate_divider
 *
 * Produces a one-clock tick pulse at a selectable rate so the generator and
 * solver can be slowed down enough to watch. The algorithms only take an
 * animated step when tick is high.
 *
 *   speed_sel 0  slow     8 steps/s
 *   speed_sel 1  medium   32 steps/s
 *   speed_sel 2  fast     128 steps/s
 *   speed_sel 3  instant  every clock
 *
 * The comparison is >= rather than == so switching to a faster speed mid-count
 * takes effect immediately instead of waiting for the counter to wrap.
 */
`timescale 1ns / 1ns
module rate_divider #(
    parameter [25:0] SLOW_PERIOD   = 26'd6_250_000,
    parameter [25:0] MEDIUM_PERIOD = 26'd1_562_500,
    parameter [25:0] FAST_PERIOD   = 26'd390_625
) (
    input  wire       clk,
    input  wire       resetn,
    input  wire [1:0] speed_sel,
    output reg        tick
);
    reg [25:0] count;
    reg [25:0] period;

    always @(*) begin
        case (speed_sel)
            2'd0:    period = SLOW_PERIOD;
            2'd1:    period = MEDIUM_PERIOD;
            2'd2:    period = FAST_PERIOD;
            default: period = 26'd1;
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            count <= 26'd0;
            tick  <= 1'b0;
        end
        else if (count >= period - 26'd1) begin
            count <= 26'd0;
            tick  <= 1'b1;
        end
        else begin
            count <= count + 26'd1;
            tick  <= 1'b0;
        end
    end
endmodule
