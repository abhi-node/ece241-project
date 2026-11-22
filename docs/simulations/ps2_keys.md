# tb_ps2_keys: keyboard input

**Run:** `do tb_ps2_keys.do`

## What is being tested

The path from the keyboard's two wires to a command: `ps2_rx` (wire → byte) and then `key_decoder` (byte → command).

A PS/2 keyboard sends 11-bit frames on its own slow clock (here 25 kHz). Each frame is a 0 start bit, 8 data bits (LSB first), an odd parity bit, and a 1 stop bit. Pressing a key sends its *make code*. Holding it repeats the make code. Releasing it sends `F0` followed by the make code.

## What the testbench does

It wiggles `ps2_clk` and `ps2_dat` exactly like a real keyboard, one frame at a time:

| Step | Bytes sent | Check |
| --- | --- | --- |
| Hold G | `34 34 34` | Only **one** GENERATE pulse (auto-repeat ignored) |
| Release, press G | `F0 34 34` | A second GENERATE pulse |
| Tap S | `1B F0 1B` | One SOLVE pulse |
| Tap 3, press 4 | `26 F0 26 25` | speed → FAST, then INSTANT |
| Arrow key | `E0 75 E0 F0 75` | No commands at all |
| Corrupted frame | `34` with wrong parity | `bad_frame` pulses, no GENERATE |

## Waves

| Label | Signal | Meaning |
| --- | --- | --- |
| `ps2_clk`, `ps2_data` | `ps2_clk`, `ps2_dat` | The two keyboard wires |
| `bit_count` | `RX/bit_count` | How many bits of the current frame have arrived (0-10) |
| `byte` | `scan_code` | Last good byte received |
| `byte_ready` | `scan_valid` | One-clock pulse when a good byte arrives |
| `bad_frame` | `frame_error` | One-clock pulse when start/stop/parity is wrong |
| `release_next` | `KEYS/release_next` | High after `F0`: the next byte is a release |
| `g_held` | `KEYS/g_held` | G is physically down; blocks repeat pulses |
| `GENERATE`, `SOLVE` | `key_generate`, `key_solve` | The command pulses sent to the control FSM |
| `speed` | `speed_sel` | SLOW / MEDIUM / FAST / INSTANT |
| `last_key` | `last_make` | Last make code (shown on HEX in debug view) |

## What to look for

- Zoom into one frame: `bit_count` steps 0 → 10 on each falling `ps2_clk`, then `byte_ready` blips and `byte` updates.
- During the held-G section, `g_held` goes high on the first `34` and `GENERATE` pulses once. The next two `34`s don't pulse it.
- After each `F0`, `release_next` is high for exactly one byte.
- The command pulses are one 50 MHz clock wide (20 ns). Zoom in a long way to see them.

## Expected transcript

```
ok: generate pulses after held G = 1
ok: last make code = 52
ok: generate pulses after re-press = 2
ok: solve pulses = 1
ok: speed after 3 = 2
ok: speed after 4 = 3
ok: no commands from arrow key = 3
ok: frame errors after bad parity = 1
ok: bad frame ignored = 2
=== tb_ps2_keys: ALL TESTS PASSED ===
```
(52 is `34` hex written in decimal.)
