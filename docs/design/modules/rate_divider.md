# rate_divider

**File:** `rtl/control/rate_divider.v`. **Drives:** `tick` into `dfs_generator` and `lee_solver`.

## What it does

Slows the algorithms down so they can be watched. It outputs a one-clock `tick` pulse at a chosen rate, and the algorithms take one animated step per tick.

| `speed_sel` | Period (clocks) | Steps/s |
| --- | --- | --- |
| 0 slow | 6,250,000 | 8 |
| 1 medium | 1,562,500 | 32 |
| 2 fast | 390,625 | 128 |
| 3 instant | 1 | 50,000,000 |

## Key code

A counter that resets and fires `tick` when it reaches the period:

```verilog
else if (count >= period - 26'd1) begin
    count <= 26'd0;
    tick  <= 1'b1;
end
else begin
    count <= count + 26'd1;
    tick  <= 1'b0;
end
```

It uses `>=` rather than `==`: if you switch from slow to fast while the count is at 3 million, it fires immediately instead of counting all the way to 2^26 and wrapping.

The periods are parameters, so testbenches pass tiny values like 10 / 5 / 2.
