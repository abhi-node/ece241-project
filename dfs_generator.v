`timescale 1ns / 1ns
module dfs_generator (
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire        tick,
    input  wire [1:0]  rand2,
    output reg  [10:0] ram_addr,
    output reg  [2:0]  ram_din,
    output reg         ram_we,
    input  wire [2:0]  ram_q,
    output wire        busy,
    output reg         done,
    output wire [8:0]  stack_depth,
    output wire [4:0]  cur_row,
    output wire [5:0]  cur_col
);
    localparam [4:0] ROWS = 5'd29;
    localparam [5:0] COLS = 6'd39;

    localparam [2:0] T_WALL  = 3'd0,
                     T_PATH  = 3'd1,
                     T_START = 3'd2,
                     T_END   = 3'd3;

    localparam [3:0] S_IDLE   = 4'd0,
                     S_CLEAR  = 4'd1,
                     S_START  = 4'd2,
                     S_READ   = 4'd3,
                     S_LATCH  = 4'd4,
                     S_PICK   = 4'd5,
                     S_CARVE1 = 4'd6,
                     S_CARVE2 = 4'd7,
                     S_POP    = 4'd8,
                     S_POP2   = 4'd9,
                     S_MARK_S = 4'd10,
                     S_MARK_E = 4'd11;

    reg [3:0]  state;
    reg [4:0]  row;
    reg [5:0]  col;
    reg [8:0]  sp;
    reg [10:0] clr_addr;
    reg [1:0]  chk;
    reg [3:0]  unvis;
    reg [1:0]  dir_sel;

    assign busy        = (state != S_IDLE);
    assign stack_depth = sp;
    assign cur_row     = row;
    assign cur_col     = col;

    reg  [1:0] d;
    reg        two;

    always @(*) begin
        if (state == S_CARVE1) begin
            d   = dir_sel;
            two = 1'b0;
        end
        else if (state == S_CARVE2) begin
            d   = dir_sel;
            two = 1'b1;
        end
        else begin
            d   = chk;
            two = 1'b1;
        end
    end

    wire [1:0] step = two ? 2'd2 : 2'd1;

    reg [4:0] n_row;
    reg [5:0] n_col;
    reg       in_bounds;

    always @(*) begin
        n_row     = row;
        n_col     = col;
        in_bounds = 1'b0;
        case (d)
            2'd0: begin n_row = row - {3'b000, step};  in_bounds = (row > 5'd1);        end
            2'd1: begin n_col = col + {4'b0000, step}; in_bounds = (col < COLS - 6'd2); end
            2'd2: begin n_row = row + {3'b000, step};  in_bounds = (row < ROWS - 5'd2); end
            2'd3: begin n_col = col - {4'b0000, step}; in_bounds = (col > 6'd1);        end
        endcase
    end

    wire [1:0] r0 = rand2;
    wire [1:0] r1 = rand2 + 2'd1;
    wire [1:0] r2 = rand2 + 2'd2;
    wire [1:0] r3 = rand2 + 2'd3;
    reg  [1:0] pick;

    always @(*) begin
        if      (unvis[r0]) pick = r0;
        else if (unvis[r1]) pick = r1;
        else if (unvis[r2]) pick = r2;
        else                pick = r3;
    end

    wire [10:0] stk_q;
    wire        stk_we   = (state == S_CARVE2);
    wire [8:0]  stk_addr = (state == S_POP) ? (sp - 9'd1) : sp;

    stack_ram STACK (
        .clk  (clk),
        .addr (stk_addr),
        .din  ({row, col}),
        .we   (stk_we),
        .q    (stk_q)
    );

    always @(*) begin
        ram_addr = {n_row, n_col};
        ram_din  = T_WALL;
        ram_we   = 1'b0;
        case (state)
            S_CLEAR:  begin ram_addr = clr_addr;                    ram_din = T_WALL;  ram_we = 1'b1; end
            S_START:  begin ram_addr = {5'd1, 6'd1};                ram_din = T_PATH;  ram_we = 1'b1; end
            S_CARVE1: begin                                         ram_din = T_PATH;  ram_we = 1'b1; end
            S_CARVE2: begin                                         ram_din = T_PATH;  ram_we = 1'b1; end
            S_MARK_S: begin ram_addr = {5'd1, 6'd1};                ram_din = T_START; ram_we = 1'b1; end
            S_MARK_E: begin ram_addr = {ROWS - 5'd2, COLS - 6'd2};  ram_din = T_END;   ram_we = 1'b1; end
            default:  begin end
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            state    <= S_IDLE;
            row      <= 5'd1;
            col      <= 6'd1;
            sp       <= 9'd0;
            clr_addr <= 11'd0;
            chk      <= 2'd0;
            unvis    <= 4'b0000;
            dir_sel  <= 2'd0;
            done     <= 1'b0;
        end
        else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        done     <= 1'b0;
                        clr_addr <= 11'd0;
                        state    <= S_CLEAR;
                    end
                end

                S_CLEAR: begin
                    clr_addr <= clr_addr + 11'd1;
                    if (clr_addr == 11'd2047)
                        state <= S_START;
                end

                S_START: begin
                    row   <= 5'd1;
                    col   <= 6'd1;
                    sp    <= 9'd0;
                    chk   <= 2'd0;
                    unvis <= 4'b0000;
                    state <= S_READ;
                end

                S_READ: begin
                    state <= S_LATCH;
                end

                S_LATCH: begin
                    unvis[chk] <= in_bounds && (ram_q == T_WALL);
                    chk        <= chk + 2'd1;
                    if (chk == 2'd3) state <= S_PICK;
                    else             state <= S_READ;
                end

                S_PICK: begin
                    if (unvis == 4'b0000)
                        state <= S_POP;
                    else if (tick) begin
                        dir_sel <= pick;
                        state   <= S_CARVE1;
                    end
                end

                S_CARVE1: begin
                    state <= S_CARVE2;
                end

                S_CARVE2: begin
                    sp    <= sp + 9'd1;
                    row   <= n_row;
                    col   <= n_col;
                    chk   <= 2'd0;
                    unvis <= 4'b0000;
                    state <= S_READ;
                end

                S_POP: begin
                    if (sp == 9'd0)
                        state <= S_MARK_S;
                    else begin
                        sp    <= sp - 9'd1;
                        state <= S_POP2;
                    end
                end

                S_POP2: begin
                    row   <= stk_q[10:6];
                    col   <= stk_q[5:0];
                    chk   <= 2'd0;
                    unvis <= 4'b0000;
                    state <= S_READ;
                end

                S_MARK_S: begin
                    state <= S_MARK_E;
                end

                S_MARK_E: begin
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
