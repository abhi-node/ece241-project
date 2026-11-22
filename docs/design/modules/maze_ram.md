# maze_ram

**File:** `rtl/maze/maze_ram.v`. **Port A:** `dfs_generator` / `lee_solver` (through the mux in `maze_top`). **Port B:** `vga_tile_draw`.

## What it does

Holds the maze: 2,048 words of 3 bits, one tile code per word. It is the only state the algorithms and the display share.

## Ports

| Port | Meaning |
| --- | --- |
| `addr_a`, `din_a`, `we_a`, `q_a` | Read/write port for whichever algorithm is running |
| `addr_b`, `q_b` | Read-only port for the display |

## Key code

```verilog
reg [2:0] mem [0:2047];

initial $readmemh(INIT_FILE, mem);

always @(posedge clk) begin
    if (we_a)
        mem[addr_a] <= din_a;
    q_a <= mem[addr_a];
end

always @(posedge clk)
    q_b <= mem[addr_b];
```

- **Written in a pattern Quartus recognises,** so it becomes a real M10K block RAM instead of 6,000 flip-flops.
- **Two ports:** the display reads every clock without ever blocking the algorithms, and the two sides never need to coordinate.
- **Registered outputs:** `q` appears one clock after the address. Every FSM that reads it has an "ask" state followed by a "use" state.
- **`$readmemh`** loads `mem/maze_init.hex` at programming time, so a maze is visible before anything is generated. Reset does *not* reload it.

## Address layout

`{row[4:0], col[5:0]}`. Using 6 bits for the column (up to 64) wastes some addresses, but turning (row, col) into an address is then just wiring, with no multiply.
