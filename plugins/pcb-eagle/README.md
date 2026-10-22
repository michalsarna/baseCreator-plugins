# Circuit board: EAGLE

Reads an Autodesk EAGLE or Fusion Electronics board (`.brd`, the XML format).

## Read

* the board outline (layer **20 Dimension**), also arcs (`curve`)
* **copper** (layers 1 Top and 16 Bottom): wires, vias, pads (round, square, octagon, long), SMD pads (also rounded), rectangles and circles; the parts of the board are built from the packages in the libraries of the file, placed with their rotation and **mirroring** (a part on the bottom side swaps its layers)
* **drill holes** of pads, vias and mounting holes
* the **silkscreen** (21 tPlace, 22 bPlace): wires, circles, rectangles, polygons

## Not read

Copper pours (a polygon in a signal): the file keeps only its outline, not the clearances around the other traces, so drawing it would join everything; the plugin counts them in a message and leaves them out. Text. A pad with no diameter in the file (the design rules decide it) gets twice its drill.

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

Tried with a hand-made board (tests/) and by reading the format: not yet with a board from a real project. For a board with pours use Gerber from EAGLE instead (`pcb-gerber`).
