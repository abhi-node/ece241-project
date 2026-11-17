# ECE 241 Maze Project: Week of Nov 16 — Abhi's Guide

Your modules this week: `maze_ram`, `lfsr16`, `maze_gen`, `maze_solve`.
Ali's modules: `draw_fsm`, `ps2_decoder`, `control_fsm` (see his guide).

## Where we are

We are one week behind: the Nov 9 simulations were not done, so this week covers both the Nov 9 and Nov 16 rows of the proposal.

| Owner | Carried over from Nov 9 | Due this week (Nov 16) |
| --- | --- | --- |
| Abhi | Sim: maze RAM and DFS maze generator | DFS generator on the board; sim: BFS (Lee) solver |
| Ali | Sim: VGA drawing a hard-coded maze; sim: PS/2 input | PS/2 input and VGA draw on the board; sim: control FSM |

Three choices keep this to one week:

- **Tile maze, not wall bits.** Every 5x5 pixel tile is either wall or passage. Drawing, generating and solving all become "read a tile, write a tile".
- **You test against an ASCII dump, Ali tests against a hard-coded maze file.** Neither of you is blocked until Friday.
- **No rate divider this week.** `step_en` is tied to 1. The rate divider (Nov 23) plugs into it later.

Assumptions: DE1-SoC, course `vga_adapter` at 160x120 with 3-bit colour, course `PS2_Controller`, ModelSim.

**None of the code below has been run through a simulator.** Treat each block as a starting skeleton and let your testbench confirm it.

## The contract between you and Ali

Everything talks through one shared maze RAM. The generator and solver write tiles through port A; the draw FSM continuously reads tiles through port B and repaints the screen.

**Grid.** 160x120 screen, 5x5 pixel tiles: 32 columns by 24 rows. The maze uses tiles x = 0..30, y = 0..22. Tiles where both x and y are odd are maze cells (15 x 11 = 165 cells); the tiles between them are the walls the generator knocks out. The outer ring is never carved, so it is always wall.

**Addressing.** `addr = {y[4:0], x[4:0]}`, 10 bits, 1024 words.

**Tile word (4 bits).**

| Value | Meaning | Written by | Screen colour |
| --- | --- | --- | --- |
| `4'b0000` | Wall | Generator (clear) | Black `000` |
| `4'b0001` | Open passage, not yet visited | Generator (carve) | White `111` |
| `4'b01dd` | Visited by solver; `dd` = direction back to parent | Solver (BFS) | Cyan `011` |
| `4'b11dd` | On the solution path | Solver (backtrace) | Yellow `110` |

Directions everywhere: 0 = north (y-1), 1 = east (x+1), 2 = south (y+1), 3 = west (x-1). Start is tile (1,1); goal is tile (29,21).

**Module ports.**

| Module | Owner | Inputs | Outputs |
| --- | --- | --- | --- |
| `maze_ram` | Abhi | `addr_a, din_a, we_a, addr_b` | `dout_a, dout_b` (valid one clock after the address) |
| `lfsr16` | Abhi | `clk, resetn` | `q[15:0]` |
| `maze_gen` | Abhi | `start` (pulse), `step_en`, `rnd[1:0]`, `dout` | `addr, din, we, busy, done` (pulse) |
| `maze_solve` | Abhi | `start` (pulse), `step_en`, `dout` | `addr, din, we, busy, done` (pulse), `found` |
| `draw_fsm` | Ali | `ram_q` | `ram_addr, vga_x, vga_y, vga_colour, vga_plot` |
| `ps2_decoder` | Ali | `rx_data[7:0], rx_en` | `key_gen, key_solve` (pulses), `speed[1:0]` |
| `control_fsm` | Ali | `key_gen, key_solve, gen_done, solve_done` | `gen_start, solve_start, state` |

All modules use `CLOCK_50` and an active-low synchronous `resetn` (`KEY[0]`).

## Your schedule

On-board days assume you can get to a DE1-SoC; move them to your lab slot and keep the order.

| Day | You | Ali (for reference) |
| --- | --- | --- |
| Tue Nov 17 | Agree the contract with Ali. Write and simulate `maze_ram` and `lfsr16`. | Write `draw_fsm`; simulate against a checker pattern. |
| Wed Nov 18 | Write `maze_gen`; simulate until a valid ASCII maze prints. Send Ali `maze_init.hex`. | Finish `draw_fsm` sim with your file. Write `ps2_decoder`. |
| Thu Nov 19 | `maze_gen` on the board (`KEY[1]` = start, `LEDR[0]` toggles on done). Start `maze_solve`. | `draw_fsm` and PS/2 on the board. |
| Fri Nov 20 | **Integration together:** pressing G draws a new maze on the monitor. | Same session. |
| Sat Nov 21 | Simulate `maze_solve`; testbench prints the solved maze. | Write and simulate `control_fsm`. |
| Sun Nov 22 | Buffer. Fix whatever Friday exposed. | Swap the top level over to `control_fsm`. |

## 1. Maze RAM (Tue)

A dual-port RAM that Quartus infers as block memory. Port A reads and writes; port B only reads. Data appears one clock after the address, and both FSMs below are written around that one-cycle delay.

```verilog
module maze_ram (
    input            clk,
    input      [9:0] addr_a,
    input      [3:0] din_a,
    input            we_a,
    output reg [3:0] dout_a,
    input      [9:0] addr_b,
    output reg [3:0] dout_b
);
    reg [3:0] mem [0:1023];

    // Optional preload, used by Ali's hard-coded maze test.
    // initial $readmemh("maze_init.hex", mem);

    always @(posedge clk) begin
        if (we_a) mem[addr_a] <= din_a;
        dout_a <= mem[addr_a];
    end

    always @(posedge clk) dout_b <= mem[addr_b];
endmodule
```

Done when: a testbench writes two addresses, reads them back one cycle later on both ports, and gets the same values. Give Ali this file right away; he needs it on day one.

## 2. LFSR (Tue)

A free-running 16-bit maximal-length LFSR (taps 16, 14, 13, 11). It never stops, so the moment the user presses G decides the maze. The seed must be non-zero.

```verilog
module lfsr16 (
    input             clk,
    input             resetn,
    output reg [15:0] q
);
    wire fb = q[15] ^ q[13] ^ q[12] ^ q[10];
    always @(posedge clk)
        if (!resetn) q <= 16'hACE1;
        else         q <= {q[14:0], fb};
endmodule
```

## 3. DFS maze generator (Wed)

The algorithm is the iterative recursive-backtracker:

1. Clear all 1024 tiles to wall. Open tile (1,1) and make it the current cell.
2. Look at the four cells two tiles away. A neighbour is a candidate if it is inside the grid and still a wall.
3. If there are candidates, pick one at random, open the tile between and the neighbour itself, push the current cell on the stack, and move to the neighbour.
4. If there are none, pop the stack and go back to that cell. If the stack is empty, the maze is finished.

The bounds check in step 2 matters: from x = 1, going west wraps to x = 31, which is a wall tile and would look like a valid unvisited cell.

This helper is used by both the generator and the solver. Paste it inside each module.

```verilog
// Move n tiles from (x, y) in direction d. Returns {y, x}, which is a RAM address.
function [9:0] step;
    input [4:0] x, y;
    input [1:0] d;
    input [4:0] n;
    case (d)
        2'd0: step = {y - n, x};   // north
        2'd1: step = {y, x + n};   // east
        2'd2: step = {y + n, x};   // south
        2'd3: step = {y, x - n};   // west
    endcase
endfunction
```

The generator. RAM address, data and write enable are combinational from the state, so an address set in one state has its data ready in the next.

```verilog
module maze_gen (
    input            clk, resetn,
    input            start,      // one-cycle pulse
    input            step_en,    // tie to 1 this week; rate divider later
    input      [1:0] rnd,        // lfsr q[1:0]
    output reg [9:0] addr,
    output reg [3:0] din,
    output reg       we,
    input      [3:0] dout,
    output reg       busy,
    output reg       done        // one-cycle pulse
);
    localparam WALL = 4'h0, OPEN = 4'h1;
    localparam IDLE = 4'd0, CLEAR = 4'd1, INIT = 4'd2, SCAN_A = 4'd3, SCAN_R = 4'd4,
               PICK = 4'd5, CARVE1 = 4'd6, CARVE2 = 4'd7, POP = 4'd8, WAIT = 4'd9;

    reg [3:0] state;
    reg [4:0] cx, cy;      // current cell, always (odd, odd)
    reg [1:0] dir;
    reg [3:0] mask;        // mask[d] = neighbour d is an unvisited cell
    reg [9:0] clr;
    reg [7:0] sp;
    reg [9:0] stack [0:255];
    reg [9:0] stack_q;

    // paste the step() function here

    // Is the cell two tiles away in direction dir still inside the grid?
    wire inb = (dir == 2'd0) ? (cy != 5'd1)  :
               (dir == 2'd1) ? (cx != 5'd29) :
               (dir == 2'd2) ? (cy != 5'd21) :
                               (cx != 5'd1);

    // RAM port drive
    always @(*) begin
        addr = {cy, cx}; din = OPEN; we = 1'b0;
        case (state)
            CLEAR:  begin addr = clr; din = WALL; we = 1'b1; end
            INIT:   begin addr = {5'd1, 5'd1}; we = 1'b1; end
            SCAN_A: addr = step(cx, cy, dir, 5'd2);
            CARVE1: begin addr = step(cx, cy, dir, 5'd1); we = 1'b1; end
            CARVE2: begin addr = step(cx, cy, dir, 5'd2); we = 1'b1; end
            default: ;
        endcase
    end

    // Stack memory
    always @(posedge clk) begin
        if (state == CARVE2) stack[sp] <= {cy, cx};
        stack_q <= stack[sp - 8'd1];
    end

    always @(posedge clk) begin
        done <= 1'b0;
        if (!resetn) begin
            state <= IDLE; busy <= 1'b0;
        end else case (state)
            IDLE:   if (start) begin clr <= 10'd0; busy <= 1'b1; state <= CLEAR; end
            CLEAR:  begin clr <= clr + 10'd1; if (clr == 10'd1023) state <= INIT; end
            INIT:   begin cx <= 5'd1; cy <= 5'd1; sp <= 8'd0; dir <= 2'd0; state <= SCAN_A; end

            // Read the four neighbours, one per SCAN_A/SCAN_R pair.
            SCAN_A: state <= SCAN_R;
            SCAN_R: begin
                mask[dir] <= inb && (dout == WALL);
                if (dir == 2'd3) begin dir <= rnd; state <= PICK; end   // random first guess
                else             begin dir <= dir + 2'd1; state <= SCAN_A; end
            end

            // Rotate from the random direction until we hit a candidate.
            PICK: begin
                if (mask == 4'b0000) begin
                    if (sp == 8'd0) begin busy <= 1'b0; done <= 1'b1; state <= IDLE; end
                    else state <= POP;
                end
                else if (mask[dir]) state <= CARVE1;
                else dir <= dir + 2'd1;
            end

            CARVE1: state <= CARVE2;                 // opens the tile between
            CARVE2: begin                            // opens the neighbour, pushes, moves
                {cy, cx} <= step(cx, cy, dir, 5'd2);
                sp <= sp + 8'd1; dir <= 2'd0; state <= WAIT;
            end

            POP:    begin {cy, cx} <= stack_q; sp <= sp - 8'd1; dir <= 2'd0; state <= WAIT; end
            WAIT:   if (step_en) state <= SCAN_A;
            default: state <= IDLE;
        endcase
    end
endmodule
```

The testbench prints the maze as text and writes the file Ali needs.

```verilog
`timescale 1ns/1ps
module tb_gen;
    reg clk = 0, resetn = 0, start = 0;
    wire [15:0] rnd;
    wire [9:0]  addr;
    wire [3:0]  din, dout;
    wire        we, busy, done;
    integer x, y, opens;

    always #10 clk = ~clk;

    maze_ram ram (.clk(clk), .addr_a(addr), .din_a(din), .we_a(we), .dout_a(dout),
                  .addr_b(10'd0), .dout_b());
    lfsr16   l   (.clk(clk), .resetn(resetn), .q(rnd));
    maze_gen g   (.clk(clk), .resetn(resetn), .start(start), .step_en(1'b1),
                  .rnd(rnd[1:0]), .addr(addr), .din(din), .we(we), .dout(dout),
                  .busy(busy), .done(done));

    initial begin
        repeat (3) @(posedge clk);
        resetn <= 1;
        @(posedge clk) start <= 1;
        @(posedge clk) start <= 0;
        @(posedge done);
        @(posedge clk);
        opens = 0;
        for (y = 0; y < 23; y = y + 1) begin
            for (x = 0; x < 31; x = x + 1) begin
                if (ram.mem[y*32 + x] == 0) $write("#");
                else begin $write(" "); opens = opens + 1; end
            end
            $write("\n");
        end
        $display("open tiles = %0d (expect 329)", opens);
        $writememh("maze_init.hex", ram.mem);
        $stop;
    end
endmodule
```

Done when: the printed maze has a solid `#` border, every (odd, odd) tile is open, and the count is exactly 329 (165 cells plus 164 knocked-out walls, which is what a maze with no loops and no unreachable cells must have). Change the LFSR seed and confirm the maze changes. Then send `maze_init.hex` to Ali.

## 4. Generator on the board (Thu)

Use a temporary top level so you are not waiting on the control FSM: `KEY[0]` is reset, `KEY[1]` starts generation, `LEDR[0]` toggles on each `done` (`busy` lasts only milliseconds). Add Ali's `draw_fsm` on port B as soon as it works on his side.

```verilog
// One-cycle pulse when KEY[1] is pressed (keys are active low).
reg k1_d;
always @(posedge CLOCK_50) k1_d <= KEY[1];
wire gen_start = k1_d & ~KEY[1];
```

## 5. BFS (Lee) solver in simulation (Thu to Sat)

Lee's algorithm is breadth-first search from the start tile:

1. Mark the start tile visited and put it in the queue.
2. Take the tile at the head of the queue. If it is the goal, go to step 4.
3. For each of its four neighbours one tile away: if the tile is open (`4'b0001`), mark it visited with the direction pointing back to the current tile, and add it to the queue. Repeat from step 2.
4. Backtrace: starting at the goal, set the solution bit on the tile and follow its stored direction to the parent, until the start tile is reached.

No bounds check is needed here because the outer ring is always wall. The direction back to the parent is the opposite of the direction travelled, which is `dir ^ 2'b10`.

```verilog
module maze_solve (
    input            clk, resetn,
    input            start, step_en,
    output reg [9:0] addr,
    output reg [3:0] din,
    output reg       we,
    input      [3:0] dout,
    output reg       busy, done, found
);
    localparam OPEN = 4'h1;
    localparam [9:0] START = {5'd1, 5'd1}, GOAL = {5'd21, 5'd29};   // {y, x}
    localparam IDLE = 4'd0, SEED = 4'd1, DEQ = 4'd2, CHECK = 4'd3, NB_A = 4'd4,
               NB_R = 4'd5, WAIT = 4'd6, BT_A = 4'd7, BT_R = 4'd8;

    reg [3:0] state;
    reg [9:0] cur;                 // tile being expanded, {y, x}
    reg [1:0] dir;
    reg [9:0] queue [0:1023];
    reg [9:0] head, tail, q_out;

    // paste the step() function here
    wire [9:0] nb = step(cur[4:0], cur[9:5], dir, 5'd1);

    always @(*) begin
        addr = cur; din = 4'b0100; we = 1'b0;
        case (state)
            SEED: begin addr = START; we = 1'b1; end
            NB_A: addr = nb;
            NB_R: begin addr = nb; din = {2'b01, dir ^ 2'b10}; we = (dout == OPEN); end
            BT_R: begin din = dout | 4'b1000; we = 1'b1; end
            default: ;
        endcase
    end

    // Queue memory
    always @(posedge clk) begin
        if (state == SEED)                      queue[tail] <= START;
        else if (state == NB_R && dout == OPEN) queue[tail] <= nb;
        q_out <= queue[head];
    end

    always @(posedge clk) begin
        done <= 1'b0;
        if (!resetn) begin
            state <= IDLE; busy <= 1'b0; found <= 1'b0;
        end else case (state)
            IDLE:  if (start) begin
                       head <= 10'd0; tail <= 10'd0;
                       busy <= 1'b1; found <= 1'b0; state <= SEED;
                   end
            SEED:  begin tail <= 10'd1; state <= DEQ; end

            DEQ:   if (head == tail) begin busy <= 1'b0; done <= 1'b1; state <= IDLE; end  // no path
                   else state <= CHECK;
            CHECK: begin
                       cur <= q_out; head <= head + 10'd1; dir <= 2'd0;
                       state <= (q_out == GOAL) ? BT_A : NB_A;
                   end

            NB_A:  state <= NB_R;
            NB_R:  begin
                       if (dout == OPEN) tail <= tail + 10'd1;
                       dir <= dir + 2'd1;
                       state <= (dir == 2'd3) ? WAIT : NB_A;
                   end
            WAIT:  if (step_en) state <= DEQ;

            BT_A:  state <= BT_R;                    // read the tile at cur
            BT_R:  if (cur == START) begin
                       busy <= 1'b0; done <= 1'b1; found <= 1'b1; state <= IDLE;
                   end else begin
                       cur <= step(cur[4:0], cur[9:5], dout[1:0], 5'd1);
                       state <= BT_A;
                   end
            default: state <= IDLE;
        endcase
    end
endmodule
```

For the testbench, copy `tb_gen`, add the solver, and share port A between the two. Pulse the solver's `start` after the generator's `done`.

```verilog
wire [9:0] addr = g_busy ? g_addr : s_addr;
wire [3:0] din  = g_busy ? g_din  : s_din;
wire       we   = g_busy ? g_we   : s_we;
```

In the print loop, show bit 3 as `*`, bit 2 as `.`, open as a space and wall as `#`.

Done when: `found` is 1, and the `*` tiles form one unbroken line from (1,1) to (29,21) with no branches. `busy` is the signal Ali's HEX cycle counter will count next week.

## Friday integration

Goal: one Quartus project where pressing G on the keyboard draws a new maze on the monitor. On Friday the solver may not exist yet, so tie `s_addr`, `s_din` and `s_we` to 0 and drive `gen_start` straight from `key_gen`. On Sunday, swap in `control_fsm` and the real solver.

```verilog
wire [9:0] g_addr, s_addr, d_addr;
wire [3:0] g_din,  s_din,  q_a, q_b;
wire       g_we,   s_we,   g_busy, g_done, s_busy, s_done;
wire [15:0] rnd;

// Port A belongs to whichever of the generator or solver is running.
wire [9:0] a_addr = g_busy ? g_addr : s_addr;
wire [3:0] a_din  = g_busy ? g_din  : s_din;
wire       a_we   = g_busy ? g_we   : s_we;

maze_ram    ram  (.clk(CLOCK_50), .addr_a(a_addr), .din_a(a_din), .we_a(a_we), .dout_a(q_a),
                  .addr_b(d_addr), .dout_b(q_b));
lfsr16      rng  (.clk(CLOCK_50), .resetn(resetn), .q(rnd));
maze_gen    gen  (.clk(CLOCK_50), .resetn(resetn), .start(gen_start), .step_en(1'b1),
                  .rnd(rnd[1:0]), .addr(g_addr), .din(g_din), .we(g_we), .dout(q_a),
                  .busy(g_busy), .done(g_done));
maze_solve  sol  (.clk(CLOCK_50), .resetn(resetn), .start(solve_start), .step_en(1'b1),
                  .addr(s_addr), .din(s_din), .we(s_we), .dout(q_a),
                  .busy(s_busy), .done(s_done), .found());
draw_fsm    draw (.clk(CLOCK_50), .resetn(resetn), .ram_addr(d_addr), .ram_q(q_b),
                  .vga_x(x), .vga_y(y), .vga_colour(colour), .vga_plot(plot));
ps2_decoder keys (.clk(CLOCK_50), .resetn(resetn), .rx_data(rx_data), .rx_en(rx_en),
                  .key_gen(key_gen), .key_solve(key_solve), .speed(speed));
control_fsm ctrl (.clk(CLOCK_50), .resetn(resetn), .key_gen(key_gen), .key_solve(key_solve),
                  .gen_done(g_done), .solve_done(s_done),
                  .gen_start(gen_start), .solve_start(solve_start), .state());
```

With `step_en` tied to 1, generation finishes in a few milliseconds, so the maze will simply appear. Watching it grow needs the rate divider, which is next week.

If the screen is wrong, check in this order: does the hard-coded maze still draw (draw path), does an LED that toggles on every `g_done` flip when G is pressed (keyboard and generator), and does a ModelSim run of the full top level show `a_we` going high (RAM mux).

## Your checklist

- [ ] Contract agreed with Ali; `maze_ram.v` sent to him
- [ ] `maze_ram` and `lfsr16` simulated
- [ ] `maze_gen` simulation prints a valid maze with 329 open tiles
- [ ] `maze_init.hex` sent to Ali
- [ ] Generator runs on the board from `KEY[1]`
- [ ] Friday: G on the keyboard draws a new maze on the monitor
- [ ] `maze_solve` simulation shows `found = 1` and a continuous path
- [ ] Sunday: list what is left for Nov 23 (solver on board, rate divider)
