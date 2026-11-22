# cycle_counter

**File:** `rtl/control/cycle_counter.v`. **Driven by:** `lee_solver.working`, `control_fsm.solve_start`. **Drives:** the HEX displays.

## What it does

Counts how many clock cycles the solve takes. This is the "performance" number shown on the board.

## Key code

```verilog
if (!resetn || clear)
    count <= {WIDTH{1'b0}};
else if (enable && !(&count))
    count <= count + 1'b1;
```

- `clear` is wired to `solve_start`, so every solve starts from 0.
- `enable` is wired to the solver's `working` signal. That is low while the solver is cleaning up the last run or waiting for an animation tick, so **the count is the same at every speed**. It measures the algorithm, not the animation.
- `!(&count)` means "not all ones": the counter saturates at FFFFFF instead of wrapping back to 0.
