# lfsr16

**File:** `rtl/maze/lfsr16.v`. **Drives:** `random_dir` (bits [1:0]) into `dfs_generator`.

## What it does

Produces pseudo-random numbers. Hardware can't roll dice, but a linear-feedback shift register produces a sequence that looks shuffled.

## Key code

```verilog
wire feedback = q[15] ^ q[13] ^ q[12] ^ q[10];
q <= {q[14:0], feedback};
```

Every clock, the bits shift left and the XOR of four "tap" bits enters on the right. These taps give a **maximal-length** sequence: all 65,535 non-zero values before it repeats. All-zero would lock up (0 XOR 0 = 0), so it is seeded with `ACE1`.

## Why the mazes are actually random

The sequence is fixed, but the register changes 50 million times a second, and the generator reads it at whatever moment you press G. Human timing is the randomness.
