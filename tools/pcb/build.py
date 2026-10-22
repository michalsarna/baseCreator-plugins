#!/usr/bin/env python3
"""Builds plugins/pcb-*/: plugin.json from the shared form, read.rhai = header + common.rhai + the reader of the format.

The four circuit board plugins share one text (common.rhai: the pieces, the arcs, the outline chaining, the mirror, the origin,
the isolation and the shapes) because a plugin cannot import another. Change the shared part here and run
`python3 tools/pcb/build.py gerber kicad eagle easyeda`; do not edit the read.rhai of a plugin by hand.
"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "plugins"))

PL = {
 "Mirror (a bottom layer seen from the top)": "Odbicie lustrzane (warstwa spodnia widziana od góry)",
 "Origin": "Początek układu",
 "As in the file": "Jak w pliku",
 "Board corner to the top left": "Narożnik płytki w lewym górnym rogu",
 "Copper drawn as": "Miedź rysowana jako",
 "Centre lines": "Linie środkowe",
 "Outlines grown by the isolation": "Kontury powiększone o izolację",
 "Isolation": "Izolacja",
 "Holes drawn as": "Otwory rysowane jako",
 "Circles of the real size": "Okręgi w prawdziwym rozmiarze",
 "Small circles at the centres": "Małe okręgi w środkach",
 "Layer of the board outline": "Warstwa obrysu płytki",
 "Layer of the copper": "Warstwa miedzi",
 "Layer of the drill holes": "Warstwa otworów",
 "Layer of the legend": "Warstwa opisu (sitodruk)",
 "Layer of the pads": "Warstwa padów",
 "What the file is": "Czym jest plik",
 "Detect from the file": "Rozpoznaj z pliku",
 "Copper": "Miedź",
 "Board outline": "Obrys płytki",
 "Legend (silkscreen)": "Opis (sitodruk)",
 "Board outline (Edge.Cuts)": "Obrys płytki (Edge.Cuts)",
 "Copper on top": "Miedź na wierzchu",
 "Copper on the bottom": "Miedź na spodzie",
 "Drill holes": "Otwory wiercone",
 "Legend on top": "Opis na wierzchu",
 "Legend on the bottom": "Opis na spodzie",
 "Board outline (Dimension)": "Obrys płytki (Dimension)",
}

def common_params(origin_default, extra_first=None, layers=True):
    ps = list(extra_first or [])
    ps += [
     {"id": "mirror", "label": "Mirror (a bottom layer seen from the top)", "kind": "bool", "default": False},
     {"id": "origin", "label": "Origin", "kind": "choice", "default": origin_default, "options": ["As in the file", "Board corner to the top left"]},
     {"id": "mode", "label": "Copper drawn as", "kind": "choice", "default": "Outlines grown by the isolation", "options": ["Centre lines", "Outlines grown by the isolation"]},
     {"id": "isolation", "label": "Isolation", "kind": "number", "default": 0.2, "min": 0, "max": 5, "unit": "mm"},
     {"id": "holes_as", "label": "Holes drawn as", "kind": "choice", "default": "Circles of the real size", "options": ["Circles of the real size", "Small circles at the centres"]},
    ]
    if layers:
        ps += [
         {"id": "layer_outline", "label": "Layer of the board outline", "kind": "number", "default": 0, "min": 0, "max": 20, "unit": ""},
         {"id": "layer_copper", "label": "Layer of the copper", "kind": "number", "default": 1, "min": 0, "max": 20, "unit": ""},
         {"id": "layer_holes", "label": "Layer of the drill holes", "kind": "number", "default": 2, "min": 0, "max": 20, "unit": ""},
         {"id": "layer_legend", "label": "Layer of the legend", "kind": "number", "default": 3, "min": 0, "max": 20, "unit": ""},
        ]
    return ps

def build(pid, name, desc, imp_id, imp_name, exts, reader, params, extra_pl, header, version="1.0.0", imp_desc=None, min_base="1.6.0"):
    d = os.path.join(OUT, pid)
    os.makedirs(os.path.join(d, "tests"), exist_ok=True)
    texts = dict(PL)
    texts.update(extra_pl)
    used = set()
    def use(s):
        if s in texts: used.add(s)
    use(name); use(desc); use(imp_name)
    for p in params:
        use(p["label"])
        for o in p.get("options", []): use(o)
    imp = {"id": imp_id, "name": imp_name, "extensions": exts, "script": "read.rhai", "params": params}
    if imp_desc:
        imp["description"] = imp_desc; use(imp_desc)
    m = {"format": 1, "id": pid, "name": name, "version": version, "min_base": min_base, "author": "Michał Sarna",
         "license": "MIT OR Apache-2.0", "description": desc, "importers": [imp],
         "texts": {"pl": {k: texts[k] for k in texts if k in used}}}
    json.dump(m, open(os.path.join(d, "plugin.json"), "w"), indent=2, ensure_ascii=False)
    open(os.path.join(d, "plugin.json"), "a").write("\n")
    common = open(os.path.join(HERE, "common.rhai")).read()
    body = open(os.path.join(HERE, reader)).read()
    open(os.path.join(d, "read.rhai"), "w").write(header + "\n\n" + common + "\n" + body)
    return d

if __name__ == "__main__":
    which = sys.argv[1:] or ["gerber"]
    for w in which:
        exec(open(os.path.join(HERE, "cfg_" + w + ".py")).read())
