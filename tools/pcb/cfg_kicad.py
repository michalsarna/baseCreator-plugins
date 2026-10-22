build("pcb-kicad", "Circuit board: KiCad",
 "Reads a KiCad board (.kicad_pcb, KiCad 5 to 8): the board outline, copper (tracks, pads, vias, filled zones), drill holes and the silkscreen, each part ticked in the form. For isolation milling, laser engraving of a resist or plotting of the traces.",
 "kicad-pcb", "KiCad board (.kicad_pcb)", ["kicad_pcb"], "kicad.rhai",
 common_params("Board corner to the top left", [
   {"id": "outline", "label": "Board outline (Edge.Cuts)", "kind": "bool", "default": True},
   {"id": "copper_top", "label": "Copper on top", "kind": "bool", "default": True},
   {"id": "copper_bottom", "label": "Copper on the bottom", "kind": "bool", "default": False},
   {"id": "holes", "label": "Drill holes", "kind": "bool", "default": True},
   {"id": "legend_top", "label": "Legend on top", "kind": "bool", "default": False},
   {"id": "legend_bottom", "label": "Legend on the bottom", "kind": "bool", "default": False}]),
 {"Circuit board: KiCad": "Płytka drukowana: KiCad",
  "KiCad board (.kicad_pcb)": "Płytka KiCad (.kicad_pcb)",
  "Reads a KiCad board (.kicad_pcb, KiCad 5 to 8): the board outline, copper (tracks, pads, vias, filled zones), drill holes and the silkscreen, each part ticked in the form. For isolation milling, laser engraving of a resist or plotting of the traces.":
  "Czyta płytkę z KiCada (.kicad_pcb, KiCad 5 do 8): obrys płytki, miedź (ścieżki, pady, przelotki, wypełnione obszary), otwory i sitodruk — każdą część zaznaczasz w formularzu. Do frezowania izolacji, wypalania maski laserem lub rysowania ścieżek."},
 "// Circuit board: a KiCad board file. See README.md.", min_base="1.15.0")
