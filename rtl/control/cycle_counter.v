/*
 * cycle_counter
 *
 * Measures how many clock cycles the solver spends doing real work. It clears
 * when a solve starts and counts every clock that enable is high, saturating
 * at all ones instead of wrapping. The solver drops enable while it waits for
 * an animation tick, so the count is the same at every animation speed: it is
 * the cost of the algorithm itself, shown on the HEX displays.
 */
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
