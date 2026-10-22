// Circuit board: a KiCad board file. See README.md.

// ---- Shared part of the circuit board plugins (the same text is in every pcb-* plugin) ----------------------------------------
// The reader of a format turns the file into a list of "pieces" in millimetres, Y up (the way a board is drawn):
//   m_trace(kind, points, width)   a line with a width        m_poly(kind, points)   a filled closed outline (pad, region)
//   m_disc(kind, x, y, r)          a filled circle            m_hole(x, y, diameter) a drill hole
// where kind is "copper", "outline" or "legend". finish() mirrors, moves and draws them as shapes.

// A piece is an array whose points are one text "x,y x,y ..." (the sandbox of the scripts looks through a whole array each time
// something is pushed to it, so a long list of arrays of points would get slow; a text counts as one item):
//   ["T", kind, points, width]   ["P", kind, points]   ["D", kind, x, y, r]   ["H", "hole", x, y, diameter]
fn enc(pts) {
    let s = "";
    for q in pts { s += q[0].to_string() + "," + q[1].to_string() + " "; }
    s
}

fn dec(s) {
    let out = [];
    for w in s.split(' ') {
        if w == "" { continue; }
        let xy = w.split(',');
        out.push([parse_float(xy[0]), parse_float(xy[1])]);
    }
    out
}

fn m_trace(kind, pts, w) { ["T", kind, enc(pts), w] }
fn m_poly(kind, pts) { ["P", kind, enc(pts)] }
fn m_disc(kind, x, y, r) { ["D", kind, x, y, r] }
fn m_hole(x, y, d) { ["H", "hole", x, y, d] }

fn rot_pt(x, y, deg) {
    let a = deg * PI() / 180.0;
    [x * cos(a) - y * sin(a), x * sin(a) + y * cos(a)]
}

fn rot_all(pts, deg) {
    if deg == 0.0 { return pts; }
    let out = [];
    for q in pts { out.push(rot_pt(q[0], q[1], deg)); }
    out
}

fn rect_pts(cx, cy, w, h) {
    [[cx - w / 2.0, cy - h / 2.0], [cx + w / 2.0, cy - h / 2.0], [cx + w / 2.0, cy + h / 2.0], [cx - w / 2.0, cy + h / 2.0]]
}

fn rrect_pts(w, h, r) {
    let out = [];
    let cx = [w / 2.0 - r, -(w / 2.0 - r), -(w / 2.0 - r), w / 2.0 - r];
    let cy = [h / 2.0 - r, h / 2.0 - r, -(h / 2.0 - r), -(h / 2.0 - r)];
    for k in 0..4 {
        for s in 0..7 {
            // corner k covers the angles of the quadrant that points at it: 0 = top right, 1 = top left, 2 = bottom left, 3 = bottom right
            let q = (k.to_float() * 90.0 + 90.0 * s.to_float() / 6.0) * PI() / 180.0;
            out.push([cx[k] + r * cos(q), cy[k] + r * sin(q)]);
        }
    }
    out
}

// Points of an arc from the angle a0 turning by sweep radians (positive = counter-clockwise, Y up); both ends are included.
fn arc_points(cx, cy, r, a0, sweep) {
    let step = PI() / 12.0;
    if r > 0.05 {
        let c = 1.0 - 0.02 / r;
        if c < 0.0 { c = 0.0; }
        step = 2.0 * acos(c);
        if step > PI() / 12.0 { step = PI() / 12.0; }
        if step < PI() / 90.0 { step = PI() / 90.0; }
    }
    let n = (abs(sweep) / step).ceiling().to_int();
    if n < 1 { n = 1; }
    let out = [];
    for i in 0..(n + 1) {
        let a = a0 + sweep * i.to_float() / n.to_float();
        out.push([cx + r * cos(a), cy + r * sin(a)]);
    }
    out
}

fn wrap_pos(a) {
    let t = 2.0 * PI();
    while a < 0.0 { a += t; }
    while a >= t { a -= t; }
    a
}

// An arc through three points (start, a point on it, end), Y up. Falls back to a straight line when they lie on a line.
fn arc_3pt(a, m, b) {
    let d = 2.0 * (a[0] * (m[1] - b[1]) + m[0] * (b[1] - a[1]) + b[0] * (a[1] - m[1]));
    if abs(d) < 0.000001 { return [a, b]; }
    let a2 = a[0] * a[0] + a[1] * a[1];
    let m2 = m[0] * m[0] + m[1] * m[1];
    let b2 = b[0] * b[0] + b[1] * b[1];
    let cx = (a2 * (m[1] - b[1]) + m2 * (b[1] - a[1]) + b2 * (a[1] - m[1])) / d;
    let cy = (a2 * (b[0] - m[0]) + m2 * (a[0] - b[0]) + b2 * (m[0] - a[0])) / d;
    let r = sqrt((a[0] - cx) * (a[0] - cx) + (a[1] - cy) * (a[1] - cy));
    let a0 = atan(a[1] - cy, a[0] - cx);
    let am = atan(m[1] - cy, m[0] - cx);
    let a1 = atan(b[1] - cy, b[0] - cx);
    let ccw = wrap_pos(a1 - a0);
    let mid = wrap_pos(am - a0);
    let sweep = if mid <= ccw { ccw } else { ccw - 2.0 * PI() };
    arc_points(cx, cy, r, a0, sweep)
}

// An arc from the centre, the start point and the angle in degrees (positive = counter-clockwise, Y up).
fn arc_centre(cx, cy, sx, sy, deg) {
    let r = sqrt((sx - cx) * (sx - cx) + (sy - cy) * (sy - cy));
    arc_points(cx, cy, r, atan(sy - cy, sx - cx), deg * PI() / 180.0)
}

fn circle_pts(cx, cy, r) {
    let out = [];
    for i in 0..24 {
        let a = 2.0 * PI() * i.to_float() / 24.0;
        out.push([cx + r * cos(a), cy + r * sin(a)]);
    }
    out
}

// The outline of a segment with round ends and the width w.
fn capsule(a, b, w) {
    let r = w / 2.0;
    let dx = b[0] - a[0];
    let dy = b[1] - a[1];
    if dx * dx + dy * dy < 0.000001 { return circle_pts(a[0], a[1], r); }
    let t = atan(dy, dx);
    let out = [];
    for i in 0..5 {
        let q = t - PI() / 2.0 + PI() * i.to_float() / 4.0;
        out.push([b[0] + r * cos(q), b[1] + r * sin(q)]);
    }
    for i in 0..5 {
        let q = t + PI() / 2.0 + PI() * i.to_float() / 4.0;
        out.push([a[0] + r * cos(q), a[1] + r * sin(q)]);
    }
    out
}

// Chains lines that share their ends into longer ones; a chain whose ends meet is closed (the last point is dropped).
fn chain_key(p) { "" + (p[0] * 100.0).round().to_int() + "," + (p[1] * 100.0).round().to_int() }

fn chain(lines) {
    let used = [];
    let ends = #{};
    for i in 0..lines.len() {
        used.push(false);
        let ps = lines[i];
        for k in [chain_key(ps[0]), chain_key(ps[ps.len() - 1])] {
            if ends[k] == () { ends[k] = []; }
            ends[k].push(i);
        }
    }
    let out = [];
    for i in 0..lines.len() {
        if used[i] { continue; }
        used[i] = true;
        let cur = lines[i];
        let again = true;
        while again {
            again = false;
            let k = chain_key(cur[cur.len() - 1]);
            let cand = ends[k];
            if cand != () {
                for j in cand {
                    if used[j] { continue; }
                    let ps = lines[j];
                    used[j] = true;
                    if chain_key(ps[0]) == k {
                        for q in 1..ps.len() { cur.push(ps[q]); }
                    } else {
                        for q in 1..ps.len() { cur.push(ps[ps.len() - 1 - q]); }
                    }
                    again = true;
                    break;
                }
            }
        }
        out.push(cur);
    }
    out
}

fn bbox_of(prims) {
    let b = [1.0e30, 1.0e30, -1.0e30, -1.0e30];
    for pr in prims {
        let pts = [];
        if pr[0] == "T" || pr[0] == "P" {
            pts = dec(pr[2]);
        } else if pr[0] == "D" {
            pts = [[pr[2] - pr[4], pr[3] - pr[4]], [pr[2] + pr[4], pr[3] + pr[4]]];
        } else {
            pts = [[pr[2], pr[3]]];
        }
        for q in pts {
            if q[0] < b[0] { b[0] = q[0]; }
            if q[1] < b[1] { b[1] = q[1]; }
            if q[0] > b[2] { b[2] = q[0]; }
            if q[1] > b[3] { b[3] = q[1]; }
        }
    }
    b
}

fn tpt(q, c) {
    let x = if c.mir { c.sx - q[0] } else { q[0] };
    [x - c.dx, c.top - q[1]]
}

fn tpts(pts, c) {
    let out = [];
    for q in pts { out.push(tpt(q, c)); }
    out
}

// A filled piece as the outlines it covers, grown by iso on every side.
fn filled_polys(pr, c, iso) {
    let out = [];
    if pr[0] == "T" {
        let pts = tpts(dec(pr[2]), c);
        if pts.len() == 1 { out.push(circle_pts(pts[0][0], pts[0][1], pr[3] / 2.0 + iso)); }
        for i in 1..pts.len() { out.push(capsule(pts[i - 1], pts[i], pr[3] + 2.0 * iso)); }
    } else if pr[0] == "D" {
        let q = tpt([pr[2], pr[3]], c);
        out.push(circle_pts(q[0], q[1], pr[4] + iso));
    } else if pr[0] == "P" {
        let pts = tpts(dec(pr[2]), c);
        out.push(pts);
        if iso > 0.0 {
            for i in 0..pts.len() { out.push(capsule(pts[i], pts[(i + 1) % pts.len()], 2.0 * iso)); }
        }
    }
    out
}

fn param_layer(p, id, fallback) {
    let v = p[id];
    if v == () { fallback } else { v.to_int() }
}

// Contours [points, closed] -> shapes. Up to 300 are shapes of their own; more become compound paths of about 3000 points each
// (a script may return only a few thousand shapes).
fn contour_shapes(contours, layer) {
    let out = [];
    if contours.len() <= 300 {
        for ct in contours {
            let s = if ct[1] { polygon(ct[0]) } else { polyline(ct[0]) };
            s.layer = layer;
            out.push(s);
        }
        return out;
    }
    let segs = [];
    let n = 0;
    for ct in contours {
        let pts = ct[0];
        for i in 0..pts.len() {
            segs.push([if i == 0 { "M" } else { "L" }, pts[i][0], pts[i][1]]);
        }
        if ct[1] { segs.push(["Z"]); }
        n += pts.len();
        if n >= 3000 {
            let s = path(segs);
            s.layer = layer;
            out.push(s);
            segs = [];
            n = 0;
        }
    }
    if segs.len() > 0 {
        let s = path(segs);
        s.layer = layer;
        out.push(s);
    }
    out
}

// Merges the outlines of many pieces (in batches: the union of everything at once would be too much for a script).
fn merged(polys) {
    let acc = [];
    let buf = [];
    let batches = 0;
    for q in polys {
        buf.push(q);
        if buf.len() >= 300 {
            for r in union_polygons(buf) { acc.push(r); }
            buf = [];
            batches += 1;
        }
    }
    if buf.len() > 0 {
        for r in union_polygons(buf) { acc.push(r); }
        batches += 1;
    }
    if batches > 1 { acc = union_polygons(acc); }
    acc
}

fn kind_count(prims, kind) {
    let n = 0;
    for pr in prims { if pr[1] == kind { n += 1; } }
    n
}

// pieces -> shapes. p is the form: mirror, origin, mode, isolation, holes_as and the four layers.
fn finish(prims, p, ctx) {
    let ref_pieces = [];
    for pr in prims { if pr[1] == "outline" { ref_pieces.push(pr); } }
    if ref_pieces.len() == 0 { ref_pieces = prims; }
    if prims.len() == 0 {
        warn("nothing to draw: the file has none of the ticked parts");
        return [];
    }
    let b = bbox_of(ref_pieces);
    let corner = p.origin == "Board corner to the top left";
    let c = #{ mir: p.mirror == true, sx: b[0] + b[2], dx: if corner { b[0] } else { 0.0 }, top: if corner { b[3] } else { ctx.area_h } };
    let l_out = param_layer(p, "layer_outline", 0);
    let l_cu = param_layer(p, "layer_copper", 1);
    let l_hole = param_layer(p, "layer_holes", 2);
    let l_leg = param_layer(p, "layer_legend", 3);
    let iso = if p.isolation == () { 0.0 } else { p.isolation };
    let outlined = p.mode == "Outlines grown by the isolation";
    let out = [];

    // board outline: lines are chained into closed contours
    let lines = [];
    for pr in prims {
        if pr[1] != "outline" { continue; }
        if pr[0] == "T" {
            lines.push(tpts(dec(pr[2]), c));
        } else if pr[0] == "D" {
            let q = tpt([pr[2], pr[3]], c);
            let s = circle(q[0], q[1], pr[4]);
            s.layer = l_out;
            out.push(s);
        } else if pr[0] == "P" {
            let pts = dec(pr[2]);
            pts.push(pts[0]);
            lines.push(tpts(pts, c));
        }
    }
    let contours = [];
    for pts in chain(lines) {
        let closed = pts.len() >= 4 && chain_key(pts[0]) == chain_key(pts[pts.len() - 1]);
        if closed { pts.pop(); }
        contours.push([pts, closed]);
    }
    for s in contour_shapes(contours, l_out) { out.push(s); }

    // copper and legend
    for kind in ["copper", "legend"] {
        let layer = if kind == "copper" { l_cu } else { l_leg };
        let grow = if kind == "copper" { iso } else { 0.0 };
        if kind_count(prims, kind) == 0 { continue; }
        let cts = [];
        if outlined {
            let polys = [];
            for pr in prims {
                if pr[1] != kind { continue; }
                for q in filled_polys(pr, c, grow) { polys.push(q); }
            }
            try {
                for r in merged(polys) { cts.push([r, true]); }
            } catch {
                warn("this board is too big to merge into outlines: draw the copper as centre lines instead");
                return out;
            }
        } else {
            for pr in prims {
                if pr[1] != kind { continue; }
                if pr[0] == "T" {
                    let pts = tpts(dec(pr[2]), c);
                    if pts.len() >= 2 { cts.push([pts, false]); }
                } else if pr[0] == "D" {
                    let q = tpt([pr[2], pr[3]], c);
                    cts.push([circle_pts(q[0], q[1], pr[4]), true]);
                } else {
                    cts.push([tpts(dec(pr[2]), c), true]);
                }
            }
        }
        for s in contour_shapes(cts, layer) { out.push(s); }
    }

    // drill holes
    let small = p.holes_as == "Small circles at the centres";
    let holes = [];
    for pr in prims {
        if pr[0] != "H" { continue; }
        let q = tpt([pr[2], pr[3]], c);
        holes.push([q[0], q[1], if small { 0.1 } else { pr[4] }]);
    }
    if holes.len() <= 300 {
        for h in holes {
            let s = circle(h[0], h[1], h[2] / 2.0);
            s.layer = l_hole;
            out.push(s);
        }
    } else {
        let cts = [];
        for h in holes { cts.push([circle_pts(h[0], h[1], h[2] / 2.0), true]); }
        for s in contour_shapes(cts, l_hole) { out.push(s); }
    }
    out
}

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
