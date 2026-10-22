# Circuit board: KiCad

Reads a KiCad board file (`.kicad_pcb`, KiCad 5 to 8). Needs baseCreator 1.15.0 (the extension has an underscore).

## Read

* the board outline (**Edge.Cuts**): lines, arcs, circles, rectangles, polygons, also inside footprints; the pieces are chained into closed contours
* **copper** on F.Cu and B.Cu: tracks (`segment`), arc tracks, vias, **filled zones** (`filled_polygon`), **pads** of the footprints in their place and rotation (circle, rectangle, oval, rounded rectangle; a trapezoid and a custom pad as a rectangle of their size)
* **drill holes** of pads and vias (a hole of a pad that is not plated too)
* the **silkscreen** lines, arcs, circles, rectangles and polygons (F.SilkS, B.SilkS)

## Not read

Text, the inner copper layers, a zone that is not filled (save the board after filling the zones: the plugin tells you), the slot of an oval drill (a round hole of its smaller side is drawn), the shape primitives of custom pads.

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

Tried with a hand-made board in the KiCad 7 format (tests/) and by reading the file format: not yet with boards from a real project. The arc of KiCad 5 (`gr_arc` with an angle) is read the way the format is documented; tell us if one comes out the wrong way round.
