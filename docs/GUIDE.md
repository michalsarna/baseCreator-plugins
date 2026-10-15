# Guide for plugin authors

A plugin is a **folder** with a `plugin.json` (the manifest) and the files it names. Programs on baseCreator
(LightCreator, MillCreator, PenCreator) load it from their shared `plugins` folder or install it from the
[official list](https://michalsarna.github.io/baseCreator-plugins/).

- [1. Your first plugin in five minutes](#1-your-first-plugin-in-five-minutes)
- [2. The manifest](#2-the-manifest)
- [3. Scripts: the language and the functions you get](#3-scripts-the-language-and-the-functions-you-get)
- [4. Generators](#4-generators)
- [5. Importers](#5-importers)
- [6. Postprocessors](#6-postprocessors)
- [7. Packs without code](#7-packs-without-code)
- [8. Testing](#8-testing)
- [9. Rules and safety](#9-rules-and-safety)
- [10. Sending it to the official list](#10-sending-it-to-the-official-list)
- [11. Versions and updates](#11-versions-and-updates)
- [12. Rhai pitfalls](#12-rhai-pitfalls)

## 1. Your first plugin in five minutes

1. Copy [`templates/generator`](../templates/generator) to a folder named like the plugin's `id`, for example
   `my-generator`, inside the `plugins` folder of the programs. (Settings → Plugins… → **Open plugins folder** shows
   where it is; on macOS `~/Library/Application Support/baseCreator/plugins`.)
2. Edit `plugin.json` (the `id` must equal the folder name) and the script.
3. In the program: Settings → Plugins… → **Reload plugins**. A plugin with a mistake is listed with the reason.
4. **File → Import → Generate shape…** and your generator is in the list.

## 2. The manifest

`plugin.json`, with every key you may use (all but `format`, `id`, `name` are optional):

```json
{
  "format": 1,
  "id": "my-plugin",
  "name": "My plugin",
  "version": "1.0.0",
  "min_base": "0.9.8",
  "author": "Me",
  "license": "MIT OR Apache-2.0",
  "description": "What it does, in a sentence or two.",
  "programs": ["millcreator", "pencreator"],

  "presets":   [ { "name": "My router (400 × 300)", "class": "mill", "area": [400, 300, 60], "rapid": 2000, "spindle_max": 12000 } ],
  "clipart":   [ { "file": "clipart/star.svg", "name": "Star", "category": "My pack", "license": "CC0", "author": "Me" } ],
  "texts":     { "pl": { "My plugin": "Moja wtyczka" } },
  "data":      [ { "kind": "mill-tools", "file": "data/tools.json" } ],

  "importers":      [ { "id": "xy", "name": "XY points", "extensions": ["xy"], "script": "read.rhai" } ],
  "generators":     [ { "id": "holes", "name": "Holes", "description": "…", "script": "holes.rhai", "params": [ ] } ],
  "postprocessors": [ { "id": "numbers", "name": "Number the lines", "description": "…", "script": "numbers.rhai" } ]
}
```

- `id`: 1–64 characters `a-z 0-9 - _`, **the same as the folder name**. It never changes; the list uses it to update.
- `version`: numbers separated by dots (`1.2.0`). Newer = bigger number (`1.10.0` is newer than `1.9.0`).
- `min_base`: the oldest baseCreator (the shared base of the programs) the plugin needs. The `VERSIONS.md` of every program says
  which baseCreator a release uses ("baseCreator v0.9.8"); if unsure, use the version you tested with. The official list does not
  offer a plugin to a program that is too old, and the program refuses to load it.
- `programs`: leave out for all programs; otherwise a list of `lightcreator`, `millcreator`, `pencreator`. The official
  list shows every plugin to everybody, but marks which programs it is for.
- Paths are relative to the plugin folder, no `..`. Scripts end in `.rhai`. Files are limited to 8 MB.
- `texts`: `language code → English text → translation`. They translate the plugin's own texts: `name`,
  `description`, the labels and options of the forms, importer and postprocessor names. Language codes are the ones of
  the programs (`pl`, `de`, `it`, `fi`, `zh`, `hi`, `bg`, `ca`, `hr`, `cs`, `da`, `nl`, `et`, `fr`, `el`, `hu`, `is`,
  `ga`, `lv`, `lt`, `mt`, `nb`, `pt`, `ro`, `sk`, `sl`, `es`, `sv`, `uk`).
- Importers must not use the extensions the programs read themselves (`svg pdf ai cre lbrn lbrn2 ugsd png jpg jpeg bmp gif webp`).

## 3. Scripts: the language and the functions you get

Scripts are [Rhai](https://rhai.rs/book/): a small language that looks like Rust/JavaScript. Each script defines one
function with a fixed name (the second parameter `ctx` may be left out):

| Kind | Function | Gets | Returns |
|---|---|---|---|
| importer | `fn read(text, ctx)` | the file as text | shapes |
| generator | `fn generate(p, ctx)` | the values of the form (a map) | shapes |
| postprocessor | `fn post(lines, ctx)` | the lines of the program (array of strings) | the new lines |

`ctx` is `#{ app, area_w, area_h }`: the program (`"millcreator"`) and the work area in millimetres.

**Shapes** are one shape or an array of shapes (arrays may be nested). Coordinates are **millimetres, the origin is the top
left corner of the work area, Y goes down** (like the drawing in the programs). An importer for a format with Y up
turns it over with `ctx.area_h - y`.

| Function | Makes |
|---|---|
| `rect(x, y, w, h)` · `rounded_rect(x, y, w, h, r)` | rectangles (x, y is the top left corner) |
| `circle(cx, cy, r)` · `ellipse(cx, cy, rx, ry)` | circles, ellipses |
| `line(x1, y1, x2, y2)` | a line |
| `polyline(points)` · `polygon(points)` | open and closed shapes from `[[x, y], …]` |
| `path(segments)` | curves: `["M", x, y]` `["L", x, y]` `["Q", cx, cy, x, y]` `["C", c1x, c1y, c2x, c2y, x, y]` `["Z"]` |
| `text("…", x, y, size)` | live text (set `.family`, `.bold`, `.italic` on it) |
| `group([shapes])` | shapes that move together |
| `translate(s, dx, dy)` · `rotate(s, degrees, cx, cy)` · `scale(s, sx, sy)` | return the moved shape (applied in the order you call them) |
| `warn("…")` · `print("…")` | a message the person sees after the script ran |

`s.layer = 3;` puts a shape on a layer (0 is the first). Everything else of Rhai works: loops, `if`, functions, maps
`#{ a: 1 }`, arrays, strings, `sin cos sqrt …`, `PI()`. There is no file, network or system access, no `eval`, no
`import`. A script may run for 10 seconds, and make 200 000 shapes / 2 000 000 points at most.

## 4. Generators

A generator has a **form**: the `params` list in the manifest.

```json
"params": [
  { "id": "count",  "label": "Number of holes", "kind": "number", "default": 6, "min": 1, "max": 200, "unit": "" },
  { "id": "centre", "label": "Centre hole",     "kind": "bool",   "default": true },
  { "id": "label",  "label": "Text",            "kind": "text",   "default": "A" },
  { "id": "style",  "label": "Tooth shape",     "kind": "choice", "default": "square", "options": ["square", "round"] }
]
```

The script gets the values as `p.count`, `p.centre`, … Numbers are **floats** and already limited to `min`/`max`; use
`p.count.to_int()` for a loop. `id`s are letters, digits, `-`, `_`; avoid names that are Rhai keywords (`module`, `import`,
`private`, `fn`, `let`, …). Look at [`plugins/fractals`](../plugins/fractals) for a bigger generator.

```rhai
fn generate(p, ctx) {
    let out = [];
    for i in 0..p.count.to_int() {
        let a = 2.0 * PI() * i.to_float() / p.count;
        out.push(circle(ctx.area_w / 2.0 + 20.0 * cos(a), ctx.area_h / 2.0 + 20.0 * sin(a), 2.0));
    }
    out
}
```

## 5. Importers

An importer reads **one file type**. `extensions` lists them without the dot; the program offers the plugin for those
files in *Import with a plugin…*, in Open and on drag and drop. The script gets the file as text (bytes that are not
UTF-8 become `�`) and returns shapes. Put a small file in `tests/sample.<extension>` (see [`xy-points-importer`](../plugins/xy-points-importer)):
the checks of this repository run the importer on it.

## 6. Postprocessors

A postprocessor rewrites the G-code of **Export G-code…** (not the job that is sent straight to a machine). It gets the
lines and returns the lines.

What it may not do (the program refuses the whole result, and nothing is saved):

- lines that are commands of the controller itself: starting with `$`, `~`, `!`, `?`;
- control characters; lines longer than 240 characters.

A postprocessor that changes what the machine does (another way of spindle start, G-code dialect for another controller…)
must say so in its `description`.

## 7. Packs without code

- **Presets**: `class` is `mill`, `pen` or `laser`; `area` is X, Y, Z travel in mm (Z `0` for a plotter or laser); `rapid`
  in mm/min; `spindle_max` in S units. They appear in the *Start from* list when a device is added.
- **Clipart**: SVG files; they join the shared gallery once (same name + category are not added twice). Only add
  pictures you may share, and put the licence in the manifest.
- **Data**: files a program picks up by `kind`. MillCreator reads `mill-tools` (a bit library as `Export` writes it).
- **Texts**: see the manifest.

See [`templates/pack`](../templates/pack).

## 8. Testing

1. In the programs: copy the folder to the plugins folder, **Reload plugins**, try it. Errors of a script are shown in the
   window of the generator; `warn("…")` helps to see values.
2. The same check the CI runs, without a program (needs [Rust](https://rustup.rs) and a checkout of
   [baseCreator](https://github.com/michalsarna/baseCreator)):

   ```
   cd baseCreator
   cargo run -p base-core --example check_plugins -- /path/to/folder-with-your-plugin-folders
   ```

   It loads the manifests, runs every generator (with its start values and with every option of every choice), every
   postprocessor on a small program, and every importer on `tests/sample.<extension>`.
3. `python3 tools/build_site.py --out /tmp/site` builds the zips and `index.json` exactly as the CI does.

## 9. Rules and safety

- **No surprises.** A plugin does what its description says. No hidden behaviour.
- **No tricks against the sandbox.** Plugins that try to get around limits, or to send controller commands, are refused.
- **Licence.** Say it in `license`. Pictures, fonts and data must be yours or allowed to share.
- **Small.** Keep the files small and readable: they are reviewed by a person. No minified or generated code that cannot be
  read.
- **Be kind to machines.** Check your numbers: a generator that makes a 5 m shape for a 300 mm machine is a bug.
- **No personal data**, no links that track people.

## 10. Sending it to the official list

1. Fork this repository, add your folder to `plugins/` (named like the `id`), commit.
2. Open a pull request. The CI checks the manifest and runs your scripts. A person reads the scripts; expect questions.
3. When it is merged the list is rebuilt and the plugin appears in the programs after **Check for updates**.

Not ready to write code? Open an issue with the **Plugin idea** form.

## 11. Versions and updates

- Change anything in your folder → **raise `version`** in `plugin.json`. The CI refuses a pull request that changes the files
  of a plugin but not its version (what people installed would silently differ from what the list says).
- Write what changed in `CHANGELOG.md` in your folder (the top section is shown next to the Update button):

  ```
  # Changelog
  ## 1.1.0
  * Added the dragon curve.
  ```

- People see **Update available** when the list has a bigger version than the one installed.
- Never change the `id`. A different `id` is a different plugin.

## 12. Rhai pitfalls

- `s.trim()`, `s.to_upper()`, … **change the string itself** and return nothing: `let t = line; t.trim();`.
- Arrays, maps and strings are **values**: a function gets a copy. Return what you build (`out += more_shapes(...)`).
- Loops give copies: to change an element, use the index: `for i in 0..shapes.len() { shapes[i].layer = 2; }`.
- Whole numbers and floats are different types: `1 / 2` is `0`, `1.0 / 2.0` is `0.5`. Use `.to_float()` / `.to_int()`.
- Some names are reserved (`import`, `module`, `private`, `fn`, `let`, `const`, `switch`, `this`, …), also as parameter ids.
- `x in map` tests for a key; `if "points" in shape { … }`.
