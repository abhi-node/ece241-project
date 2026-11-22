`timescale 1ns / 1ns
module lee_solver (
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire        tick,
    output reg  [10:0] ram_addr,
    output reg  [2:0]  ram_din,
    output reg         ram_we,
    input  wire [2:0]  ram_q,
    output wire        busy,
    output wire        working,
    output reg         done,
    output reg         found,
    output reg  [10:0] path_length
);
    localparam [10:0] START_ADDR = {5'd1, 6'd1};

    localparam [2:0] T_WALL     = 3'd0,
                     T_PATH     = 3'd1,
                     T_START    = 3'd2,
                     T_END      = 3'd3,
                     T_VISITED  = 3'd4,
                     T_SOLUTION = 3'd5;

    localparam [1:0] NORTH = 2'd0,
                     EAST  = 2'd1,
                     SOUTH = 2'd2,
                     WEST  = 2'd3;

    localparam [3:0] IDLE        = 4'd0,
                     CLEAN_READ  = 4'd1,
                     CLEAN_FIX   = 4'd2,
                     SEED        = 4'd3,
                     POP         = 4'd4,
                     LOAD        = 4'd5,
                     PROBE       = 4'd6,
                     EXPAND      = 4'd7,
                     TRACE_READ  = 4'd8,
                     TRACE_STEP  = 4'd9,
                     TRACE_MARK  = 4'd10,
                     FINISH      = 4'd11;

    reg [3:0]  state;
    reg [10:0] clean_addr;
    reg [10:0] head;
    reg [10:0] tail;
    reg [10:0] cur;
    reg [1:0]  dir;

    wire [10:0] queue_q;
    wire [1:0]  parent_q;

    wire queue_empty = (head == tail);

    wire [1:0] step_dir = (state == TRACE_STEP) ? parent_q : dir;
    wire [4:0] cur_row  = cur[10:6];
    wire [5:0] cur_col  = cur[5:0];
    reg  [10:0] neighbour;

    always @(*) begin
        case (step_dir)
            NORTH: neighbour = {cur_row - 5'd1, cur_col};
            EAST:  neighbour = {cur_row, cur_col + 6'd1};
            SOUTH: neighbour = {cur_row + 5'd1, cur_col};
            default: neighbour = {cur_row, cur_col - 6'd1};
        endcase
    end

    wire [1:0] back_to_cur = dir ^ 2'b10;
    wire       found_end   = (state == EXPAND) && (ram_q == T_END);
    wire       found_open  = (state == EXPAND) && (ram_q == T_PATH);

    wire stalled = !tick && (((state == POP) && !queue_empty) || (state == TRACE_READ));

    assign busy    = (state != IDLE);
    assign working = busy && (state != CLEAN_READ) && (state != CLEAN_FIX) && !stalled;

    sync_ram #(.ADDR_W(11), .DATA_W(11)) QUEUE (
        .clk  (clk),
        .addr ((state == SEED) ? 11'd0 : (state == EXPAND) ? tail : head),
        .din  ((state == SEED) ? START_ADDR : neighbour),
        .we   ((state == SEED) || found_open),
        .q    (queue_q)
    );

    sync_ram #(.ADDR_W(11), .DATA_W(2)) PARENT (
        .clk  (clk),
        .addr ((state == TRACE_READ) ? cur : neighbour),
        .din  (back_to_cur),
        .we   (found_open || found_end),
        .q    (parent_q)
    );

    wire clean_needed = (ram_q == T_VISITED) || (ram_q == T_SOLUTION);

    always @(*) begin
        ram_addr = neighbour;
        ram_din  = T_PATH;
        ram_we   = 1'b0;
        case (state)
            CLEAN_READ: ram_addr = clean_addr;
            CLEAN_FIX:  begin ram_addr = clean_addr; ram_din = T_PATH;     ram_we = clean_needed; end
            EXPAND:     begin                        ram_din = T_VISITED;  ram_we = found_open;   end
            TRACE_MARK: begin ram_addr = cur;        ram_din = T_SOLUTION; ram_we = (cur != START_ADDR); end
            default:    begin end
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            state       <= IDLE;
            clean_addr  <= 11'd0;
            head        <= 11'd0;
            tail        <= 11'd0;
            cur         <= START_ADDR;
            dir         <= NORTH;
            done        <= 1'b0;
            found       <= 1'b0;
            path_length <= 11'd0;
        end
        else begin
            case (state)
                IDLE: if (start) begin
                    done        <= 1'b0;
                    found       <= 1'b0;
                    path_length <= 11'd0;
                    clean_addr  <= 11'd0;
                    state       <= CLEAN_READ;
                end

                CLEAN_READ: state <= CLEAN_FIX;

                CLEAN_FIX: begin
                    clean_addr <= clean_addr + 11'd1;
                    state      <= (&clean_addr) ? SEED : CLEAN_READ;
                end

                SEED: begin
                    head  <= 11'd0;
                    tail  <= 11'd1;
                    state <= POP;
                end

                POP: begin
                    if (queue_empty)
                        state <= FINISH;
                    else if (tick)
                        state <= LOAD;
                end

                LOAD: begin
                    cur   <= queue_q;
                    head  <= head + 11'd1;
                    dir   <= NORTH;
                    state <= PROBE;
                end

                PROBE: state <= EXPAND;

                EXPAND: begin
                    if (found_end) begin
                        found <= 1'b1;
                        cur   <= neighbour;
                        state <= TRACE_READ;
                    end
                    else begin
                        if (found_open)
                            tail <= tail + 11'd1;
                        dir   <= dir + 2'd1;
                        state <= (dir == WEST) ? POP : PROBE;
                    end
                end

                TRACE_READ: if (tick) state <= TRACE_STEP;

                TRACE_STEP: begin
                    cur   <= neighbour;
                    state <= TRACE_MARK;
                end

                TRACE_MARK: begin
                    if (cur == START_ADDR)
                        state <= FINISH;
                    else begin
                        path_length <= path_length + 11'd1;
                        state       <= TRACE_READ;
                    end
                end

                FINISH: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
