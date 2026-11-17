# ECE 241 Maze Project: Week of Nov 16 — Ali's Guide

Your modules this week: `draw_fsm`, `ps2_decoder`, `control_fsm`.
Abhi's modules: `maze_ram`, `lfsr16`, `maze_gen`, `maze_solve` (see his guide).

## Where we are

We are one week behind: the Nov 9 simulations were not done, so this week covers both the Nov 9 and Nov 16 rows of the proposal.

| Owner | Carried over from Nov 9 | Due this week (Nov 16) |
| --- | --- | --- |
| Abhi | Sim: maze RAM and DFS maze generator | DFS generator on the board; sim: BFS (Lee) solver |
| Ali | Sim: VGA drawing a hard-coded maze; sim: PS/2 input | PS/2 input and VGA draw on the board; sim: control FSM |

Three choices keep this to one week:

- **Tile maze, not wall bits.** Every 5x5 pixel tile is either wall or passage. Drawing is just "read a tile, pick a colour, plot 25 pixels".
- **You test against a hard-coded maze, Abhi tests against an ASCII dump.** Neither of you is blocked until Friday.
- **No rate divider this week.** You store `speed` from the keyboard now; the rate divider (Nov 23) uses it later.

Assumptions: DE1-SoC, course `vga_adapter` at 160x120 with 3-bit colour, course `PS2_Controller`, ModelSim. If the adapter is set to 320x240, double the tile size to 10 pixels and nothing else changes.

**None of the code below has been run through a simulator.** Treat each block as a starting skeleton and let your testbench confirm it.

## The contract between you and Abhi

Everything talks through one shared maze RAM. Abhi's generator and solver write tiles through port A; your draw FSM continuously reads tiles through port B and repaints the screen, which is what makes generation and solving animate for free.

**Grid.** 160x120 screen, 5x5 pixel tiles: 32 columns by 24 rows. The maze uses tiles x = 0..30, y = 0..22. Tiles where both x and y are odd are maze cells; the tiles between them are walls the generator knocks out. The outer ring is always wall.

**Addressing.** `addr = {y[4:0], x[4:0]}`, 10 bits, 1024 words.

**Tile word (4 bits).**

| Value | Meaning | Written by | Screen colour (3-bit RGB) |
| --- | --- | --- | --- |
| `4'b0000` | Wall | Generator (clear) | Black `000` |
| `4'b0001` | Open passage, not yet visited | Generator (carve) | White `111` |
| `4'b01dd` | Visited by solver; `dd` = direction back to parent | Solver (BFS) | Cyan `011` |
| `4'b11dd` | On the solution path | Solver (backtrace) | Yellow `110` |

Start is tile (1,1), drawn green `010`. Goal is tile (29,21), drawn red `100`.

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

All modules use `CLOCK_50` and an active-low synchronous `resetn` (`KEY[0]`). Keys: G generates, S solves, 1/2/3 set the speed.

## Your schedule

On-board days assume you can get to a DE1-SoC; move them to your lab slot and keep the order.

| Day | You | Abhi (for reference) |
| --- | --- | --- |
| Tue Nov 17 | Agree the contract with Abhi. Write `draw_fsm`; simulate against the checker pattern. | Write and simulate `maze_ram` and `lfsr16`. |
| Wed Nov 18 | Finish the `draw_fsm` sim using Abhi's `maze_init.hex`. Write `ps2_decoder` and its testbench. | Simulate `maze_gen`; send you `maze_init.hex`. |
| Thu Nov 19 | `draw_fsm` on the board showing the hard-coded maze. PS/2 on the board with key pulses on LEDs. | `maze_gen` on the board. Start `maze_solve`. |
| Fri Nov 20 | **Integration together:** pressing G draws a new maze on the monitor. | Same session. |
| Sat Nov 21 | Write `control_fsm`; simulate the G then S sequence with fake done pulses. | Simulate `maze_solve`. |
| Sun Nov 22 | Buffer. Swap the Friday top level over to `control_fsm`. | Buffer. |

## 0. The RAM you need on day one

This is Abhi's module. Copy it now so you are not waiting on him.

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

    // Preload for the hard-coded maze test. Uncomment for the board test.
    // initial $readmemh("maze_init.hex", mem);

    always @(posedge clk) begin
        if (we_a) mem[addr_a] <= din_a;
        dout_a <= mem[addr_a];
    end

    always @(posedge clk) dout_b <= mem[addr_b];
endmodule
```

## 1. VGA tile draw FSM (Tue to Wed)

The draw FSM never stops. It walks every tile, reads its 4-bit word from RAM port B, turns that into a colour, and plots the tile's 25 pixels. A full repaint takes about 21,000 clock cycles (under half a millisecond), so anything the generator or solver writes shows up almost immediately. There is no separate "redraw" signal.

Per tile there are three states: present the address, latch the colour once the RAM data arrives, then plot 5x5 pixels.

```verilog
module draw_fsm (
    input            clk, resetn,
    output     [9:0] ram_addr,
    input      [3:0] ram_q,
    output     [7:0] vga_x,
    output     [6:0] vga_y,
    output reg [2:0] vga_colour,
    output           vga_plot
);
    localparam T_ADDR = 2'd0, T_READ = 2'd1, T_PLOT = 2'd2;

    reg [1:0] state;
    reg [4:0] tx, ty;      // tile: 0..31, 0..23
    reg [2:0] px, py;      // pixel inside the tile: 0..4

    assign ram_addr = {ty, tx};
    assign vga_x    = {tx, 2'b00} + tx + px;     // tx*5 + px
    assign vga_y    = {ty, 2'b00} + ty + py;     // ty*5 + py
    assign vga_plot = (state == T_PLOT);

    wire is_start = (tx == 5'd1)  && (ty == 5'd1);
    wire is_goal  = (tx == 5'd29) && (ty == 5'd21);

    always @(posedge clk) begin
        if (!resetn) begin
            state <= T_ADDR; tx <= 5'd0; ty <= 5'd0; px <= 3'd0; py <= 3'd0;
        end else case (state)
            T_ADDR: state <= T_READ;              // RAM registers the address
            T_READ: begin                         // ram_q is valid now
                vga_colour <= is_start ? 3'b010 :     // green
                              is_goal  ? 3'b100 :     // red
                              ram_q[3] ? 3'b110 :     // solution: yellow
                              ram_q[2] ? 3'b011 :     // visited: cyan
                              ram_q[0] ? 3'b111 :     // open: white
                                         3'b000;      // wall: black
                px <= 3'd0; py <= 3'd0;
                state <= T_PLOT;
            end
            T_PLOT: begin
                if (px != 3'd4) px <= px + 3'd1;
                else begin
                    px <= 3'd0;
                    if (py != 3'd4) py <= py + 3'd1;
                    else begin                    // tile finished, go to the next
                        state <= T_ADDR;
                        if (tx != 5'd31) tx <= tx + 5'd1;
                        else begin
                            tx <= 5'd0;
                            ty <= (ty == 5'd23) ? 5'd0 : ty + 5'd1;
                        end
                    end
                end
            end
            default: state <= T_ADDR;
        endcase
    end
endmodule
```

The testbench fills the RAM with a test pattern, records every plotted pixel into a fake frame buffer for one full repaint, and checks three tiles. Until Abhi sends `maze_init.hex`, use the checker pattern below (every tile with odd x and odd y is open). When the file arrives, replace the `for` loop with `$readmemh("maze_init.hex", ram.mem);`.

```verilog
`timescale 1ns/1ps
module tb_draw;
    reg clk = 0, resetn = 0;
    wire [9:0] ram_addr;
    wire [3:0] ram_q;
    wire [7:0] x;
    wire [6:0] y;
    wire [2:0] colour;
    wire       plot;
    reg  [2:0] frame [0:19199];      // 160 x 120
    integer i;

    always #10 clk = ~clk;

    maze_ram ram (.clk(clk), .addr_a(10'd0), .din_a(4'd0), .we_a(1'b0), .dout_a(),
                  .addr_b(ram_addr), .dout_b(ram_q));
    draw_fsm d   (.clk(clk), .resetn(resetn), .ram_addr(ram_addr), .ram_q(ram_q),
                  .vga_x(x), .vga_y(y), .vga_colour(colour), .vga_plot(plot));

    always @(posedge clk) if (plot) frame[y*160 + x] <= colour;

    initial begin
        for (i = 0; i < 1024; i = i + 1)
            ram.mem[i] = (i[0] && i[5]) ? 4'h1 : 4'h0;   // i[0] = x is odd, i[5] = y is odd
        repeat (3) @(posedge clk);
        resetn <= 1;
        repeat (22000) @(posedge clk);                   // a bit more than one repaint
        $display("tile (0,0) pixel = %b (expect 000)", frame[0]);
        $display("tile (1,1) pixel = %b (expect 010)", frame[7*160 + 7]);
        $display("tile (3,1) pixel = %b (expect 111)", frame[7*160 + 17]);
        $stop;
    end
endmodule
```

Done when: the three checks print the expected colours, and in the waveform `x` never passes 159 and `y` never passes 119.

A note on the .mif in the proposal: `$readmemh` with a hex file does the same job for this inferred RAM, in both ModelSim and Quartus. If you would rather use an IP Catalog RAM with a .mif, keep the same port names and nothing else in this guide changes.

## 2. VGA on the board (Thu)

Uncomment the `$readmemh` line in `maze_ram`, add `maze_init.hex` to the Quartus project, and connect `draw_fsm` to the course `vga_adapter` exactly as in your VGA lab top level: `colour`, `x`, `y`, `plot` in, the `VGA_*` pins out, resolution 160x120, 1 bit per colour channel. You should see the maze with a green start tile and a red goal tile.

## 3. PS/2 decoder (Wed sim, Thu board)

The course `PS2_Controller` hands you one byte at a time on `received_data` with a one-cycle `received_data_en`. A key press sends its make code; a release sends `F0` followed by the same code. The decoder's only job is to turn make codes into pulses and throw away the byte that follows `F0`.

| Key | Make code | Action |
| --- | --- | --- |
| G | `34` | `key_gen` pulse |
| S | `1B` | `key_solve` pulse |
| 1 | `16` | `speed = 0` |
| 2 | `1E` | `speed = 1` |
| 3 | `26` | `speed = 2` |

```verilog
module ps2_decoder (
    input            clk, resetn,
    input      [7:0] rx_data,
    input            rx_en,
    output reg       key_gen, key_solve,
    output reg [1:0] speed
);
    reg brk;    // the previous byte was F0, so this byte is a key release

    always @(posedge clk) begin
        key_gen   <= 1'b0;
        key_solve <= 1'b0;
        if (!resetn) begin
            brk <= 1'b0; speed <= 2'd0;
        end else if (rx_en) begin
            if (rx_data == 8'hF0) brk <= 1'b1;
            else if (brk)         brk <= 1'b0;        // ignore the released key
            else case (rx_data)
                8'h34: key_gen   <= 1'b1;
                8'h1B: key_solve <= 1'b1;
                8'h16: speed <= 2'd0;
                8'h1E: speed <= 2'd1;
                8'h26: speed <= 2'd2;
                default: ;
            endcase
        end
    end
endmodule
```

In simulation you do not need the PS/2 controller at all; drive the bytes directly with a task.

```verilog
task send_byte(input [7:0] b);
    begin
        @(posedge clk); rx_data <= b; rx_en <= 1'b1;
        @(posedge clk); rx_en <= 1'b0;
        repeat (5) @(posedge clk);
    end
endtask

// In the initial block, after reset:
send_byte(8'h34);                    // press G: expect one key_gen pulse
send_byte(8'hF0); send_byte(8'h34);  // release G: expect no pulse
send_byte(8'h1B);                    // press S: expect one key_solve pulse
send_byte(8'h1E);                    // press 2: expect speed = 1
```

On the board, connect it to the controller and make the pulses visible on LEDs (for example, toggle `LEDR[0]` on each `key_gen`).

```verilog
PS2_Controller ps2 (
    .CLOCK_50(CLOCK_50), .reset(~KEY[0]),
    .PS2_CLK(PS2_CLK), .PS2_DAT(PS2_DAT),
    .received_data(rx_data), .received_data_en(rx_en)
);
```

Done when: each press of G toggles the LED exactly once, and releasing the key does nothing. Holding a key repeats the make code; that is fine, because the control FSM ignores G and S while it is busy.

## 4. Control FSM in simulation (Sat)

The control FSM decides who owns the maze. It has four states and sends one-cycle start pulses to Abhi's modules.

| State | Meaning | Leaves when |
| --- | --- | --- |
| `C_EMPTY` | No maze yet | G pressed, go to `C_GEN` |
| `C_GEN` | Generator running | `gen_done`, go to `C_READY` |
| `C_READY` | Maze drawn, unsolved | S pressed, go to `C_SOLVE`; G pressed, go to `C_GEN` |
| `C_SOLVE` | Solver running | `solve_done`, go to `C_EMPTY` |

After a solve it returns to `C_EMPTY` on purpose: the tiles are now marked visited, so S must do nothing until G makes a fresh maze. The solved maze stays on screen because nothing clears the RAM.

```verilog
module control_fsm (
    input            clk, resetn,
    input            key_gen, key_solve,
    input            gen_done, solve_done,
    output reg       gen_start, solve_start,
    output reg [1:0] state
);
    localparam C_EMPTY = 2'd0, C_GEN = 2'd1, C_READY = 2'd2, C_SOLVE = 2'd3;

    always @(posedge clk) begin
        gen_start   <= 1'b0;
        solve_start <= 1'b0;
        if (!resetn) state <= C_EMPTY;
        else case (state)
            C_EMPTY: if (key_gen) begin gen_start <= 1'b1; state <= C_GEN; end
            C_GEN:   if (gen_done) state <= C_READY;
            C_READY: if (key_gen)        begin gen_start   <= 1'b1; state <= C_GEN;   end
                     else if (key_solve) begin solve_start <= 1'b1; state <= C_SOLVE; end
            C_SOLVE: if (solve_done) state <= C_EMPTY;
        endcase
    end
endmodule
```

Testbench sequence: pulse `key_solve` first and confirm nothing happens; pulse `key_gen` and confirm one `gen_start`; pulse `key_gen` again while in `C_GEN` and confirm it is ignored; pulse `gen_done`, then `key_solve`, and confirm one `solve_start`; pulse `solve_done` and confirm the state is back to `C_EMPTY`.

Done when: that sequence passes with you driving `gen_done` and `solve_done` by hand. Abhi's real modules replace your fake pulses on Sunday.

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

- [ ] Contract agreed with Abhi; `maze_ram.v` copied
- [ ] `draw_fsm` simulation passes the three pixel checks
- [ ] Hard-coded maze visible on the monitor
- [ ] `ps2_decoder` simulated, then G and S pulses confirmed on LEDs
- [ ] Friday: G on the keyboard draws a new maze on the monitor
- [ ] `control_fsm` simulation passes the G then S sequence
- [ ] Sunday: top level uses `control_fsm`; list what is left for Nov 23 (stat counters on HEX, PS/2 speed into the rate divider)
