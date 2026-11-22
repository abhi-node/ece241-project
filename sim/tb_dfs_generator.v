`timescale 1ns / 1ns
module tb_dfs_generator;
    reg         clk = 1'b0;
    reg         resetn = 1'b0;
    reg         start = 1'b0;
    wire [15:0] random_bits;
    wire [10:0] ram_addr;
    wire [2:0]  ram_din;
    wire        ram_we;
    wire [2:0]  ram_q;
    wire        busy;
    wire        done;
    wire [8:0]  stack_depth;

    reg  [2:0]  first_maze [0:2047];
    integer     errors = 0;
    integer     max_depth = 0;
    integer     r, c, open_count, differences;

    lfsr16 RANDOM (.clk(clk), .resetn(resetn), .q(random_bits));

    dfs_generator DUT (
        .clk(clk), .resetn(resetn), .start(start), .tick(1'b1),
        .random_dir(random_bits[1:0]), .ram_addr(ram_addr), .ram_din(ram_din),
        .ram_we(ram_we), .ram_q(ram_q), .busy(busy), .done(done),
        .stack_depth(stack_depth)
    );

    maze_ram #(.INIT_FILE("../mem/maze_init.hex")) MAZE (
        .clk(clk), .addr_a(ram_addr), .din_a(ram_din), .we_a(ram_we), .q_a(ram_q),
        .addr_b(11'd0), .q_b()
    );

    always #10 clk = ~clk;

    always @(posedge clk) if (stack_depth > max_depth) max_depth = stack_depth;

    function [2:0] tile(input integer row, input integer col);
        tile = MAZE.mem[row * 64 + col];
    endfunction

    task fail(input [8*60-1:0] what, input integer row, input integer col);
        begin
            if (errors < 10) $display("FAIL: %0s at row %0d col %0d", what, row, col);
            errors = errors + 1;
        end
    endtask

    task check_maze;
        begin
            open_count = 0;
            for (r = 0; r < 29; r = r + 1)
                for (c = 0; c < 39; c = c + 1) begin
                    if (tile(r, c) != 3'd0) open_count = open_count + 1;
                    if ((r == 0 || r == 28 || c == 0 || c == 38) && tile(r, c) != 3'd0)
                        fail("border not wall", r, c);
                    if (r % 2 == 1 && c % 2 == 1 && tile(r, c) == 3'd0)
                        fail("cell never carved", r, c);
                    if (r % 2 == 0 && c % 2 == 0 && tile(r, c) != 3'd0)
                        fail("corner post carved", r, c);
                end
            if (tile(1, 1)   != 3'd2) fail("start not marked", 1, 1);
            if (tile(27, 37) != 3'd3) fail("end not marked", 27, 37);
            if (open_count != 531) begin
                $display("FAIL: %0d open tiles, expected 531", open_count);
                errors = errors + 1;
            end
            else
                $display("ok: 531 open tiles, all 266 cells carved, border intact");
        end
    endtask

    task run_generator;
        integer cycles;
        begin
            @(posedge clk); #1 start = 1'b1;
            @(posedge clk); #1 start = 1'b0;
            cycles = 0;
            while (!done && cycles < 100000) begin
                @(posedge clk); #1;
                cycles = cycles + 1;
            end
            if (!done) begin
                $display("FAIL: generator never finished");
                errors = errors + 1;
            end
            else
                $display("ok: generated in %0d clocks, max stack depth %0d", cycles, max_depth);
        end
    endtask

    task print_maze;
        reg [8*39-1:0] line;
        begin
            for (r = 0; r < 29; r = r + 1) begin
                for (c = 0; c < 39; c = c + 1)
                    line[8*(38-c) +: 8] = (tile(r, c) == 3'd0) ? "#" :
                                          (tile(r, c) == 3'd2) ? "S" :
                                          (tile(r, c) == 3'd3) ? "E" : " ";
                $display("%s", line);
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        #1 resetn = 1'b1;

        run_generator;
        check_maze;
        for (r = 0; r < 2048; r = r + 1) first_maze[r] = MAZE.mem[r];

        repeat (777) @(posedge clk);
        run_generator;
        check_maze;

        differences = 0;
        for (r = 0; r < 2048; r = r + 1)
            if (first_maze[r] != MAZE.mem[r]) differences = differences + 1;
        if (differences == 0) begin
            $display("FAIL: second maze identical to first");
            errors = errors + 1;
        end
        else
            $display("ok: second maze differs in %0d tiles", differences);

        print_maze;
        if (errors == 0) $display("=== tb_dfs_generator: ALL TESTS PASSED ===");
        else             $display("=== tb_dfs_generator: %0d FAILURES ===", errors);
        $stop;
    end
endmodule
