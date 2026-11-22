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
