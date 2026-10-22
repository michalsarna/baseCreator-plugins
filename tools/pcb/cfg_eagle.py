build("pcb-eagle", "Circuit board: EAGLE",
 "Reads an EAGLE or Fusion Electronics board (.brd, XML): the board outline (Dimension layer), copper (wires, pads, SMD pads, vias), drill holes and the silkscreen, each part ticked in the form. Copper pours are left out. For isolation milling, laser engraving of a resist or plotting of the traces.",
 "eagle-brd", "EAGLE board (.brd)", ["brd"], "eagle.rhai",
 common_params("Board corner to the top left", [
   {"id": "outline", "label": "Board outline (Dimension)", "kind": "bool", "default": True},
   {"id": "copper_top", "label": "Copper on top", "kind": "bool", "default": True},
   {"id": "copper_bottom", "label": "Copper on the bottom", "kind": "bool", "default": False},
   {"id": "holes", "label": "Drill holes", "kind": "bool", "default": True},
   {"id": "legend_top", "label": "Legend on top", "kind": "bool", "default": False},
   {"id": "legend_bottom", "label": "Legend on the bottom", "kind": "bool", "default": False}]),
 {"Circuit board: EAGLE": "Płytka drukowana: EAGLE",
  "EAGLE board (.brd)": "Płytka EAGLE (.brd)",
  "Reads an EAGLE or Fusion Electronics board (.brd, XML): the board outline (Dimension layer), copper (wires, pads, SMD pads, vias), drill holes and the silkscreen, each part ticked in the form. Copper pours are left out. For isolation milling, laser engraving of a resist or plotting of the traces.":
  "Czyta płytkę z EAGLE lub Fusion Electronics (.brd, XML): obrys płytki (warstwa Dimension), miedź (ścieżki, pady, pady SMD, przelotki), otwory i sitodruk — każdą część zaznaczasz w formularzu. Wylewki miedzi są pomijane. Do frezowania izolacji, wypalania maski laserem lub rysowania ścieżek."},
 "// Circuit board: an EAGLE board file. See README.md.")
