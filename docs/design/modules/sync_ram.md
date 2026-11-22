# sync_ram

**File:** `rtl/maze/sync_ram.v`. **Used by:** `dfs_generator` (stack), `lee_solver` (queue and parent arrows).

## What it does

A generic single-port block RAM. You set the address width and data width with parameters.

```verilog
module sync_ram #(parameter ADDR_W = 9, parameter DATA_W = 11) (...);
    reg [DATA_W-1:0] mem [0:(1 << ADDR_W) - 1];
    always @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        q <= mem[addr];
    end
endmodule
```

| Instance | Size | Stores |
| --- | --- | --- |
| `dfs_generator.STACK` | 512 x 11 | Positions to backtrack to |
| `lee_solver.QUEUE` | 2048 x 11 | Tiles waiting to be expanded |
| `lee_solver.PARENT` | 2048 x 2 | Direction back toward the start, per tile |

Like `maze_ram`, `q` is valid one clock after the address.
