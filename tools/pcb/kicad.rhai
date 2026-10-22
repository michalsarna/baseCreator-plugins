// ---- KiCad board (.kicad_pcb, S-expressions; KiCad 5 to 8) -------------------------------------------------------------------
// Read: lines, arcs, circles, rectangles and polygons on Edge.Cuts and the silkscreen layers (also inside footprints), copper
// tracks (segment, arc), vias, filled zones, pads (circle, rectangle, oval, rounded rectangle; a trapezoid and a custom pad as a
// rectangle) and their drill holes. Not read: text, inner copper layers, the unfilled outline of a zone, slots of oval drills.
// The file is turned into a flat list of tokens; a form is the slice of tokens from its "(" to its ")".

// Splits the file into tokens in one go: the text in quotes is made one word first (spaces and brackets inside it are hidden).
fn tokenize(text) {
    let parts = text.split('"');
    let all = "";
    for i in 0..parts.len() {
        let s = parts[i];
        if i % 2 == 1 {
            s.replace(" ", "\x01");
            s.replace("(", "\x02");
            s.replace(")", "\x03");
            all += " \"" + s + " ";
        } else {
            s.replace("(", " ( ");
            s.replace(")", " ) ");
            all += s;
        }
    }
    all.split()
}

fn atom(k) {
    if !k.starts_with("\"") { return k; }
    let s = k.sub_string(1);
    s.replace("\x01", " ");
    s.replace("\x02", "(");
    s.replace("\x03", ")");
    s
}

// The forms directly inside a form.
fn kids(t) {
    let out = [];
    let depth = 0;
    let start = 0;
    for i in 1..(t.len() - 1) {
        let k = t[i];
        if k == "(" {
            if depth == 0 { start = i; }
            depth += 1;
        } else if k == ")" {
            depth -= 1;
            if depth == 0 { out.push(t.extract(start, i - start + 1)); }
        }
    }
    out
}

// The plain values directly inside a form (after its name).
fn args(t) {
    let out = [];
    let depth = 0;
    for i in 2..(t.len() - 1) {
        let k = t[i];
        if k == "(" { depth += 1; }
        else if k == ")" { depth -= 1; }
        else if depth == 0 { out.push(atom(k)); }
    }
    out
}

fn find(forms, name) {
    for f in forms { if f.len() > 1 && f[1] == name { return f; } }
    ()
}

fn xy_of(f) {
    let a = args(f);
    [parse_float(a[0]), -parse_float(a[1])]
}

fn place(q, xf) {
    let r = rot_pt(q[0], q[1], xf.a);
    [r[0] + xf.x, r[1] + xf.y]
}

fn width_of(ks) {
    let w = find(ks, "width");
    if w != () { return parse_float(args(w)[0]); }
    let st = find(ks, "stroke");
    if st != () {
        let w2 = find(kids(st), "width");
        if w2 != () { return parse_float(args(w2)[0]); }
    }
    0.1
}

fn layer_of(ks) {
    let l = find(ks, "layer");
    if l == () { "" } else { args(l)[0] }
}

fn layer_kind(l, p) {
    if l == "Edge.Cuts" { return if p.outline { "outline" } else { "" }; }
    if l == "F.Cu" { return if p.copper_top { "copper" } else { "" }; }
    if l == "B.Cu" { return if p.copper_bottom { "copper" } else { "" }; }
    if l == "F.SilkS" || l == "F.Silkscreen" { return if p.legend_top { "legend" } else { "" }; }
    if l == "B.SilkS" || l == "B.Silkscreen" { return if p.legend_bottom { "legend" } else { "" }; }
    ""
}

fn pts_of(f, xf) {
    let out = [];
    for q in kids(f) {
        if q[1] == "xy" { out.push(place(xy_of(q), xf)); }
    }
    out
}

// Graphic items (gr_* on the board, fp_* in a footprint) of the kinds line, rect, circle, arc and poly.
fn graphic(f, shape, xf, p) {
    let ks = kids(f);
    let kind = layer_kind(layer_of(ks), p);
    if kind == "" { return []; }
    let w = width_of(ks);
    if shape == "line" {
        return [m_trace(kind, [place(xy_of(find(ks, "start")), xf), place(xy_of(find(ks, "end")), xf)], w)];
    }
    if shape == "rect" {
        let a = xy_of(find(ks, "start"));
        let b = xy_of(find(ks, "end"));
        let pts = [place(a, xf), place([b[0], a[1]], xf), place(b, xf), place([a[0], b[1]], xf)];
        pts.push(pts[0]);
        return [m_trace(kind, pts, w)];
    }
    if shape == "circle" {
        let c = xy_of(find(ks, "center"));
        let e = xy_of(find(ks, "end"));
        let r = sqrt((e[0] - c[0]) * (e[0] - c[0]) + (e[1] - c[1]) * (e[1] - c[1]));
        let pts = [];
        for q in circle_pts(c[0], c[1], r) { pts.push(place(q, xf)); }
        pts.push(pts[0]);
        return [m_trace(kind, pts, w)];
    }
    if shape == "arc" {
        let mid = find(ks, "mid");
        if mid != () {
            return [m_trace(kind, arc_3pt(place(xy_of(find(ks, "start")), xf), place(xy_of(mid), xf), place(xy_of(find(ks, "end")), xf)), w)];
        }
        // KiCad 5: start is the centre, end the first point, angle the sweep (clockwise on the screen when positive)
        let c = xy_of(find(ks, "start"));
        let e = xy_of(find(ks, "end"));
        let deg = parse_float(args(find(ks, "angle"))[0]);
        let pts = [];
        for q in arc_centre(c[0], c[1], e[0], e[1], -deg) { pts.push(place(q, xf)); }
        return [m_trace(kind, pts, w)];
    }
    if shape == "poly" {
        let pts = pts_of(find(ks, "pts"), xf);
        if pts.len() >= 2 { pts.push(pts[0]); return [m_trace(kind, pts, w)]; }
    }
    []
}

fn pad_shape(shape, w, h, ratio) {
    if shape == "oval" {
        if w >= h { return capsule([-(w - h) / 2.0, 0.0], [(w - h) / 2.0, 0.0], h); }
        return capsule([0.0, -(h - w) / 2.0], [0.0, (h - w) / 2.0], w);
    }
    if shape == "roundrect" {
        let m = if w < h { w } else { h };
        return rrect_pts(w, h, ratio * m);
    }
    rect_pts(0.0, 0.0, w, h)
}

fn pad_prims(f, xf, p) {
    let out = [];
    let a = args(f);
    if a.len() < 3 { return out; }
    let ks = kids(f);
    let at = args(find(ks, "at"));
    let c = place([parse_float(at[0]), -parse_float(at[1])], xf);
    let ang = if at.len() > 2 { parse_float(at[2]) } else { 0.0 };
    let sz = args(find(ks, "size"));
    let w = parse_float(sz[0]);
    let h = if sz.len() > 1 { parse_float(sz[1]) } else { w };
    let ly = find(ks, "layers");
    let top = false;
    let bottom = false;
    if ly != () {
        for l in args(ly) {
            if l == "F.Cu" || l == "*.Cu" { top = true; }
            if l == "B.Cu" || l == "*.Cu" { bottom = true; }
        }
    }
    let on = (top && p.copper_top) || (bottom && p.copper_bottom);
    if on && a[1] != "np_thru_hole" {
        if a[2] == "circle" {
            out.push(m_disc("copper", c[0], c[1], w / 2.0));
        } else {
            let rr = find(ks, "roundrect_rratio");
            let ratio = if rr != () { parse_float(args(rr)[0]) } else { 0.25 };
            let pts = [];
            for q in rot_all(pad_shape(a[2], w, h, ratio), ang) { pts.push([c[0] + q[0], c[1] + q[1]]); }
            out.push(m_poly("copper", pts));
        }
    }
    let dr = find(ks, "drill");
    if dr != () && p.holes {
        let d = args(dr);
        let dia = 0.0;
        if d[0] == "oval" { dia = if parse_float(d[1]) < parse_float(d[2]) { parse_float(d[1]) } else { parse_float(d[2]) }; }
        else { dia = parse_float(d[0]); }
        if dia > 0.0 { out.push(m_hole(c[0], c[1], dia)); }
    }
    out
}

fn footprint_prims(f, p) {
    let out = [];
    let ks = kids(f);
    let at = args(find(ks, "at"));
    let xf = #{ x: parse_float(at[0]), y: -parse_float(at[1]), a: if at.len() > 2 { parse_float(at[2]) } else { 0.0 } };
    for k in ks {
        let nm = k[1];
        if nm == "pad" {
            for q in pad_prims(k, xf, p) { out.push(q); }
        } else if nm.starts_with("fp_") && nm != "fp_text" && nm != "fp_text_box" && nm != "fp_curve" {
            for q in graphic(k, nm.sub_string(3), xf, p) { out.push(q); }
        }
    }
    out
}

fn zone_prims(f, p) {
    let out = [];
    let ks = kids(f);
    let zl = layer_of(ks);
    let filled = 0;
    for k in ks {
        if k[1] != "filled_polygon" { continue; }
        filled += 1;
        let kk = kids(k);
        let l = layer_of(kk);
        let kind = layer_kind(if l == "" { zl } else { l }, p);
        if kind == "" { continue; }
        let pts = pts_of(find(kk, "pts"), #{ x: 0.0, y: 0.0, a: 0.0 });
        if pts.len() >= 3 { out.push(m_poly(kind, pts)); }
    }
    if filled == 0 && layer_kind(zl, p) == "copper" { warn("a copper zone that is not filled is left out (fill the zones in KiCad and save the board)"); }
    out
}

fn item_prims(it, p) {
    let out = [];
    let none = #{ x: 0.0, y: 0.0, a: 0.0 };
    let nm = it[1];
    if nm == "footprint" || nm == "module" {
        for q in footprint_prims(it, p) { out.push(q); }
    } else if nm.starts_with("gr_") && nm != "gr_text" && nm != "gr_text_box" && nm != "gr_curve" {
        for q in graphic(it, nm.sub_string(3), none, p) { out.push(q); }
    } else if nm == "segment" || nm == "arc" {
        let ks = kids(it);
        let kind = layer_kind(layer_of(ks), p);
        if kind == "copper" {
            let w = width_of(ks);
            let pts = if nm == "arc" { arc_3pt(xy_of(find(ks, "start")), xy_of(find(ks, "mid")), xy_of(find(ks, "end"))) } else { [xy_of(find(ks, "start")), xy_of(find(ks, "end"))] };
            out.push(m_trace("copper", pts, w));
        }
    } else if nm == "via" {
        let ks = kids(it);
        let c = xy_of(find(ks, "at"));
        let size = parse_float(args(find(ks, "size"))[0]);
        let ly = find(ks, "layers");
        let top = false;
        let bottom = false;
        if ly != () { for l in args(ly) { if l == "F.Cu" { top = true; } if l == "B.Cu" { bottom = true; } } }
        if (top && p.copper_top) || (bottom && p.copper_bottom) { out.push(m_disc("copper", c[0], c[1], size / 2.0)); }
        let dr = find(ks, "drill");
        if dr != () && p.holes { out.push(m_hole(c[0], c[1], parse_float(args(dr)[0]))); }
    } else if nm == "zone" {
        for q in zone_prims(it, p) { out.push(q); }
    }
    out
}

// The items of the board are taken one by one (a list of all of them would be slow to build).
fn read(text, ctx) {
    let p = ctx.p;
    let t = tokenize(text);
    let prims = [];
    let depth = 0;
    let start = 0;
    for i in 1..(t.len() - 1) {
        let k = t[i];
        if k == "(" {
            if depth == 0 { start = i; }
            depth += 1;
        } else if k == ")" {
            depth -= 1;
            if depth == 0 { for q in item_prims(t.extract(start, i - start + 1), p) { prims.push(q); } }
        }
    }
    finish(prims, p, ctx)
}
