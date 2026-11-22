# vga_adapter (course-provided)

**Files:** `rtl/vga_adapter/vga_adapter.v`, `vga_controller.v`, `vga_address_translator.v`, `vga_pll.v`. **Driven by:** `vga_tile_draw`.

This is the ECE 241 starter code, used unmodified. It isn't ours, but the rest of the design depends on how it behaves.

## What it does

It holds a frame buffer (one colour per pixel) and continuously sends it to the monitor with the correct VGA timing. You write pixels into it; it handles the monitor.

## How we use it

| Port / parameter | Our value |
| --- | --- |
| `RESOLUTION` | `"160x120"`: each "pixel" is drawn as a 4x4 block on the real 640x480 screen |
| `COLOR_DEPTH` | `3`: one bit each of R, G, B, so 8 colours |
| `BACKGROUND_IMAGE` | `../mem/black.mif`: frame buffer contents at power-up |
| `x`, `y`, `color`, `write` | When `write` is high, pixel (x, y) becomes `color` on the next clock |
| `VGA_*` | Straight to the board pins |

## Inside (the short version)

| File | Job |
| --- | --- |
| `vga_adapter.v` | Wraps everything; the dual-port frame buffer (`altsyncram`) has its write side on our clock and its read side on the VGA clock |
| `vga_address_translator.v` | (x, y) → memory address, as `y*160 + x` done with shifts |
| `vga_controller.v` | Counts through 800x525 positions at 25 MHz, generates the HSYNC/VSYNC pulses, and reads each pixel out to the DAC |
| `vga_pll.v` | Makes the 25 MHz pixel clock from 50 MHz |

## Watch out

- The port names are `color` and `write`, **not** `colour` and `plot` like older versions of the adapter.
- It needs Intel's `altsyncram`/`altpll`, so it can't be simulated in plain Icarus. The testbenches use `sim/stubs/vga_adapter_stub.v` instead.
- PLL warnings and "VGA_SYNC_N stuck at VCC" in Quartus are normal.
