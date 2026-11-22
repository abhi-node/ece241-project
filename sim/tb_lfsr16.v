/*
 * tb_lfsr16
 *
 * Checks the LFSR never reaches the all-zero lock-up state and returns to its
 * seed after exactly 65535 clocks (maximal length).
 */
`timescale 1ns / 1ns
module tb_lfsr16;
    reg         clk = 1'b0;
    reg         resetn = 1'b0;
    wire [15:0] q;
    integer     cycles;
    integer     errors = 0;

    lfsr16 DUT (.clk(clk), .resetn(resetn), .q(q));

    always #10 clk = ~clk;

    initial begin
        @(posedge clk); @(posedge clk);
        resetn = 1'b1;
        @(posedge clk); #1;
        cycles = 1;
        while (q != 16'hACE1 && cycles < 70000) begin
            if (q == 16'd0) errors = errors + 1;
            @(posedge clk); #1;
            cycles = cycles + 1;
        end
        if (cycles != 65535) begin
            $display("FAIL: period %0d, expected 65535", cycles);
            errors = errors + 1;
        end
        else
            $display("ok: period 65535, never zero");
        if (errors == 0) $display("=== tb_lfsr16: ALL TESTS PASSED ===");
        else             $display("=== tb_lfsr16: %0d FAILURES ===", errors);
        $stop;
    end
endmodule
