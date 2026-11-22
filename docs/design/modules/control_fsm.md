# control_fsm

**File:** `rtl/control/control_fsm.v`. **Driven by:** `key_decoder` and the buttons (via `maze_top`). **Drives:** `dfs_generator`, `lee_solver`.

## What it does

The referee. It makes sure only one algorithm uses the maze at a time, and turns a request into exactly one start pulse.

## Ports

| Port | Dir | Meaning |
| --- | --- | --- |
| `go_generate`, `go_solve` | in | Request pulses |
| `gen_done`, `solve_done` | in | The algorithms' finished flags |
| `gen_start`, `solve_start` | out | One-clock start pulses |
| `busy` | out | Not idle |
| `state_out` | out | Current state, shown on LEDR[2:0] |

## How it works

```
IDLE ──go_generate──► GEN_START ──► GENERATING ──gen_done──► IDLE
IDLE ──go_solve─────► SOLVE_START ─► SOLVING ────solve_done─► IDLE
```

Requests are only looked at in IDLE, so pressing G mid-solve does nothing. If both arrive on the same clock, generate wins.

## Key code

This is the standard two-block FSM: a combinational next-state block (with a default, so no latches) and a clocked state register.

```verilog
always @(*) begin
    next = state;
    case (state)
        IDLE:        if (go_generate)    next = GEN_START;
                     else if (go_solve)  next = SOLVE_START;
        GEN_START:                       next = GENERATING;
        GENERATING:  if (gen_done)       next = IDLE;
        ...
```

The outputs come straight from the state (Moore-style), so each START state lasts exactly one clock and the pulse is clean:

```verilog
assign gen_start = (state == GEN_START);
```

## Why the done flag can't fire early

The algorithms' `done` stays high after they finish. On the clock that `gen_start` is seen, the generator clears `done` at the same edge the FSM moves to GENERATING, so GENERATING never sees a stale `done`.
