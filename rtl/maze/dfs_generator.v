/*
 * dfs_generator
 *
 * Carves a random perfect maze (exactly one route between any two tiles) into
 * maze RAM using iterative depth-first search with an explicit stack.
 *
 * Grid: tiles with odd row and odd col are cells (14 x 19 = 266 cells); the
 * tiles between them are walls that may be knocked out. The outer ring is
 * never touched, so the maze always has a solid border.
 *
 * Algorithm ("explorer with a pickaxe and a ball of string"):
 *   CLEAR      write WALL to every tile
 *   OPEN_START open the start cell (1,1), empty the stack
 *   READ/CHECK look two tiles away in each of the 4 directions; a neighbour
 *              cell is "unvisited" if it is in bounds and still WALL
 *   PICK       none unvisited -> BACKTRACK; otherwise wait for an animation
 *              tick and choose one using the LFSR
 *   CARVE_WALL open the wall tile between here and the chosen cell
 *   CARVE_CELL open the chosen cell, push the current cell, move there
 *   BACKTRACK  stack empty -> done; otherwise pop the previous cell
 *   RESUME     move to the popped cell and check its neighbours again
 *   MARK_START / MARK_END  paint the start (1,1) and end (27,37) tiles
 *
 * Every maze RAM read takes a clock, which is why READ and CHECK are separate
 * states. Directions are 0 north, 1 east, 2 south, 3 west.
 */
`timescale 1ns / 1ns
module dfs_generator (
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire        tick,
    input  wire [1:0]  random_dir,
    output reg  [10:0] ram_addr,
    output reg  [2:0]  ram_din,
    output reg         ram_we,
    input  wire [2:0]  ram_q,
    output wire        busy,
    output reg         done,
    output wire [8:0]  stack_depth
);
    localparam [4:0] ROWS = 5'd29;
    localparam [5:0] COLS = 6'd39;

    localparam [10:0] START_ADDR = {5'd1, 6'd1};
    localparam [10:0] END_ADDR   = {ROWS - 5'd2, COLS - 6'd2};

    localparam [2:0] T_WALL  = 3'd0,
                     T_PATH  = 3'd1,
                     T_START = 3'd2,
                     T_END   = 3'd3;

    localparam [1:0] NORTH = 2'd0,
                     EAST  = 2'd1,
                     SOUTH = 2'd2,
                     WEST  = 2'd3;

    localparam [3:0] IDLE       = 4'd0,
                     CLEAR      = 4'd1,
                     OPEN_START = 4'd2,
                     READ       = 4'd3,
                     CHECK      = 4'd4,
                     PICK       = 4'd5,
                     CARVE_WALL = 4'd6,
                     CARVE_CELL = 4'd7,
                     BACKTRACK  = 4'd8,
                     RESUME     = 4'd9,
                     MARK_START = 4'd10,
                     MARK_END   = 4'd11;

    reg [3:0]  state;
    reg [4:0]  row;
    reg [5:0]  col;
    reg [8:0]  sp;
    reg [10:0] clear_addr;
    reg [1:0]  check_dir;
    reg [3:0]  unvisited;
    reg [1:0]  chosen_dir;

    assign busy        = (state != IDLE);
    assign stack_depth = sp;

    wire       carving   = (state == CARVE_WALL) || (state == CARVE_CELL);
    wire [1:0] probe_dir = carving ? chosen_dir : check_dir;
    wire [1:0] distance  = (state == CARVE_WALL) ? 2'd1 : 2'd2;

    reg [4:0] probe_row;
    reg [5:0] probe_col;
    reg       probe_in_bounds;

    always @(*) begin
        probe_row       = row;
        probe_col       = col;
        probe_in_bounds = 1'b0;
        case (probe_dir)
            NORTH: begin probe_row = row - distance; probe_in_bounds = (row > 5'd1);        end
            EAST:  begin probe_col = col + distance; probe_in_bounds = (col < COLS - 6'd2); end
            SOUTH: begin probe_row = row + distance; probe_in_bounds = (row < ROWS - 5'd2); end
            WEST:  begin probe_col = col - distance; probe_in_bounds = (col > 6'd1);        end
        endcase
    end

    wire [1:0] try0 = random_dir;
    wire [1:0] try1 = random_dir + 2'd1;
    wire [1:0] try2 = random_dir + 2'd2;
    wire [1:0] try3 = random_dir + 2'd3;
    reg  [1:0] random_unvisited;

    always @(*) begin
        if      (unvisited[try0]) random_unvisited = try0;
        else if (unvisited[try1]) random_unvisited = try1;
        else if (unvisited[try2]) random_unvisited = try2;
        else                      random_unvisited = try3;
    end

    wire [10:0] stack_q;

    sync_ram #(.ADDR_W(9), .DATA_W(11)) STACK (
        .clk  (clk),
        .addr ((state == BACKTRACK) ? sp - 9'd1 : sp),
        .din  ({row, col}),
        .we   (state == CARVE_CELL),
        .q    (stack_q)
    );

    always @(*) begin
        ram_addr = {probe_row, probe_col};
        ram_din  = T_WALL;
        ram_we   = 1'b0;
        case (state)
            CLEAR:      begin ram_addr = clear_addr; ram_din = T_WALL;  ram_we = 1'b1; end
            OPEN_START: begin ram_addr = START_ADDR; ram_din = T_PATH;  ram_we = 1'b1; end
            CARVE_WALL: begin                        ram_din = T_PATH;  ram_we = 1'b1; end
            CARVE_CELL: begin                        ram_din = T_PATH;  ram_we = 1'b1; end
            MARK_START: begin ram_addr = START_ADDR; ram_din = T_START; ram_we = 1'b1; end
            MARK_END:   begin ram_addr = END_ADDR;   ram_din = T_END;   ram_we = 1'b1; end
            default:    begin end
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            state      <= IDLE;
            row        <= 5'd1;
            col        <= 6'd1;
            sp         <= 9'd0;
            clear_addr <= 11'd0;
            check_dir  <= NORTH;
            unvisited  <= 4'b0000;
            chosen_dir <= NORTH;
            done       <= 1'b0;
        end
        else begin
            case (state)
                IDLE: if (start) begin
                    done       <= 1'b0;
                    clear_addr <= 11'd0;
                    state      <= CLEAR;
                end

                CLEAR: begin
                    clear_addr <= clear_addr + 11'd1;
                    if (&clear_addr)
                        state <= OPEN_START;
                end

                OPEN_START: begin
                    row       <= 5'd1;
                    col       <= 6'd1;
                    sp        <= 9'd0;
                    check_dir <= NORTH;
                    unvisited <= 4'b0000;
                    state     <= READ;
                end

                READ: state <= CHECK;

                CHECK: begin
                    unvisited[check_dir] <= probe_in_bounds && (ram_q == T_WALL);
                    check_dir            <= check_dir + 2'd1;
                    state                <= (check_dir == WEST) ? PICK : READ;
                end

                PICK: begin
                    if (unvisited == 4'b0000)
                        state <= BACKTRACK;
                    else if (tick) begin
                        chosen_dir <= random_unvisited;
                        state      <= CARVE_WALL;
                    end
                end

                CARVE_WALL: state <= CARVE_CELL;

                CARVE_CELL: begin
                    sp        <= sp + 9'd1;
                    row       <= probe_row;
                    col       <= probe_col;
                    check_dir <= NORTH;
                    unvisited <= 4'b0000;
                    state     <= READ;
                end

                BACKTRACK: begin
                    if (sp == 9'd0)
                        state <= MARK_START;
                    else begin
                        sp    <= sp - 9'd1;
                        state <= RESUME;
                    end
                end

                RESUME: begin
                    row       <= stack_q[10:6];
                    col       <= stack_q[5:0];
                    check_dir <= NORTH;
                    unvisited <= 4'b0000;
                    state     <= READ;
                end

                MARK_START: state <= MARK_END;

                MARK_END: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
