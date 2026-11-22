# vga_tile_draw

**File:** `rtl/display/vga_tile_draw.v`. **Reads:** `maze_ram` port B. **Drives:** `vga_adapter`.

## What it does

Copies the maze onto the screen, forever. Each tile becomes a 4x4 block of colour. It has no idea when the maze changes; it just keeps repainting, about 2,600 times a second.

## Ports

| Port | Meaning |
| --- | --- |
| `tile_addr`, `tile_q` | Maze RAM port B |
| `x`, `y`, `color`, `write` | Straight into the VGA adapter: "paint pixel (x, y) this colour" |
| `frame_done` | Pulses once per full repaint (unused, handy for debug) |

## Geometry

The adapter is 160x120. The maze is 39x29 tiles x 4 px = 156x116 px, so a 2-pixel border centres it.

```verilog
assign tile_addr = {row, col};
assign x         = X_OFFSET + {col, 2'b00} + {6'd0, px};
assign y         = Y_OFFSET + {row, 2'b00} + {5'd0, py};
```

`{col, 2'b00}` is `col * 4`: tacking two zeros on the end is the same as multiplying by 4.

## How it works

It is two nested counters (tile, then pixel within the tile) driven by a two-state FSM:

| State | Clocks | Does |
| --- | --- | --- |
| `FETCH` | 1 | Present `{row, col}` to the RAM. Data arrives next clock |
| `PLOT` | 16 | `write` = 1. Step `px` 0-3, and `py` 0-3 each time `px` wraps. After the last pixel, move to the next tile |

The address doesn't change during `PLOT`, so `tile_q` stays valid for all 16 pixels. A frame is 17 x 1,131 = 19,227 clocks.

## Key code

**Colour lookup:** tile code → `{R,G,B}`. Unknown codes show magenta so bugs are obvious.

```verilog
case (tile_q)
    T_WALL:     color = BLUE;
    T_PATH:     color = WHITE;
    ...
    default:    color = MAGENTA;
```

**Odometer advance** at the end of each tile:

```verilog
if (last_pixel) begin
    state <= FETCH;
    col   <= last_col ? 6'd0 : col + 6'd1;
    if (last_col) begin
        row        <= last_row ? 5'd0 : row + 5'd1;
        frame_done <= last_row;
    end
end
```

## The bug this file was blamed for

The drawer itself was fine. The VGA didn't work because `maze_top` connected the adapter with ports that don't exist (`colour`, `plot`, `MONOCHROME`...). See [maze_top](maze_top.md).
