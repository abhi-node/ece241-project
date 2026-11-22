/*
 * tb_maze_top
 *
 * Whole-system test with the VGA adapter replaced by sim/stubs. It presses
 * the board buttons the way a person would (SW[9] up for instant speed):
 *   1. solve the power-up maze  2. generate a new maze  3. solve it
 * After each step it lets the drawer repaint, then checks every pixel of the
 * captured frame against the colour of its tile in maze RAM, and writes the
 * final screen to out/frame.ppm so it can be looked at.
 */
`timescale 1ns / 1ns
module tb_maze_top;
    reg        clk = 1'b0;
    reg  [3:0] KEY = 4'b1110;
    reg  [9:0] SW  = 10'b1000000000;
    wire [9:0] LEDR;
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    wire [7:0] VGA_R, VGA_G, VGA_B;
    wire       VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    integer errors = 0;
    integer i, x, y, file, mismatches;
    reg [2:0] expected_color;
    reg [2:0] palette [0:7];

    maze_top #(.MAZE_INIT_FILE("../mem/maze_init.hex")) DUT (
        .CLOCK_50(clk), .KEY(KEY), .SW(SW), .PS2_CLK(1'b1), .PS2_DAT(1'b1),
        .LEDR(LEDR), .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3),
        .HEX4(HEX4), .HEX5(HEX5), .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N), .VGA_CLK(VGA_CLK)
    );

    always #10 clk = ~clk;

    initial begin
        palette[0] = 3'b001; palette[1] = 3'b111; palette[2] = 3'b010; palette[3] = 3'b100;
        palette[4] = 3'b011; palette[5] = 3'b110; palette[6] = 3'b101; palette[7] = 3'b101;
    end

    task press(input integer button);
        begin
            KEY[button] = 1'b0; repeat (5) @(posedge clk);
            KEY[button] = 1'b1; repeat (5) @(posedge clk);
        end
    endtask

    task wait_idle(input [8*20-1:0] what);
        integer cycles;
        begin
            cycles = 0;
            while (LEDR[9] && cycles < 200000) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            if (LEDR[9]) begin
                $display("FAIL: %0s never finished", what);
                errors = errors + 1;
            end
            else
                $display("ok: %0s finished after %0d clocks", what, cycles);
        end
    endtask

    task check_frame(input [8*20-1:0] what);
        begin
            repeat (40000) @(posedge clk);
            mismatches = 0;
            for (y = 0; y < 120; y = y + 1)
                for (x = 0; x < 160; x = x + 1) begin
                    if (x < 2 || x > 157 || y < 2 || y > 117)
                        expected_color = 3'b000;
                    else
                        expected_color = palette[DUT.MAZE.mem[((y - 2) / 4) * 64 + (x - 2) / 4]];
                    if (DUT.VGA.frame[y * 160 + x] !== expected_color)
                        mismatches = mismatches + 1;
                end
            if (mismatches == 0) $display("ok: %0s screen matches maze RAM", what);
            else begin
                $display("FAIL: %0s screen has %0d wrong pixels", what, mismatches);
                errors = errors + 1;
            end
        end
    endtask

    task save_frame;
        begin
            file = $fopen("out/frame.ppm", "w");
            $fwrite(file, "P3\n160 120\n1\n");
            for (i = 0; i < 19200; i = i + 1)
                $fwrite(file, "%0d %0d %0d\n", DUT.VGA.frame[i][2], DUT.VGA.frame[i][1], DUT.VGA.frame[i][0]);
            $fclose(file);
            $display("wrote out/frame.ppm");
        end
    endtask

    initial begin
        repeat (5) @(posedge clk);
        KEY[0] = 1'b1;

        check_frame("power-up");

        press(2);
        wait_idle("solve power-up maze");
        if (!LEDR[4]) begin $display("FAIL: LEDR[4] path found not lit"); errors = errors + 1; end
        $display("solve cycles on HEX: %0d, path length %0d", DUT.solve_cycles, DUT.path_length);
        check_frame("solved power-up");

        press(1);
        wait_idle("generate");
        if (!LEDR[3]) begin $display("FAIL: LEDR[3] maze generated not lit"); errors = errors + 1; end
        check_frame("generated");

        press(2);
        wait_idle("solve new maze");
        if (!LEDR[4]) begin $display("FAIL: LEDR[4] path found not lit"); errors = errors + 1; end
        $display("solve cycles on HEX: %0d, path length %0d", DUT.solve_cycles, DUT.path_length);
        check_frame("solved new maze");
        save_frame;

        if (errors == 0) $display("=== tb_maze_top: ALL TESTS PASSED ===");
        else             $display("=== tb_maze_top: %0d FAILURES ===", errors);
        $stop;
    end
endmodule
