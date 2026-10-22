# Printed circuit boards: programs and plugins

A list of the popular programs for designing printed circuit boards and a plan for plugins that bring their boards into
LightCreator (laser: the board outline, masks, engraving of copper), MillCreator (isolation milling, drilling, outline) and
PenCreator (plotting the traces with a resist pen). The first four plugins are written (see *The plugins* below); the rest of the programs are the map for the next ones.

## What a program has to give us

A board is a set of layers. Whatever the program, the plugin needs the same things:

| Need | Used for |
|---|---|
| board outline (Edge.Cuts, profile) | cutting out / milling the board |
| copper layers (top, bottom) as traces, pads, zones | isolation milling, laser engraving of the resist, pen plotting |
| drill holes (position, diameter, plated or not) | drilling, milling of larger holes |
| solder mask, silkscreen (optional) | engraving the legend, cutting stencils |
| units and the origin | placing the board on the work area |

The two formats nearly every program can write are **Gerber (RS-274X / X2)** for the layers and **Excellon** for the
drill holes. A Gerber + Excellon importer therefore reaches all the programs below; the native readers are worth writing
only where the native file keeps more (a single file, net names, the real shape of the outline).

## The programs

| Program | Licence | Native board file | Easy to read? | Other ways out |
|---|---|---|---|---|
| **KiCad** | free (GPL) | `.kicad_pcb` (text, S-expression) | yes, plain text, documented | Gerber + drill, SVG, DXF plot, Python (`pcbnew`) |
| **Autodesk EAGLE** / Fusion Electronics | commercial (free tier) | `.brd` (XML) | yes, XML | Gerber + drill, CAM jobs, ULP scripts |
| **Altium Designer** / CircuitMaker | commercial | `.PcbDoc` (binary OLE) | no | Gerber X2, ODB++, DXF, IPC-2581 |
| **EasyEDA** / EasyEDA Pro (LCSC) | free online | JSON (`.json`, `.epro`) | yes, JSON | Gerber + drill, PDF/SVG |
| **Fritzing** | free (GPL) | `.fzz` (zip with `.fz` XML) | yes, XML | Gerber + drill, SVG per layer |
| **DipTrace** | commercial (free tier) | `.dip` (binary) | no | Gerber + drill, DXF |
| **OrCAD / Allegro** (Cadence) | commercial | `.brd` (binary) | no | Gerber, ODB++, IPC-2581 |
| **PADS / Xpedition** (Siemens) | commercial | `.pcb`, `.pcbdoc` | no | Gerber, ODB++, DXF |
| **Proteus (Ares)** | commercial | `.pdsprj` | no | Gerber + drill, DXF |
| **Target 3001!** | commercial (free tier) | `.t3001` | no | Gerber + drill, DXF |
| **LibrePCB** | free (GPL) | `.lppz` (zip of text files) | yes, text, documented | Gerber + drill, SVG |
| **Horizon EDA** | free (GPL) | `.json` | yes, JSON | Gerber + drill, SVG |
| **gEDA PCB** / pcb-rnd | free (GPL) | `.pcb` (text) | yes, text | Gerber, SVG, DXF |
| **Flux.ai**, **CELUS** | online | cloud | no | Gerber + drill |

How to read the table: *Easy to read* means a Rhai script can do it from the text of the file. Binary formats are better
reached through Gerber; a plugin gets the whole file as a string today (see the importer template), so a binary reader
would need a new base function and is out of scope.

## The plugins

One folder per format in [`plugins/`](../plugins/), all of the **importer** kind (a generator is not needed: the board
comes from a file). The order was by how many users it reaches for how little work:

| Plugin | Reads | Status |
|---|---|---|
| [`pcb-gerber`](../plugins/pcb-gerber) | Gerber (RS-274X, X2) layers and Excellon drill files: lines, arcs, round / rectangular / obround / polygon apertures, aperture macros, regions. Reaches every program above | done |
| [`pcb-kicad`](../plugins/pcb-kicad) | `.kicad_pcb` (5 to 8): outline, tracks, pads, vias, filled zones, holes, silkscreen, by layer | done (needs baseCreator 1.15.0) |
| [`pcb-eagle`](../plugins/pcb-eagle) | `.brd` XML: Dimension outline, wires, pads, SMD pads, vias, holes, silkscreen, parts built from the libraries of the file | done (pours are left out) |
| [`pcb-easyeda`](../plugins/pcb-easyeda) | the PCB JSON of EasyEDA Standard: tracks, arcs, circles, solid regions, pads, vias, holes | done (written from the format description, not tried on a real export) |
| `pcb-horizon`, `pcb-geda` | Horizon EDA JSON, gEDA PCB / pcb-rnd text | not written |
| `pcb-fritzing`, `pcb-librepcb` | `.fzz` and `.lppz` are zip archives: a script gets one file as text, so these need the archive to be opened by the program first (a new base function) | not written, use Gerber |

Altium and the other binary programs are served by `pcb-gerber` (and, later, a reader of DXF if the base gets one).

All four share one form (the same ids, labels and translations): which parts to read, `mirror`, `origin`, how to draw the
copper (centre lines for a plotter, or outlines grown by the `isolation` for milling and laser), how to draw the holes and
the program layer of each part. The shared code is the same text in every `read.rhai` (a plugin cannot import another); its source and the script that pastes it
are in [`tools/pcb/`](../tools/pcb) (`python3 tools/pcb/build.py gerber kicad eagle easyeda`).

What a script of a plugin may do shaped the code, and is worth knowing for the next ones: an array of arrays gets slow when
it is long (the sandbox looks through the whole array at every `push`), so the pieces of a board are arrays with the points
written as one text; object maps are limited to 20 000 entries, so more than 300 contours of a layer are returned as a few
compound `path` shapes, not as a shape each; the union of the copper is made in batches; a script may run 10 seconds, which a
board of about ten thousand tracks reaches in *outlines* mode (the centre lines take about a second).

### Structure of one plugin

```
plugins/pcb-kicad/
  plugin.json        "importers": [{ "id": "kicad-pcb", "name": "KiCad board (.kicad_pcb)",
                                     "extensions": ["kicad_pcb"], "script": "read.rhai", "params": [...] }]
  read.rhai          fn read(text, ctx) -> shapes (ctx.p holds the values of the form); the shared code is pasted in it by `tools/pcb/build.py`
  tests/sample.kicad_pcb   a small board; the CI runs the importer on it
  CHANGELOG.md
  README.md          what is read, what is not, which program version it was tried with
```

* the form has a `bool` for each part of the board (*Edge.Cuts*, *F.Cu*, drill holes...); `read` draws only the ticked ones,
  each on its own program layer (layer 0 = the outline, 1 = the copper, 2 = the drill holes, 3 = the legend; the numbers are
  parameters). A `form(text, ctx)` function could list the layers a file really has; the four plugins use a fixed list.
* Parameters common to all the PCB plugins (same ids, same labels, so one translation serves all):
  `mirror` (a bottom layer is seen from the top), `isolation` (grow the traces by this many mm for isolation milling),
  `holes_as` (circles of the real size / points for drilling), `origin` (board corner / drill origin).
* Output: closed outlines for the board and the pads, open polylines for traces of width 0 (the width is a parameter
  for the pen and the laser), circles for holes. Arcs are flattened by the importer.
* A plugin warns (`warn(...)`) about what it skips: a copper zone that is not filled, a text, a 3D model.

### Plan for MillCreator and LightCreator

| Task | Needs |
|---|---|
| isolation milling of traces | the trace outlines grown by `isolation`; `union_polygons` merges the overlaps |
| drilling | holes as circles with the diameter; MillCreator drills each one with a tool of that size |
| outline cut | the Edge.Cuts outline as the cut path on its own layer |
| laser engraving of resist / mask | filled copper as an area to engrave (layer 1), the board outline as the cut |
| pen plotter | traces as lines, pads as small circles |

## Next steps

1. Try the readers on real boards from the programs and fix what differs (the EasyEDA ones most of all).
2. `pcb-horizon` and `pcb-geda`; the zip formats when the base can open an archive.
3. A page on the plugins site that groups them ("Circuit boards").
4. Copper pours: EAGLE and EasyEDA keep only the outline of a pour, so the plugins leave them out; a base function that
   subtracts the other copper (`difference_polygons`) would let them be drawn with their clearances.
