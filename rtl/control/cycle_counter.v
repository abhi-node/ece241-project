`timescale 1ns / 1ns
module cycle_counter #(
    parameter WIDTH = 24
) (
    input  wire             clk,
    input  wire             resetn,
    input  wire             clear,
    input  wire             enable,
    output reg  [WIDTH-1:0] count
);
    always @(posedge clk) begin
        if (!resetn || clear)
            count <= {WIDTH{1'b0}};
        else if (enable && !(&count))
            count <= count + 1'b1;
    end
endmodule
