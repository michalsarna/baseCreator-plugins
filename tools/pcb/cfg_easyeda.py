build("pcb-easyeda", "Circuit board: EasyEDA",
 "Reads an EasyEDA (Standard edition) PCB document saved as .json: the board outline, copper (tracks, pads, vias, solid regions), drill holes and the silkscreen, each part ticked in the form. Copper areas (pours) are left out.",
 "easyeda-json", "EasyEDA PCB (.json)", ["json"], "easyeda.rhai",
 common_params("Board corner to the top left", [
   {"id": "outline", "label": "Board outline", "kind": "bool", "default": True},
   {"id": "copper_top", "label": "Copper on top", "kind": "bool", "default": True},
   {"id": "copper_bottom", "label": "Copper on the bottom", "kind": "bool", "default": False},
   {"id": "holes", "label": "Drill holes", "kind": "bool", "default": True},
   {"id": "legend_top", "label": "Legend on top", "kind": "bool", "default": False},
   {"id": "legend_bottom", "label": "Legend on the bottom", "kind": "bool", "default": False}]),
 {"Circuit board: EasyEDA": "Płytka drukowana: EasyEDA",
  "EasyEDA PCB (.json)": "Płytka EasyEDA (.json)",
  "Board outline": "Obrys płytki",
  "Reads an EasyEDA (Standard edition) PCB document saved as .json: the board outline, copper (tracks, pads, vias, solid regions), drill holes and the silkscreen, each part ticked in the form. Copper areas (pours) are left out.":
  "Czyta dokument płytki z EasyEDA (wersja Standard) zapisany jako .json: obrys płytki, miedź (ścieżki, pady, przelotki, pełne regiony), otwory i sitodruk — każdą część zaznaczasz w formularzu. Obszary miedzi (wylewki) są pomijane."},
 "// Circuit board: an EasyEDA (Standard) PCB document. See README.md.")
