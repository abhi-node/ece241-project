# hex7seg

**File:** `rtl/display/hex7seg.v`. **Used by:** `maze_top` (six instances, HEX0-HEX5).

## What it does

Converts a 4-bit value into the pattern for one 7-segment display, showing 0-9 and A-F.

## Key code

A 16-entry lookup. The DE1-SoC segments are **active low** (0 = lit), and the bit order is `{g, f, e, d, c, b, a}`:

```verilog
4'h0: seg = 7'b1000000;
4'h1: seg = 7'b1111001;
```

For `0`, only g (the top bit) is 1, so every segment except the middle bar is lit. For `1`, only b and c (the two right-hand segments) are 0.

## Why hex and not decimal

One hex digit is exactly 4 bits, so a 24-bit number splits straight across six displays. Decimal would need a binary-to-BCD converter first.
