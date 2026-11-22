`timescale 1ns / 1ns
module maze_top #(
    parameter        MAZE_INIT_FILE   = "../mem/maze_init.hex",
    parameter        BACKGROUND_IMAGE = "../mem/black.mif",
    parameter [25:0] SLOW_PERIOD      = 26'd6_250_000,
    parameter [25:0] MEDIUM_PERIOD    = 26'd1_562_500,
    parameter [25:0] FAST_PERIOD      = 26'd390_625
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
    wire       scan_valid;
    wire       ps2_frame_error;
    wire       key_generate;
    wire       key_solve;
    wire [1:0] key_speed;
    wire [7:0] last_make;

    ps2_rx PS2 (
        .clk         (clk),
        .resetn      (resetn),
        .ps2_clk     (PS2_CLK),
        .ps2_dat     (PS2_DAT),
        .scan_code   (scan_code),
        .scan_valid  (scan_valid),
        .frame_error (ps2_frame_error)
    );

    key_decoder KEYBOARD (
        .clk          (clk),
        .resetn       (resetn),
        .scan_code    (scan_code),
        .scan_valid   (scan_valid),
        .key_generate (key_generate),
        .key_solve    (key_solve),
        .speed_sel    (key_speed),
        .last_make    (last_make)
    );

    reg [2:0] generate_button_sync;
    reg [2:0] solve_button_sync;

    always @(posedge clk) begin
        if (!resetn) begin
            generate_button_sync <= 3'b000;
            solve_button_sync    <= 3'b000;
        end
        else begin
            generate_button_sync <= {generate_button_sync[1:0], ~KEY[1]};
            solve_button_sync    <= {solve_button_sync[1:0],    ~KEY[2]};
        end
    end

    wire generate_button_pressed = (generate_button_sync[2:1] == 2'b01);
    wire solve_button_pressed    = (solve_button_sync[2:1]    == 2'b01);

    wire go_generate = key_generate | generate_button_pressed;
    wire go_solve    = key_solve    | solve_button_pressed;

    wire       gen_start;
    wire       gen_done;
    wire       solve_start;
    wire       solve_done;
    wire       control_busy;
    wire [2:0] control_state;

    control_fsm CONTROL (
        .clk         (clk),
        .resetn      (resetn),
        .go_generate (go_generate),
        .go_solve    (go_solve),
        .gen_done    (gen_done),
        .solve_done  (solve_done),
        .gen_start   (gen_start),
        .solve_start (solve_start),
        .busy        (control_busy),
        .state_out   (control_state)
    );

    wire [1:0] speed_sel = SW[9] ? 2'd3 : key_speed;
    wire       tick;

    rate_divider #(
        .SLOW_PERIOD   (SLOW_PERIOD),
        .MEDIUM_PERIOD (MEDIUM_PERIOD),
        .FAST_PERIOD   (FAST_PERIOD)
    ) RATE (
        .clk       (clk),
        .resetn    (resetn),
        .speed_sel (speed_sel),
        .tick      (tick)
    );

    wire [15:0] random_bits;

    lfsr16 RANDOM (
        .clk    (clk),
        .resetn (resetn),
        .q      (random_bits)
    );

    wire [10:0] gen_addr;
    wire [2:0]  gen_din;
    wire        gen_we;
    wire        gen_busy;
    wire [8:0]  stack_depth;

    wire [10:0] solve_addr;
    wire [2:0]  solve_din;
    wire        solve_we;
    wire        solve_busy;
    wire        solve_working;
    wire        path_found;
    wire [10:0] path_length;

    wire [2:0]  maze_q_a;
    wire [10:0] draw_addr;
    wire [2:0]  draw_q;

    dfs_generator GENERATOR (
        .clk         (clk),
        .resetn      (resetn),
        .start       (gen_start),
        .tick        (tick),
        .random_dir  (random_bits[1:0]),
        .ram_addr    (gen_addr),
        .ram_din     (gen_din),
        .ram_we      (gen_we),
        .ram_q       (maze_q_a),
        .busy        (gen_busy),
        .done        (gen_done),
        .stack_depth (stack_depth)
    );

    lee_solver SOLVER (
        .clk         (clk),
        .resetn      (resetn),
        .start       (solve_start),
        .tick        (tick),
        .ram_addr    (solve_addr),
        .ram_din     (solve_din),
        .ram_we      (solve_we),
        .ram_q       (maze_q_a),
        .busy        (solve_busy),
        .working     (solve_working),
        .done        (solve_done),
        .found       (path_found),
        .path_length (path_length)
    );

    maze_ram #(
        .INIT_FILE (MAZE_INIT_FILE)
    ) MAZE (
        .clk    (clk),
        .addr_a (solve_busy ? solve_addr : gen_addr),
        .din_a  (solve_busy ? solve_din  : gen_din),
        .we_a   (solve_busy ? solve_we   : gen_we),
        .q_a    (maze_q_a),
        .addr_b (draw_addr),
        .q_b    (draw_q)
    );

    wire [7:0] vga_x;
    wire [6:0] vga_y;
    wire [2:0] vga_color;
    wire       vga_write;

    vga_tile_draw DRAW (
        .clk        (clk),
        .resetn     (resetn),
        .tile_addr  (draw_addr),
        .tile_q     (draw_q),
        .x          (vga_x),
        .y          (vga_y),
        .color      (vga_color),
        .write      (vga_write),
        .frame_done ()
    );

    vga_adapter #(
        .RESOLUTION       ("160x120"),
        .COLOR_DEPTH      (3),
        .BACKGROUND_IMAGE (BACKGROUND_IMAGE)
    ) VGA (
        .resetn      (resetn),
        .clock       (clk),
        .color       (vga_color),
        .x           (vga_x),
        .y           (vga_y),
        .write       (vga_write),
        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N),
        .VGA_CLK     (VGA_CLK)
    );

    wire [23:0] solve_cycles;

    cycle_counter #(.WIDTH(24)) SOLVE_TIMER (
        .clk    (clk),
        .resetn (resetn),
        .clear  (solve_start),
        .enable (solve_working),
        .count  (solve_cycles)
    );

    reg maze_generated;
    reg solve_finished;
    reg ps2_error_seen;

    always @(posedge clk) begin
        if (!resetn) begin
            maze_generated <= 1'b0;
            solve_finished <= 1'b0;
            ps2_error_seen <= 1'b0;
        end
        else begin
            if (gen_start)       maze_generated <= 1'b0;
            else if (gen_done)   maze_generated <= 1'b1;
            if (solve_start)     solve_finished <= 1'b0;
            else if (solve_done) solve_finished <= 1'b1;
            if (ps2_frame_error) ps2_error_seen <= 1'b1;
        end
    end

    assign LEDR[2:0] = control_state;
    assign LEDR[3]   = maze_generated;
    assign LEDR[4]   = solve_finished &&  path_found;
    assign LEDR[5]   = solve_finished && !path_found;
    assign LEDR[7:6] = 2'b00;
    assign LEDR[8]   = ps2_error_seen;
    assign LEDR[9]   = control_busy;

    wire [11:0] live_count = gen_busy ? {3'b000, stack_depth} : {1'b0, path_length};
    wire [23:0] debug_view = {last_make, 2'b00, speed_sel, live_count};
    wire [23:0] hex_value  = SW[0] ? debug_view : solve_cycles;

    hex7seg H0 (.value (hex_value[3:0]),   .seg (HEX0));
    hex7seg H1 (.value (hex_value[7:4]),   .seg (HEX1));
    hex7seg H2 (.value (hex_value[11:8]),  .seg (HEX2));
    hex7seg H3 (.value (hex_value[15:12]), .seg (HEX3));
    hex7seg H4 (.value (hex_value[19:16]), .seg (HEX4));
    hex7seg H5 (.value (hex_value[23:20]), .seg (HEX5));
endmodule
