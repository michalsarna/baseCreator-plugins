build("pcb-gerber", "Circuit board: Gerber and Excellon",
 "Reads the files a circuit board program writes for a manufacturer: Gerber layers (copper, board outline, legend) and Excellon drill files. One file is one layer; use it once for each layer you need. Works for KiCad, EAGLE, Altium, EasyEDA, Fritzing, DipTrace, Proteus and every other program that can plot Gerber.",
 "gerber", "Gerber / Excellon (circuit board layer)",
 ["gbr", "ger", "gtl", "gbl", "gts", "gbs", "gto", "gbo", "gtp", "gbp", "gko", "gm1", "gml", "g1", "g2", "drl", "xln", "exc", "drd"],
 "gerber.rhai",
 common_params("As in the file", [{"id": "role", "label": "What the file is", "kind": "choice", "default": "Detect from the file", "options": ["Detect from the file", "Copper", "Board outline", "Legend (silkscreen)"]}]),
 {"Circuit board: Gerber and Excellon": "Płytka drukowana: Gerber i Excellon",
  "Gerber / Excellon (circuit board layer)": "Gerber / Excellon (warstwa płytki)",
  "Reads the files a circuit board program writes for a manufacturer: Gerber layers (copper, board outline, legend) and Excellon drill files. One file is one layer; use it once for each layer you need. Works for KiCad, EAGLE, Altium, EasyEDA, Fritzing, DipTrace, Proteus and every other program that can plot Gerber.":
  "Czyta pliki, które program do płytek drukowanych zapisuje dla producenta: warstwy Gerber (miedź, obrys płytki, opis) i pliki wierceń Excellon. Jeden plik to jedna warstwa; użyj wtyczki osobno dla każdej potrzebnej warstwy. Działa z KiCadem, EAGLE, Altium, EasyEDA, Fritzing, DipTrace, Proteusem i każdym programem, który zapisuje Gerbery."},
 "// Circuit board layers: Gerber (RS-274X, X2) and Excellon files. See README.md.")
