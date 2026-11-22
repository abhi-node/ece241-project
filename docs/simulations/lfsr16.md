# tb_lfsr16: random number source

**Run:** `do tb_lfsr16.do`

## What is being tested

`lfsr16` is a 16-bit shift register whose new bit is the XOR of four of its old bits. The generator uses its bottom two bits as a random direction. Two things must hold:

1. It never reaches `0000`, because once there it would stay there forever.
2. It visits all 65,535 non-zero values before repeating. That is the "maximal length" property, and it means the directions don't fall into a short loop.

## What the testbench does

Releases reset, then counts clocks until the register is back at its seed value `ACE1`, checking for zero on every clock. It passes if the count is exactly 65,535.

## Waves

| Label | Signal | Meaning |
| --- | --- | --- |
| `clk` | `clk` | 50 MHz clock |
| `reset_n` | `resetn` | Active-low reset |
| `random` | `q` | The full 16-bit value, in hex |
| `random[1:0]` | `q[1:0]` | The two bits the generator uses as a direction |

## What to look for

- At reset `random` = `ACE1`.
- Each clock the hex digits shift left by one bit and a new bit enters on the right.
- `random[1:0]` hops between 0-3 with no obvious pattern.

## Expected transcript

```
ok: period 65535, never zero
=== tb_lfsr16: ALL TESTS PASSED ===
```
