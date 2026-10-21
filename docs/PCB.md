# Printed circuit boards: programs and plugins

A list of the popular programs for designing printed circuit boards and a plan for plugins that bring their boards into
LightCreator (laser: the board outline, masks, engraving of copper), MillCreator (isolation milling, drilling, outline) and
PenCreator (plotting the traces with a resist pen). Nothing here is written yet: it is the map to build the plugins on.

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

## The plugins to write

One folder per format in [`plugins/`](../plugins/), all of the **importer** kind (a generator is not needed: the board
comes from a file). The order is by how many users it reaches for how little work:

1. **`pcb-gerber`** – Gerber (`.gbr`, `.gtl`, `.gbl`, `.gko`, `.gm1`, ...) and Excellon (`.drl`, `.xln`). Draws (D01 lines
   and arcs, apertures C/R/O/P, regions G36/G37) become outlines; the aperture is the width of the line or a pad. Reaches
   every program above. Form: which layer role the file has (copper / outline / drill / legend), mirror for a bottom layer.
2. **`pcb-kicad`** – `.kicad_pcb`: `gr_line`, `gr_arc`, `gr_rect`, `gr_circle`, `segment`, `arc`, `via`, `zone`
   (filled polygons), `footprint` pads and holes, by layer name. The form picks the layers.
3. **`pcb-eagle`** – `.brd` XML: `<plain>` wires on layer 20 (Dimension), `<signals>` wires, vias, pads, holes.
4. **`pcb-easyeda`** – the JSON of EasyEDA (`TRACK`, `PAD`, `VIA`, `HOLE`, `SOLIDREGION`, `ARC`, `CIRCLE` shapes).
5. **`pcb-fritzing`**, **`pcb-librepcb`**, **`pcb-horizon`**, **`pcb-geda`** – smaller, the same shape of plugin.

Altium and the other binary programs are served by `pcb-gerber` (and, later, a reader of DXF if the base gets one).

### Structure of one plugin

```
plugins/pcb-kicad/
  plugin.json        "importers": [{ "id": "kicad-pcb", "name": "KiCad board (.kicad_pcb)",
                                     "extensions": ["kicad_pcb"], "script": "read.rhai" }]
  read.rhai          fn read(text, ctx) -> shapes;  fn form(text, ctx) -> the layers found, to pick from
  parse.rhai         (optional) the tokenizer of the format, shared by the functions
  tests/sample.kicad_pcb   a small board; the CI runs the importer on it
  CHANGELOG.md
  README.md          what is read, what is not, which program version it was tried with
```

* `form(text, ctx)` lists the layers the file really has (so the user ticks *Edge.Cuts*, *F.Cu*, *drill*), each as a
  `bool` parameter; `read` draws only the ticked ones, each layer on its own program layer (LightCreator and
  MillCreator: layer 0 = the outline, 1 = the traces, 2 = the drill holes; the numbers are parameters).
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

1. `pcb-gerber` first, with a test sample from a KiCad plot.
2. The shared parameters and the labels, translated once (Polish included).
3. `pcb-kicad`, then `pcb-eagle` and `pcb-easyeda`.
4. A page on the plugins site that groups them ("Circuit boards").
