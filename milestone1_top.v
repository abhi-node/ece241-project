`timescale 1ns / 1ns
module milestone1_top #(
    parameter [25:0] PERIOD0 = 26'd6_250_000,
    parameter [25:0] PERIOD1 = 26'd1_562_500,
    parameter [25:0] PERIOD2 = 26'd390_625
) (
    input  wire       CLOCK_50,
    input  wire [3:0] KEY,
    input  wire [9:0] SW,
    input  wire       PS2_CLK,
    input  wire       PS2_DAT,
    output wire [9:0] LEDR,
    output wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    output wire [7:0] VGA_R, VGA_G, VGA_B,
    output wire       VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK
);
    wire clk    = CLOCK_50;
    wire resetn = KEY[0];

    wire [7:0] scan_code;
    wire       scan_valid, frame_error;
    wire       key_g, key_s;
    wire [1:0] speed_key;
    wire [7:0] last_make;

    ps2_rx PS2 (
        .clk         (clk),
        .resetn      (resetn),
        .ps2_clk     (PS2_CLK),
        .ps2_dat     (PS2_DAT),
        .scan_code   (scan_code),
        .scan_valid  (scan_valid),
        .frame_error (frame_error)
    );

    key_decoder KEYS (
        .clk        (clk),
        .resetn     (resetn),
        .scan_code  (scan_code),
        .scan_valid (scan_valid),
        .key_g      (key_g),
        .key_s      (key_s),
        .speed_sel  (speed_key),
        .last_make  (last_make)
    );

    reg [2:0] key1_sync;
    always @(posedge clk) begin
        if (!resetn) key1_sync <= 3'b000;
        else         key1_sync <= {key1_sync[1:0], ~KEY[1]};
    end
    wire key1_pulse = (key1_sync[2:1] == 2'b01);

    wire go_gen = key_g | key1_pulse;

    wire       gen_start, gen_done, ctrl_busy;
    wire [1:0] ctrl_state;

    control_fsm CTRL (
        .clk       (clk),
        .resetn    (resetn),
        .go_gen    (go_gen),
        .gen_done  (gen_done),
        .gen_start (gen_start),
        .busy      (ctrl_busy),
        .state_out (ctrl_state)
    );

    wire [15:0] lfsr_q;
    lfsr16 RNG (
        .clk    (clk),
        .resetn (resetn),
        .load   (1'b0),
        .seed   (16'd0),
        .q      (lfsr_q)
    );

    wire [1:0] speed_sel = SW[9] ? 2'd3 : speed_key;
    wire       tick;

    rate_divider #(
        .PERIOD0 (PERIOD0),
        .PERIOD1 (PERIOD1),
        .PERIOD2 (PERIOD2)
    ) RATE (
        .clk       (clk),
        .resetn    (resetn),
        .speed_sel (speed_sel),
        .tick      (tick)
    );

    wire [10:0] gen_addr, draw_addr;
    wire [2:0]  gen_din, gen_q, draw_q;
    wire        gen_we, gen_busy;
    wire [8:0]  stack_depth;
    wire [4:0]  cur_row;
    wire [5:0]  cur_col;

    dfs_generator GEN (
        .clk         (clk),
        .resetn      (resetn),
        .start       (gen_start),
        .tick        (tick),
        .rand2       (lfsr_q[1:0]),
        .ram_addr    (gen_addr),
        .ram_din     (gen_din),
        .ram_we      (gen_we),
        .ram_q       (gen_q),
        .busy        (gen_busy),
        .done        (gen_done),
        .stack_depth (stack_depth),
        .cur_row     (cur_row),
        .cur_col     (cur_col)
    );

    maze_ram #(
        .INIT_FILE ("maze_init.hex")
    ) MAZE (
        .clk    (clk),
        .addr_a (gen_addr),
        .din_a  (gen_din),
        .we_a   (gen_we),
        .q_a    (gen_q),
        .addr_b (draw_addr),
        .q_b    (draw_q)
    );

    wire [7:0] vga_x;
    wire [6:0] vga_y;
    wire [2:0] vga_colour;
    wire       vga_plot, frame_done;

    vga_tile_draw DRAW (
        .clk        (clk),
        .resetn     (resetn),
        .tile_addr  (draw_addr),
        .tile_q     (draw_q),
        .x          (vga_x),
        .y          (vga_y),
        .colour     (vga_colour),
        .plot       (vga_plot),
        .frame_done (frame_done)
    );

`ifdef VGA_NEW_ADAPTER
    vga_adapter VGA (
        .resetn     (resetn),
        .clock      (clk),
        .color      (vga_colour),
        .x          (vga_x),
        .y          (vga_y),
        .write      (vga_plot),
        .VGA_R      (VGA_R),
        .VGA_G      (VGA_G),
        .VGA_B      (VGA_B),
        .VGA_HS     (VGA_HS),
        .VGA_VS     (VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N (VGA_SYNC_N),
        .VGA_CLK    (VGA_CLK)
    );
    defparam VGA.RESOLUTION       = "160x120";
    defparam VGA.COLOR_DEPTH      = 3;
    defparam VGA.BACKGROUND_IMAGE = "black.mif";
`else
    vga_adapter VGA (
        .resetn    (resetn),
        .clock     (clk),
        .colour    (vga_colour),
        .x         (vga_x),
        .y         (vga_y),
        .plot      (vga_plot),
        .VGA_R     (VGA_R),
        .VGA_G     (VGA_G),
        .VGA_B     (VGA_B),
        .VGA_HS    (VGA_HS),
        .VGA_VS    (VGA_VS),
        .VGA_BLANK (VGA_BLANK_N),
        .VGA_SYNC  (VGA_SYNC_N),
        .VGA_CLK   (VGA_CLK)
    );
    defparam VGA.RESOLUTION              = "160x120";
    defparam VGA.MONOCHROME              = "FALSE";
    defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
    defparam VGA.BACKGROUND_IMAGE        = "black.mif";
`endif

    reg s_toggle;
    reg err_seen;
    always @(posedge clk) begin
        if (!resetn) begin
            s_toggle <= 1'b0;
            err_seen <= 1'b0;
        end
        else begin
            if (key_s)       s_toggle <= ~s_toggle;
            if (frame_error) err_seen <= 1'b1;
        end
    end

    assign LEDR[1:0] = ctrl_state;
    assign LEDR[2]   = gen_done;
    assign LEDR[3]   = s_toggle;
    assign LEDR[4]   = err_seen;
    assign LEDR[8:5] = 4'b0000;
    assign LEDR[9]   = ctrl_busy;

    hex7seg H0 (.value (last_make[3:0]),            .seg (HEX0));
    hex7seg H1 (.value (last_make[7:4]),            .seg (HEX1));
    hex7seg H2 (.value ({2'b00, speed_sel}),        .seg (HEX2));
    hex7seg H3 (.value (stack_depth[3:0]),          .seg (HEX3));
    hex7seg H4 (.value (stack_depth[7:4]),          .seg (HEX4));
    hex7seg H5 (.value ({3'b000, stack_depth[8]}),  .seg (HEX5));
endmodule
