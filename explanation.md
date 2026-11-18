# Why each piece exists

## The one idea behind the design

The maze is a picture stored in memory. One part of the circuit edits the picture; another part copies it to the screen, non-stop. They never talk to each other. Everything else exists to decide *when* to edit and *what* to edit.

Think of a whiteboard with a camera pointed at it. The generator is a person drawing on the board. The display is the camera. The viewer sees the drawing appear live, and the person never has to say "I changed something".

## The building blocks

| Block | What it is | Everyday picture |
| --- | --- | --- |
| Flip-flop / register | Remembers a value until the next clock edge | A sticky note you may only rewrite when a bell rings |
| Clock | The bell. Everything steps forward together on each ring | A metronome |
| Combinational logic | Works out an answer from current values, no memory | A calculator |
| Counter | A register that adds 1 each clock | A tally clicker |
| Shift register | A register whose bits slide over by one each clock | People shuffling down a bench |
| State machine | A register that says "which step am I on" plus rules for the next step | A recipe card with a bookmark |
| Block RAM | Many stored values, one reachable per clock via an address | A wall of lockers; takes one bell to open a locker |

There are no latches. A latch is memory that changes whenever its input changes instead of on the bell, which makes timing unpredictable. Every combinational block sets default values so none are created by accident.

## Abhi's side: making the maze

### maze_ram: the whiteboard
**Purpose:** hold the maze so both the generator and the display can use it.
**Why a RAM:** 1,131 tiles as separate flip-flops would waste the FPGA; a memory block stores them cheaply.
**Why two ports:** the generator and the display need different tiles at the same moment. Two doors into the same locker room means neither waits.
**The catch:** a locker takes one clock to open. That delay is why other modules have "wait" steps.

### lfsr16: the dice
**Purpose:** give the generator a random direction.
**Why it is needed:** hardware cannot "roll" anything; it only follows rules. Shifting bits and feeding back an XOR produces a sequence that is fixed but looks shuffled.
**Why mazes still differ:** it spins 50 million times a second, and nobody presses G at the same instant twice. The human is the real randomness.

### dfs_generator: the explorer
**Purpose:** turn a solid block of walls into a maze.
**Intuition:** an explorer in a cave with a pickaxe and a ball of string.
- Look at the four neighbouring rooms. Any still solid rock?
- If yes: pick one at random, dig through, walk in, and lay string behind you.
- If no: follow the string back one room and look again.
- When the string is fully wound up, every room has been dug out.

**Why this gives a good maze:** you only dig into rock you have never been in, so you never tunnel into an existing corridor. No loops, and every room is reached. That means exactly one route between any two points.
**Why it is a state machine:** the explorer can only do one small thing per clock (ask about one neighbour, dig one tile), so the job is split into steps and a register remembers which step is next.

### stack_ram: the ball of string
**Purpose:** remember the way back.
**Why a stack:** backtracking always returns to the *most recent* room first. Last in, first out.
**Why it is needed at all:** software would use recursion; hardware has no such thing, so the trail is stored by hand.

### rate_divider: the slow-motion dial
**Purpose:** make the generation visible.
**Why:** at full speed the whole maze is finished in a fraction of a millisecond. This counts off millions of clocks and lets the explorer dig only when it says "now".

## Ali's side: getting commands in and pictures out

### ps2_rx: the listener
**Purpose:** turn the keyboard's wire signal into a byte.
**Intuition:** the keyboard taps out 11 bits, one per beat of *its own* drum. The receiver writes down one bit per beat, then checks the message is well formed (starts right, ends right, parity adds up).
**Why the synchroniser:** the keyboard's drum is not our clock. Reading a signal at the exact moment it changes can give garbage, so it is passed through a couple of flip-flops first to settle.
**Why the timeout:** if a beat goes missing, the receiver would be off by one bit forever. After a short silence it starts counting fresh.

### key_decoder: the interpreter
**Purpose:** turn bytes into meaning ("generate", "speed 3").
**Why it is not trivial:** a keyboard reports *press* and *release* separately, and repeats the press while the key is held. Without tracking that, holding G would fire dozens of commands. Three one-bit flags remember "that was a release" and "this key is already down".

### control_fsm: the referee
**Purpose:** decide when the generator is allowed to start.
**Why:** a request arriving mid-generation would corrupt the maze. The referee hands out one clean "go" and ignores further requests until the job is done. It is also where "solve" will plug in next milestone.

### vga_tile_draw: the camera
**Purpose:** copy the maze memory to the screen.
**Intuition:** a painter who walks tile by tile, reads its type, and fills a 4x4 square with the matching colour, then starts over, forever.
**Why it never stops:** it does not know or care when the maze changes. Repainting everything about 2,600 times a second is simpler than tracking changes, and far faster than the eye.
**How it is built:** nested counters, like an odometer: pixel inside tile, tile inside row, row inside screen.

### hex7seg: the label maker
**Purpose:** show numbers on the board for debugging (last key, speed, stack depth).
**Why:** you cannot see inside an FPGA. These displays are the window that tells you which part is working when the screen is not.

## The top level: the wiring diagram
**Purpose:** connect the modules to each other and to the board's pins. It adds almost no behaviour of its own, apart from cleaning up the KEY[1] button so one press means one request.

## Why it is split this way
Each module does one job and talks to its neighbours through a few signals. That is what lets two people build halves separately, test each piece alone in simulation, and find a fault by asking "which box stopped doing its job?"
