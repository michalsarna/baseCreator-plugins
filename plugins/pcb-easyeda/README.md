# Circuit board: EasyEDA

Reads a PCB document of **EasyEDA Standard** saved as `.json` (*Document → Export → EasyEDA*, or the *Source* of the document). The importer is offered for every `.json` file; a file that has no PCB shapes in it says so.

## Read

* the board outline (layer 10 BoardOutLine): tracks, arcs, circles
* **copper** (1 TopLayer, 2 BottomLayer): tracks, arcs, solid regions, pads (ellipse, rectangle, oval, polygon, with rotation), vias
* **drill holes** of pads, vias and mounting holes
* the **silkscreen** (3 TopSilkLayer, 4 BottomSilkLayer)

One unit of the file is 10 mil = 0.254 mm, as in the converters that are known to work with this format; Y counts down.

## Not read

Copper areas (pours; the file keeps only their outline), text, the slots of oval holes, the Pro edition (`.epro`, a zip: export Gerber from it and use `pcb-gerber`).

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

Tried with a hand-made file (tests/) written after the description of the format, **not with an export from EasyEDA**: check the sizes of the first board against the program. The direction of the pad rotation is the part most likely to need a fix.
