# key_decoder

**File:** `rtl/input/key_decoder.v`. **Driven by:** `ps2_rx`. **Drives:** `control_fsm` (through `maze_top`), `rate_divider`.

## What it does

Turns scan codes into commands, giving exactly **one** command per physical key press.

| Key | Code | Output |
| --- | --- | --- |
| G | `34` | `key_generate` pulse |
| S | `1B` | `key_solve` pulse |
| 1 / 2 / 3 / 4 | `16` / `1E` / `26` / `25` | `speed_sel` = 0 / 1 / 2 / 3 |

## The problem it solves

A keyboard sends:
- **press:** the make code (e.g. `34`)
- **hold:** the make code again, about 10 times a second
- **release:** `F0` then the make code

A naive decoder would generate on every repeat, and again on the release.

## Key code

**Release tracking.** `F0` sets a flag, and the next byte is treated as a release instead of a press:

```verilog
if (scan_code == SC_BREAK)
    release_next <= 1'b1;
else if (scan_code == SC_EXTEND)
    release_next <= release_next;
else if (release_next) begin
    release_next <= 1'b0;
    if (scan_code == SC_G) g_held <= 1'b0;
```

`E0` (the prefix for arrow keys and similar) is skipped without disturbing the flag.

**Held flags stop auto-repeat.** The pulse only fires if the key wasn't already down:

```verilog
SC_G: begin
    key_generate <= !g_held;
    g_held       <= 1'b1;
end
```

**Pulses default to 0.** At the top of the always block, `key_generate <= 1'b0;` means they are high for exactly one clock.

`last_make` remembers the last make code for the HEX debug view.
