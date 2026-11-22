# Overview

## What it does

The DE1-SoC builds a random maze, then finds the shortest way through it, entirely in hardware. Both are animated on a VGA monitor, and a PS/2 keyboard drives it.

## The demo

| You do | You see |
| --- | --- |
| Program the board | A blue and white maze. Green square top-left (start), red square bottom-right (end) |
| Press `S` | Cyan spreads out from green like water filling the corridors. When it reaches red, a yellow line traces the shortest path back to green |
| Press `G` | The screen fills blue, then white corridors are dug out one step at a time until a new maze covers the screen |
| Press `S` again | The new maze gets solved. The HEX displays show how many clock cycles the solve took |
| Press `1`-`4` | Animation speed: slow, medium, fast, instant |

`KEY[1]` / `KEY[2]` do the same as `G` / `S`, and `KEY[0]` resets.

## The one idea

**The maze is a picture in memory, and everything else either edits the picture or copies it to the screen.**

- A small RAM holds one 3-bit number per tile: wall, path, start, end, explored, or solution.
- The **generator** and **solver** change those numbers. Only one runs at a time.
- The **display** reads the RAM and repaints the whole screen about 2,600 times a second, forever. It is never told that anything changed. It just keeps copying, so every edit shows up almost instantly.
- A **slow-down tick** makes the algorithms take one step at a time so you can watch.

Think of a whiteboard with a camera pointed at it. The generator and solver take turns drawing; the camera streams it live.

## The two algorithms in one line each

- **Generate (depth-first search):** dig from cell to random unvisited cell, leaving a trail of breadcrumbs (a stack). At a dead end, walk back along the trail. When the trail is empty, every cell has been reached exactly once, so the maze has no loops and exactly one route between any two points.
- **Solve (Lee's algorithm):** flood outward from the start one ring at a time (breadth-first search with a queue). Each tile remembers which way it was reached from. When the flood touches the end, follow those arrows back to the start: that is the shortest path.

## What's on screen

| Colour | Tile |
| --- | --- |
| Blue | Wall |
| White | Open path |
| Green / Red | Start / End |
| Cyan | Explored by the solver |
| Yellow | Shortest path |

The maze is 39 x 29 tiles, and each tile is 4 x 4 pixels on the 160 x 120 VGA adapter.

Next: [architecture.md](architecture.md).
