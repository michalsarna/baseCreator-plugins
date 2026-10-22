# Circuit board: Gerber and Excellon

Reads the files every circuit board program can write for a manufacturer, so it works for KiCad, EAGLE, Altium, EasyEDA, Fritzing, DipTrace, Proteus, Target 3001 and the rest. **One file is one layer**: use *Import with a plugin…* once for the copper, once for the board outline, once for the drill file. Keep the origin on *As in the file* and the layers land on each other.

## Read

* **Gerber (RS-274X and X2)**: lines and arcs (G01, G02, G03, G74, G75) drawn with round apertures, flashes of round, rectangular, obround and polygon apertures, **aperture macros** (circles, vector and centre lines, outlines, polygons, with `$` variables and expressions: the rounded rectangles that KiCad writes), regions (G36/G37), millimetres and inches, leading or trailing zeros left out.
* **What the file is** comes from the X2 attribute `FileFunction` (copper, profile = the board outline, legend) when the file has one; otherwise it is taken as copper. Set it in the form when it is not what you want.
* **Excellon drill files** (`.drl`, `.xln`, `.exc`, `.drd`): round holes, metric or inch, with or without decimal points.

## Not read

Clear polarity (LPC), step and repeat (SR), aperture transformations (LM, LR, LS), the hole inside an aperture, the thermal and moire macro primitives, routed slots and oval holes of a drill file (they are counted in a message). A line drawn with a rectangular aperture gets the width of its smaller side.

A big board (hundreds of thousands of lines) can take a while: a script may run for ten seconds.

## The form

| Field | What it does |
|---|---|
| Parts to read | tick what to bring in (outline, copper on top / bottom, drill holes, legend); each goes on its own layer |
| Mirror | for a layer that is seen from the top but milled or engraved from the bottom: the whole drawing is turned over left to right |
| Origin | *Board corner to the top left* moves the board so its outline (or, without one, everything read) starts at 0, 0; *As in the file* keeps the coordinates of the program, so several files (copper, outline, drill) land exactly on each other |
| Copper drawn as | *Centre lines*: tracks are lines (for a plotter), pads are outlines. *Outlines grown by the isolation*: the tracks get their real width, pads and traces are merged and grown by the isolation (for milling the isolation or engraving a resist) |
| Isolation | how far the outlines grow, in mm (0 draws the copper as it is) |
| Holes drawn as | circles of the drill size, or small circles at the centres |
| Layers | the program layer (0 is the first) for the outline, the copper, the holes and the legend |

Tried with hand-made files in the style of a KiCad plot (tests/): the real thing from other programs may differ in details, tell us when it does.
