/*
 * tb_ps2_keys
 *
 * Bit-bangs real PS/2 frames into ps2_rx -> key_decoder and checks:
 *   G press gives one key_generate pulse even with auto-repeat,
 *   G release then press gives another, S gives key_solve,
 *   number keys set the speed, a bad parity frame raises frame_error.
 */
`timescale 1ns / 1ns
module tb_ps2_keys;
    reg        clk = 1'b0;
    reg        resetn = 1'b0;
    reg        ps2_clk = 1'b1;
    reg        ps2_dat = 1'b1;
    wire [7:0] scan_code;
    wire       scan_valid;
    wire       frame_error;
    wire       key_generate;
    wire       key_solve;
    wire [1:0] speed_sel;
    wire [7:0] last_make;

    integer generate_pulses = 0;
    integer solve_pulses    = 0;
    integer error_pulses    = 0;
    integer errors          = 0;

    ps2_rx #(.TIMEOUT_BITS(12)) RX (
        .clk(clk), .resetn(resetn), .ps2_clk(ps2_clk), .ps2_dat(ps2_dat),
        .scan_code(scan_code), .scan_valid(scan_valid), .frame_error(frame_error)
    );

    key_decoder KEYS (
        .clk(clk), .resetn(resetn), .scan_code(scan_code), .scan_valid(scan_valid),
        .key_generate(key_generate), .key_solve(key_solve),
        .speed_sel(speed_sel), .last_make(last_make)
    );

    always #10 clk = ~clk;

    always @(posedge clk) begin
        if (key_generate) generate_pulses = generate_pulses + 1;
        if (key_solve)    solve_pulses    = solve_pulses + 1;
        if (frame_error)  error_pulses    = error_pulses + 1;
    end

    task send_bit(input b);
        begin
            ps2_dat = b;
            #20000 ps2_clk = 1'b0;
            #20000 ps2_clk = 1'b1;
        end
    endtask

    task send_frame(input [7:0] code, input corrupt_parity);
        integer i;
        begin
            send_bit(1'b0);
            for (i = 0; i < 8; i = i + 1) send_bit(code[i]);
            send_bit(~^code ^ corrupt_parity);
            send_bit(1'b1);
            ps2_dat = 1'b1;
            #100000;
        end
    endtask

    task send(input [7:0] code);
        send_frame(code, 1'b0);
    endtask

    task check(input integer got, input integer want, input [8*40-1:0] what);
        begin
            if (got == want) $display("ok: %0s = %0d", what, got);
            else begin
                $display("FAIL: %0s = %0d, expected %0d", what, got, want);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        #100 resetn = 1'b1;
        #1000;

        send(8'h34); send(8'h34); send(8'h34);
        check(generate_pulses, 1, "generate pulses after held G");
        check(last_make, 8'h34, "last make code");

        send(8'hF0); send(8'h34);
        send(8'h34);
        check(generate_pulses, 2, "generate pulses after re-press");

        send(8'h1B); send(8'hF0); send(8'h1B);
        check(solve_pulses, 1, "solve pulses");

        send(8'h26); send(8'hF0); send(8'h26);
        check(speed_sel, 2, "speed after 3");
        send(8'h25);
        check(speed_sel, 3, "speed after 4");

        send(8'hE0); send(8'h75); send(8'hE0); send(8'hF0); send(8'h75);
        check(generate_pulses + solve_pulses, 3, "no commands from arrow key");

        send_frame(8'h34, 1'b1);
        check(error_pulses, 1, "frame errors after bad parity");
        check(generate_pulses, 2, "bad frame ignored");

        if (errors == 0) $display("=== tb_ps2_keys: ALL TESTS PASSED ===");
        else             $display("=== tb_ps2_keys: %0d FAILURES ===", errors);
        $stop;
    end
endmodule
