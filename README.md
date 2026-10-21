<p align="center"><img src="assets/icon-256.png" alt="baseCreator plugins" width="160"></p>

# baseCreator plugins

The official list of plugins for **[LightCreator](https://github.com/michalsarna/LightCreator)**,
**[MillCreator](https://github.com/michalsarna/MillCreator)** and **[PenCreator](https://github.com/michalsarna/PenCreator)**
(programs on [baseCreator](https://github.com/michalsarna/baseCreator)). A plugin adds clipart, machine presets,
translations, importers of other file formats, **generators of shapes** (a form that makes a drawing) or **G-code
postprocessors** to every program that can use it.

## Using plugins

In any of the programs open **Settings → Plugins… → Official plugins** and press **Check for updates**. The list shows
*all* plugins, also the ones for another program; press **Install**, or **Update** when a newer version is out. The
plugin is downloaded from this site, its checksum is checked, and it is ready in all your programs (they share one
`plugins` folder). In the program the plugin brings:

| It brings | Where you find it |
|---|---|
| a generator | **File → Import → Generate shape…** |
| an importer | **File → Import → Import with a plugin…**, Open, or drag and drop a file |
| a postprocessor | chosen in the Plugins window; used by **Export G-code…** |
| presets, clipart, translations | in the usual lists (adding a device, the clipart gallery, the interface) |

Checking for updates at the start of a program is **off** unless you switch it on in the Plugins window. Nothing is
installed without you pressing the button.

> A plugin is a script that runs in your program. It runs in a sandbox (no files, no network, no machine) and what it
> returns is checked, but a postprocessor still decides which G-code your machine gets: look at the G-code of a new
> postprocessor before you run it.

## The plugins

See the table on **https://michalsarna.github.io/baseCreator-plugins/** (built from this repository), or the folders in
[`plugins/`](plugins/):

| Plugin | What it does |
|---|---|
| [`box-nets`](plugins/box-nets) | the net of a box (prism, truncated prism, pyramid, cylinder, cone, truncated cone) in one piece to cut out of paper or card: continuous outline, dashed folds, glue tabs, pictures with the lengths marked (PenCreator; needs baseCreator 1.12.0) |
| [`box-joints`](plugins/box-joints) | the same boxes for a laser: every face is a separate piece with fingers and notches that fit together, made for the thickness of the material (LightCreator; needs baseCreator 1.12.0) |
| [`fractals`](plugins/fractals) | Sierpinski triangle and carpet, Koch snowflake, Hilbert and dragon curves, Pythagoras tree |
| [`shape-generators`](plugins/shape-generators) | holes on a circle, a spur gear |
| [`xy-points-importer`](plugins/xy-points-importer) | reads text files of `x,y` points |
| [`stl-projection`](plugins/stl-projection) | imports an STL model as outlines: the shadow of the whole model or of chosen planes, or a slice at a depth, with a preview (needs baseCreator 1.6.0) |
| [`gcode-tools`](plugins/gcode-tools) | postprocessors: numbered lines, no comments |

Circuit boards: the list of the programs and the plan for importers is in [`docs/PCB.md`](docs/PCB.md).

## Writing your own

You do not need to know Rust: a plugin is a folder with a `plugin.json` and small [Rhai](https://rhai.rs) scripts.
Start with the **[guide for plugin authors](docs/GUIDE.md)** and copy a folder from [`templates/`](templates/). When it
works, send it here as a pull request ([CONTRIBUTING.md](CONTRIBUTING.md)). Questions, ideas and bugs go to
[Issues](https://github.com/michalsarna/baseCreator-plugins/issues).

## Po polsku

To oficjalna lista wtyczek do LightCreatora, MillCreatora i PenCreatora. W programie otwórz **Settings → Plugins… →
Official plugins** i naciśnij **Check for updates**: zobaczysz wszystkie wtyczki (także dla innych programów), a
**Install** pobiera wtyczkę (z sumą kontrolną) do wspólnego folderu wszystkich programów, **Update** aktualizuje. Sprawdzanie
aktualizacji przy starcie jest domyślnie wyłączone.

Własną wtyczkę napiszesz bez Rusta: to folder z `plugin.json` i krótkimi skryptami Rhai. Zacznij od
[przewodnika dla autorów](docs/GUIDE.md) (po angielsku) i szablonów w [`templates/`](templates/), a gotową wtyczkę wyślij
jako pull request. Błędy i pomysły: [Issues](https://github.com/michalsarna/baseCreator-plugins/issues).

## Licence

Plugins in this repository are `MIT OR Apache-2.0` unless a plugin says otherwise in its `plugin.json`.
