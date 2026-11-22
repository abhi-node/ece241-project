/*
 * tb_control
 *
 * Checks control_fsm hands out exactly one start pulse per accepted request,
 * ignores requests while busy, and that rate_divider ticks at the chosen
 * period (small periods are used so the test is quick).
 */
`timescale 1ns / 1ns
module tb_control;
    reg        clk = 1'b0;
    reg        resetn = 1'b0;
    reg        go_generate = 1'b0;
    reg        go_solve = 1'b0;
    reg        gen_done = 1'b0;
    reg        solve_done = 1'b0;
    wire       gen_start;
    wire       solve_start;
    wire       busy;
    wire [2:0] state;
    reg  [1:0] speed_sel = 2'd0;
    wire       tick;

    integer gen_starts = 0;
    integer solve_starts = 0;
    integer ticks = 0;
    integer errors = 0;

    control_fsm DUT (
        .clk(clk), .resetn(resetn), .go_generate(go_generate), .go_solve(go_solve),
        .gen_done(gen_done), .solve_done(solve_done), .gen_start(gen_start),
        .solve_start(solve_start), .busy(busy), .state_out(state)
    );

    rate_divider #(.SLOW_PERIOD(26'd10), .MEDIUM_PERIOD(26'd5), .FAST_PERIOD(26'd2)) RATE (
        .clk(clk), .resetn(resetn), .speed_sel(speed_sel), .tick(tick)
    );

    always #10 clk = ~clk;

    always @(posedge clk) begin
        if (gen_start)   gen_starts   = gen_starts + 1;
        if (solve_start) solve_starts = solve_starts + 1;
        if (tick)        ticks        = ticks + 1;
    end

    task check(input integer got, input integer want, input [8*40-1:0] what);
        begin
            if (got == want) $display("ok: %0s = %0d", what, got);
            else begin
                $display("FAIL: %0s = %0d, expected %0d", what, got, want);
                errors = errors + 1;
            end
        end
    endtask

    task pulse_generate; begin go_generate = 1'b1; @(posedge clk); #1 go_generate = 1'b0; end endtask
    task pulse_solve;    begin go_solve    = 1'b1; @(posedge clk); #1 go_solve    = 1'b0; end endtask

    initial begin
        repeat (2) @(posedge clk);
        #1 resetn = 1'b1;

        pulse_generate;
        repeat (3) @(posedge clk); #1;
        check(gen_starts, 1, "gen starts");
        check(busy, 1, "busy while generating");
        pulse_generate; pulse_solve;
        check(gen_starts + solve_starts, 1, "requests ignored while busy");
        gen_done = 1'b1; @(posedge clk); #1 gen_done = 1'b0;
        check(busy, 0, "idle after gen_done");

        pulse_solve;
        repeat (3) @(posedge clk); #1;
        check(solve_starts, 1, "solve starts");
        solve_done = 1'b1; @(posedge clk); #1 solve_done = 1'b0;
        check(state, 0, "idle after solve_done");

        go_generate = 1'b1; go_solve = 1'b1; @(posedge clk); #1;
        go_generate = 1'b0; go_solve = 1'b0;
        @(posedge clk); #1;
        check(gen_starts, 2, "generate wins a tie");
        check(solve_starts, 1, "solve lost the tie");

        speed_sel = 2'd0; repeat (20) @(posedge clk); #1 ticks = 0; repeat (100) @(posedge clk); #1;
        check(ticks, 10, "slow ticks in 100 clocks");
        speed_sel = 2'd2; repeat (20) @(posedge clk); #1 ticks = 0; repeat (100) @(posedge clk); #1;
        check(ticks, 50, "fast ticks in 100 clocks");
        speed_sel = 2'd3; repeat (20) @(posedge clk); #1 ticks = 0; repeat (100) @(posedge clk); #1;
        check(ticks, 100, "instant ticks in 100 clocks");

        if (errors == 0) $display("=== tb_control: ALL TESTS PASSED ===");
        else             $display("=== tb_control: %0d FAILURES ===", errors);
        $stop;
    end
endmodule
