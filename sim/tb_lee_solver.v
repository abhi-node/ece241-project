/*
 * tb_lee_solver
 *
 * Solves the hard-coded maze and checks the answer against a reference
 * shortest-path distance computed inside the testbench:
 *   - found is set and path_length = shortest distance - 1
 *   - the yellow tiles form one unbroken chain from START to END
 *   - solving a second time gives the same result (the clean sweep works)
 *   - with END walled off, the solver finishes with found = 0
 * Also checks the cycle count is the same at slow animation speed as at
 * full speed, since working drops while waiting for a tick.
 */
`timescale 1ns / 1ns
module tb_lee_solver;
    localparam [2:0] T_WALL = 3'd0, T_PATH = 3'd1, T_START = 3'd2,
                     T_END = 3'd3, T_VISITED = 3'd4, T_SOLUTION = 3'd5;

    reg         clk = 1'b0;
    reg         resetn = 1'b0;
    reg         start = 1'b0;
    reg         tick_every_clock = 1'b1;
    reg  [2:0]  tick_count = 3'd0;
    wire        tick = tick_every_clock || (tick_count == 3'd0);
    wire [10:0] ram_addr;
    wire [2:0]  ram_din;
    wire        ram_we;
    wire [2:0]  ram_q;
    wire        busy;
    wire        working;
    wire        done;
    wire        found;
    wire [10:0] path_length;

    integer errors = 0;
    integer r, c, n, changed, shortest, solution_tiles, work_cycles, first_work_cycles;
    integer dist [0:2047];

    lee_solver DUT (
        .clk(clk), .resetn(resetn), .start(start), .tick(tick),
        .ram_addr(ram_addr), .ram_din(ram_din), .ram_we(ram_we), .ram_q(ram_q),
        .busy(busy), .working(working), .done(done), .found(found),
        .path_length(path_length)
    );

    maze_ram #(.INIT_FILE("../mem/maze_init.hex")) MAZE (
        .clk(clk), .addr_a(ram_addr), .din_a(ram_din), .we_a(ram_we), .q_a(ram_q),
        .addr_b(11'd0), .q_b()
    );

    always #10 clk = ~clk;
    always @(posedge clk) tick_count <= tick_count + 3'd1;
    always @(posedge clk) if (working) work_cycles = work_cycles + 1;

    function [2:0] tile(input integer row, input integer col);
        tile = (row < 0 || col < 0 || row > 28 || col > 38) ? T_WALL : MAZE.mem[row * 64 + col];
    endfunction

    function on_route(input integer row, input integer col);
        on_route = (tile(row, col) == T_SOLUTION) || (tile(row, col) == T_START) ||
                   (tile(row, col) == T_END);
    endfunction

    function integer route_neighbours(input integer row, input integer col);
        route_neighbours = on_route(row - 1, col) + on_route(row + 1, col) +
                           on_route(row, col - 1) + on_route(row, col + 1);
    endfunction

    task check(input integer got, input integer want, input [8*48-1:0] what);
        begin
            if (got == want) $display("ok: %0s = %0d", what, got);
            else begin
                $display("FAIL: %0s = %0d, expected %0d", what, got, want);
                errors = errors + 1;
            end
        end
    endtask

    task compute_shortest;
        integer best;
        begin
            for (r = 0; r < 2048; r = r + 1) dist[r] = 99999;
            dist[1 * 64 + 1] = 0;
            changed = 1;
            while (changed) begin
                changed = 0;
                for (r = 1; r < 28; r = r + 1)
                    for (c = 1; c < 38; c = c + 1)
                        if (tile(r, c) != T_WALL) begin
                            best = dist[r * 64 + c];
                            if (dist[(r - 1) * 64 + c] + 1 < best) best = dist[(r - 1) * 64 + c] + 1;
                            if (dist[(r + 1) * 64 + c] + 1 < best) best = dist[(r + 1) * 64 + c] + 1;
                            if (dist[r * 64 + c - 1] + 1 < best)   best = dist[r * 64 + c - 1] + 1;
                            if (dist[r * 64 + c + 1] + 1 < best)   best = dist[r * 64 + c + 1] + 1;
                            if (best < dist[r * 64 + c]) begin
                                dist[r * 64 + c] = best;
                                changed = 1;
                            end
                        end
            end
            shortest = dist[27 * 64 + 37];
        end
    endtask

    task run_solver;
        integer cycles;
        begin
            work_cycles = 0;
            @(posedge clk); #1 start = 1'b1;
            @(posedge clk); #1 start = 1'b0;
            cycles = 0;
            while (!done && cycles < 500000) begin
                @(posedge clk); #1;
                cycles = cycles + 1;
            end
            if (!done) begin
                $display("FAIL: solver never finished");
                errors = errors + 1;
            end
            else
                $display("ok: solver finished in %0d clocks (%0d working)", cycles, work_cycles);
        end
    endtask

    task check_route;
        begin
            solution_tiles = 0;
            n = 0;
            for (r = 0; r < 29; r = r + 1)
                for (c = 0; c < 39; c = c + 1)
                    if (tile(r, c) == T_SOLUTION) begin
                        solution_tiles = solution_tiles + 1;
                        if (route_neighbours(r, c) != 2) n = n + 1;
                    end
            check(found, 1, "found");
            check(path_length, shortest - 1, "path_length vs reference");
            check(solution_tiles, path_length, "yellow tiles");
            check(n, 0, "yellow tiles without exactly 2 route neighbours");
            check(route_neighbours(1, 1), 1, "route neighbours of START");
            check(route_neighbours(27, 37), 1, "route neighbours of END");
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        #1 resetn = 1'b1;

        compute_shortest;
        $display("reference shortest distance START->END = %0d", shortest);

        run_solver;
        check_route;
        first_work_cycles = work_cycles;

        run_solver;
        check_route;
        check(work_cycles, first_work_cycles, "working cycles on re-solve");

        tick_every_clock = 1'b0;
        run_solver;
        check_route;
        check(work_cycles, first_work_cycles, "working cycles at 1/8 speed");
        tick_every_clock = 1'b1;

        MAZE.mem[26 * 64 + 37] = T_WALL;
        MAZE.mem[27 * 64 + 36] = T_WALL;
        run_solver;
        check(found, 0, "found with END walled off");

        if (errors == 0) $display("=== tb_lee_solver: ALL TESTS PASSED ===");
        else             $display("=== tb_lee_solver: %0d FAILURES ===", errors);
        $stop;
    end
endmodule
