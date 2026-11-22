# tb_control: control FSM and rate divider

**Run:** `do tb_control.do`

## What is being tested

**`control_fsm`** decides which algorithm may run. It accepts a request only when IDLE, turns it into a single start pulse, and ignores everything else until that algorithm says it is done.

```
IDLE ──go_generate──► GEN_START ──► GENERATING ──gen_done──► IDLE
IDLE ──go_solve─────► SOLVE_START ─► SOLVING ────solve_done─► IDLE
```

**`rate_divider`** produces the animation `tick`. To keep the test short, the testbench overrides the periods to 10 / 5 / 2 clocks instead of the real millions.

## What the testbench does

| Step | Check |
| --- | --- |
| Pulse go_generate | Exactly one GEN_START, then `busy` |
| Pulse go_generate and go_solve while busy | Ignored |
| Raise gen_done | Back to IDLE |
| Pulse go_solve, then solve_done | One SOLVE_START, back to IDLE |
| Both requests on the same clock | Generate wins |
| speed SLOW / FAST / INSTANT for 100 clocks | 10 / 50 / 100 ticks |

## Waves

| Label | Signal | Meaning |
| --- | --- | --- |
| `go_generate`, `go_solve` | same | Requests in (from the keyboard or buttons) |
| `gen_done`, `solve_done` | same | "Finished" signals from the algorithms (driven by the testbench here) |
| `state` | `state` | IDLE / GEN_START / GENERATING / SOLVE_START / SOLVING |
| `busy` | `busy` | High in any state except IDLE |
| `GEN_START`, `SOLVE_START` | `gen_start`, `solve_start` | The one-clock start pulses |
| `speed` | `speed_sel` | Rate selection |
| `count` | `RATE/count` | Rate divider's internal counter |
| `tick` | `tick` | Animation step pulse |

## What to look for

- Each start pulse is exactly one clock wide, and appears the clock after the request.
- The requests sent mid-GENERATING produce no state change.
- In the tick section, `count` ramps 0 → period-1 and `tick` fires as it wraps. At INSTANT, `tick` stays high.

## Expected transcript

```
ok: gen starts = 1
ok: busy while generating = 1
ok: requests ignored while busy = 1
ok: idle after gen_done = 0
ok: solve starts = 1
ok: idle after solve_done = 0
ok: generate wins a tie = 2
ok: solve lost the tie = 1
ok: slow ticks in 100 clocks = 10
ok: fast ticks in 100 clocks = 50
ok: instant ticks in 100 clocks = 100
=== tb_control: ALL TESTS PASSED ===
```
