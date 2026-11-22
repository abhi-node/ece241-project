# maze_top

**File:** `rtl/maze_top.v`. **Instantiates:** every other module.

## What it does

The top-level entity, whose port names match the DE1-SoC pins. Its main job is wiring; the little logic it has is glue that doesn't belong to any single module.

## Ports

Board pins: `CLOCK_50`, `KEY[3:0]`, `SW[9:0]`, `PS2_CLK`, `PS2_DAT`, `LEDR[9:0]`, `HEX0`-`HEX5`, `VGA_*`.

Parameters: `MAZE_INIT_FILE`, `BACKGROUND_IMAGE` (both default to `../mem/...`) and the three rate-divider periods, which testbenches can shrink.

## Glue logic it owns

**1. Push-button backups.** The buttons are asynchronous and active low. Each is shifted through 3 flip-flops, and a 0→1 step in the synchronised copy gives a one-clock "pressed" pulse that is ORed with the keyboard command.

```verilog
generate_button_sync <= {generate_button_sync[1:0], ~KEY[1]};
wire generate_button_pressed = (generate_button_sync[2:1] == 2'b01);
wire go_generate = key_generate | generate_button_pressed;
```

**2. Maze RAM port A multiplexer.** Only one algorithm runs at a time (`control_fsm` guarantees it), so the port goes to the solver while it is busy and to the generator otherwise.

```verilog
.addr_a (solve_busy ? solve_addr : gen_addr),
.din_a  (solve_busy ? solve_din  : gen_din),
.we_a   (solve_busy ? solve_we   : gen_we),
```

**3. Speed override.** `SW[9]` forces instant speed: `speed_sel = SW[9] ? 2'd3 : key_speed`.

**4. Course VGA adapter hookup.** The ports and parameters must match the course file exactly (`color`, `write`, `COLOR_DEPTH`). The old version used names that don't exist, which was why the VGA didn't compile.

```verilog
vga_adapter #(.RESOLUTION("160x120"), .COLOR_DEPTH(3), .BACKGROUND_IMAGE(BACKGROUND_IMAGE)) VGA (...);
```

**5. Status latches and LEDs.** `maze_generated` and `solve_finished` are set by `done` and cleared by the next start, so the LEDs stay lit after a run.

**6. HEX view switch.** `SW[0]` picks what the six HEX digits show:

```verilog
wire [11:0] live_count = gen_busy ? {3'b000, stack_depth} : {1'b0, path_length};
wire [23:0] debug_view = {last_make, 2'b00, speed_sel, live_count};
wire [23:0] hex_value  = SW[0] ? debug_view : solve_cycles;
```

| `SW[0]` | HEX5-4 | HEX3 | HEX2-0 |
| --- | --- | --- | --- |
| 0 | solve cycles (all six digits) | | |
| 1 | last scan code | speed | stack depth / path length |

## LED map

`LEDR[2:0]` control state, `[3]` maze generated, `[4]` path found, `[5]` no path, `[8]` PS/2 error seen, `[9]` busy.
