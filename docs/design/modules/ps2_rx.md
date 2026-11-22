# ps2_rx

**File:** `rtl/input/ps2_rx.v`. **Drives:** `key_decoder`.

## What it does

Turns the keyboard's two wires (`PS2_CLK`, `PS2_DAT`) into bytes.

## The PS/2 frame

The keyboard drives its own clock (about 10-17 kHz) and sends 11 bits, each valid on a **falling** clock edge:

```
start(0)  d0 d1 d2 d3 d4 d5 d6 d7  parity(odd)  stop(1)
```

## Ports

| Port | Meaning |
| --- | --- |
| `ps2_clk`, `ps2_dat` | The raw keyboard wires |
| `scan_code` | Last good byte |
| `scan_valid` | One-clock pulse per good byte |
| `frame_error` | One-clock pulse per bad frame |

## Key code

**Synchronisers.** The keyboard's signals aren't timed to our clock, so they pass through 2-3 flip-flops first. A falling edge is "was 1, now 0" in the synchronised copy.

```verilog
clk_sync <= {clk_sync[1:0], ps2_clk};
wire ps2_falling_edge = (clk_sync[2:1] == 2'b10);
```

**Shift in from the top.** On each falling edge the new bit enters at bit 10 and everything moves right. After 10 bits the start bit is at `shift[1]`, the data at `shift[9:2]` and the parity at `shift[10]`. The stop bit is checked live on the 11th edge.

```verilog
shift <= {ps2_bit, shift[10:1]};
...
wire start_ok  = (shift[1] == 1'b0);
wire stop_ok   = (ps2_bit == 1'b1);
wire parity_ok = (^shift[10:2] == 1'b1);
```

`^` XORs all the bits together. Odd parity means data plus parity has an odd number of 1s, so the XOR is 1.

**Timeout.** If the keyboard goes quiet mid-frame (a missed edge, or unplugging), `idle_count` fills up and resets `bit_count`. Without this, one glitch would misalign every byte after it.

```verilog
else if (bit_count != 4'd0) begin
    idle_count <= idle_count + 1'b1;
    if (&idle_count)
        bit_count <= 4'd0;
```
