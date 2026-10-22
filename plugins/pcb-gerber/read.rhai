// Circuit board layers: Gerber (RS-274X, X2) and Excellon files. See README.md.

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

// ---- Gerber (RS-274X, X2) and Excellon drill files ---------------------------------------------------------------------------
// One file is one layer: the copper, the board outline or the legend (the role comes from the X2 attribute of the file or from
// the form) or a drill file. Not read: clear polarity (LPC), step and repeat (SR), aperture transformations (LM LR LS), apertures
// with holes (the hole is left out), thermal and moire macro primitives.

fn scan(cmd) {
    let m = #{};
    let gs = [];
    let key = "";
    let val = "";
    for ch in cmd.chars() {
        if ch == 'X' || ch == 'Y' || ch == 'I' || ch == 'J' || ch == 'D' || ch == 'G' || ch == 'M' || ch == 'N' {
            if key == "G" { gs.push(val); } else if key != "" { m[key] = val; }
            key = "" + ch;
            val = "";
        } else {
            val += ch;
        }
    }
    if key == "G" { gs.push(val); } else if key != "" { m[key] = val; }
    m.g = gs;
    m
}

fn pow10(n) { [1.0, 10.0, 100.0, 1000.0, 10000.0, 100000.0, 1000000.0, 10000000.0, 100000000.0][n] }

// A coordinate of a file: with a decimal point as it is, else digits that count `dec` decimals (zeros left out in front or behind).
fn gnum(s, f) {
    if s == "" { return 0.0; }
    if s.contains(".") { return parse_float(s); }
    let neg = s.starts_with("-");
    let d = s;
    if d.starts_with("-") || d.starts_with("+") { d = d.sub_string(1); }
    if d == "" { return 0.0; }
    if f.trail {
        while d.len() < f.int + f.dec { d += "0"; }
    }
    let v = parse_int(d).to_float() / pow10(f.dec);
    if neg { -v } else { v }
}

// ---- the expressions of aperture macros: numbers, $1.., + - x / and brackets ----
fn ex_tokens(s) {
    let t = [];
    let cur = "";
    for ch in s.chars() {
        if (ch >= '0' && ch <= '9') || ch == '.' || ch == '$' {
            cur += ch;
        } else {
            if cur != "" { t.push(cur); cur = ""; }
            if ch == '+' || ch == '-' || ch == '/' || ch == '(' || ch == ')' { t.push("" + ch); }
            else if ch == 'x' || ch == 'X' { t.push("*"); }
        }
    }
    if cur != "" { t.push(cur); }
    t
}

fn ex_factor(t, i, v) {
    if i >= t.len() { return [0.0, i]; }
    let tok = t[i];
    if tok == "-" { let r = ex_factor(t, i + 1, v); return [-r[0], r[1]]; }
    if tok == "+" { return ex_factor(t, i + 1, v); }
    if tok == "(" { let r = ex_sum(t, i + 1, v); return [r[0], r[1] + 1]; }
    if tok.starts_with("$") {
        let n = parse_int(tok.sub_string(1));
        return [if n >= 1 && n <= v.len() { v[n - 1] } else { 0.0 }, i + 1];
    }
    [parse_float(tok), i + 1]
}

fn ex_term(t, i, v) {
    let r = ex_factor(t, i, v);
    let acc = r[0];
    let at = r[1];
    while at < t.len() && (t[at] == "*" || t[at] == "/") {
        let q = ex_factor(t, at + 1, v);
        if t[at] == "*" { acc *= q[0]; } else if q[0] != 0.0 { acc /= q[0]; }
        at = q[1];
    }
    [acc, at]
}

fn ex_sum(t, i, v) {
    let r = ex_term(t, i, v);
    let acc = r[0];
    let at = r[1];
    while at < t.len() && (t[at] == "+" || t[at] == "-") {
        let q = ex_term(t, at + 1, v);
        if t[at] == "+" { acc += q[0]; } else { acc -= q[0]; }
        at = q[1];
    }
    [acc, at]
}

fn ex_eval(s, v) { ex_sum(ex_tokens(s), 0, v)[0] }

fn regular_pts(cx, cy, d, n, deg) {
    let out = [];
    for i in 0..n {
        let a = 2.0 * PI() * i.to_float() / n.to_float() + deg * PI() / 180.0;
        out.push([cx + d / 2.0 * cos(a), cy + d / 2.0 * sin(a)]);
    }
    out
}

// The polygons of an aperture macro called with the values vals.
fn macro_polys(prims, vals) {
    let v = vals;
    let out = [];
    for pr in prims {
        let line = pr;
        line.trim();
        if line == "" || line.starts_with("0 ") || line == "0" { continue; }
        if line.starts_with("$") && line.contains("=") {
            let eq = line.split('=');
            let n = parse_int(eq[0].sub_string(1));
            while v.len() < n { v.push(0.0); }
            v[n - 1] = ex_eval(eq[1], v);
            continue;
        }
        let f = line.split(',');
        let code = parse_int(f[0]);
        let a = [];
        for i in 1..f.len() { a.push(ex_eval(f[i], v)); }
        if a.len() == 0 { continue; }
        if a[0] == 0.0 { warn("a macro primitive with exposure off is left out"); continue; }
        if code == 1 && a.len() >= 4 {
            let rot = if a.len() >= 5 { a[4] } else { 0.0 };
            out.push(rot_all(circle_pts(a[2], a[3], a[1] / 2.0), rot));
        } else if code == 20 && a.len() >= 7 {
            let len = sqrt((a[4] - a[2]) * (a[4] - a[2]) + (a[5] - a[3]) * (a[5] - a[3]));
            let t = atan(a[5] - a[3], a[4] - a[2]);
            let nx = -sin(t) * a[1] / 2.0;
            let ny = cos(t) * a[1] / 2.0;
            out.push(rot_all([[a[2] + nx, a[3] + ny], [a[4] + nx, a[5] + ny], [a[4] - nx, a[5] - ny], [a[2] - nx, a[3] - ny]], a[6]));
        } else if code == 21 && a.len() >= 6 {
            out.push(rot_all(rect_pts(a[3], a[4], a[1], a[2]), a[5]));
        } else if code == 22 && a.len() >= 6 {
            out.push(rot_all(rect_pts(a[3] + a[1] / 2.0, a[4] + a[2] / 2.0, a[1], a[2]), a[5]));
        } else if code == 4 && a.len() >= 3 {
            let n = a[1].to_int();
            let pts = [];
            for i in 0..(n + 1) {
                if 3 + 2 * i < a.len() { pts.push([a[2 + 2 * i], a[3 + 2 * i]]); }
            }
            let rot = if a.len() > 3 + 2 * n { a[3 + 2 * n] } else { 0.0 };
            out.push(rot_all(pts, rot));
        } else if code == 5 && a.len() >= 6 {
            out.push(regular_pts(a[2], a[3], a[4], a[1].to_int(), a[5]));
        } else {
            warn("a macro primitive (code " + code + ") is not read");
        }
    }
    out
}

fn aperture_def(c, macros, u) {
    // c is like "ADD10C,0.2" or "ADD11RoundRect,0.1X2X3"
    let i = 3;
    let id = "";
    while i < c.len() && c.sub_string(i, 1) >= "0" && c.sub_string(i, 1) <= "9" {
        id += c.sub_string(i, 1);
        i += 1;
    }
    let rest = c.sub_string(i);
    let comma = rest.index_of(",");
    let name = if comma < 0 { rest } else { rest.sub_string(0, comma) };
    let vals = [];
    if comma >= 0 {
        for s in rest.sub_string(comma + 1).split('X') { vals.push(parse_float(s)); }
    }
    let ap = #{ id: id };
    if name == "C" {
        ap.t = "C"; ap.d = vals[0] * u;
    } else if name == "R" || name == "O" {
        ap.t = name; ap.w = vals[0] * u; ap.h = (if vals.len() > 1 { vals[1] } else { vals[0] }) * u;
    } else if name == "P" {
        ap.t = "P"; ap.d = vals[0] * u; ap.n = (if vals.len() > 1 { vals[1] } else { 3.0 }).to_int(); ap.rot = if vals.len() > 2 { vals[2] } else { 0.0 };
    } else if macros[name] != () {
        let polys = macro_polys(macros[name], vals);
        if polys.len() > 1 { polys = union_polygons(polys); }
        ap.t = "M"; ap.polys = polys; ap.u = u;
    } else {
        ap.t = "?";
        warn("aperture " + id + ": the shape " + name + " is not known");
    }
    ap
}

fn shift_pts(pts, x, y, u) {
    let out = [];
    for q in pts { out.push([x + q[0] * u, y + q[1] * u]); }
    out
}

fn flash(kind, ap, x, y) {
    let out = [];
    if ap.t == "C" {
        if ap.d > 0.0 { out.push(m_disc(kind, x, y, ap.d / 2.0)); }
    } else if ap.t == "R" {
        out.push(m_poly(kind, rect_pts(x, y, ap.w, ap.h)));
    } else if ap.t == "O" {
        if ap.w >= ap.h { out.push(m_poly(kind, capsule([x - (ap.w - ap.h) / 2.0, y], [x + (ap.w - ap.h) / 2.0, y], ap.h))); }
        else { out.push(m_poly(kind, capsule([x, y - (ap.h - ap.w) / 2.0], [x, y + (ap.h - ap.w) / 2.0], ap.w))); }
    } else if ap.t == "P" {
        out.push(m_poly(kind, regular_pts(x, y, ap.d, ap.n, ap.rot)));
    } else if ap.t == "M" {
        for pts in ap.polys { out.push(m_poly(kind, shift_pts(pts, x, y, ap.u))); }
    }
    out
}

// The points of an arc from (x0, y0) to (x1, y1) around the centre given by the offsets i, j.
fn gerber_arc(x0, y0, x1, y1, i, j, cw, single) {
    let cx = x0 + i;
    let cy = y0 + j;
    if single {
        // single quadrant mode: the offsets have no sign, try the four and keep the centre that is equally far from both ends
        let best = 1.0e30;
        for sx in [1.0, -1.0] {
            for sy in [1.0, -1.0] {
                let tx = x0 + abs(i) * sx;
                let ty = y0 + abs(j) * sy;
                let e = abs(sqrt((x0 - tx) * (x0 - tx) + (y0 - ty) * (y0 - ty)) - sqrt((x1 - tx) * (x1 - tx) + (y1 - ty) * (y1 - ty)));
                if e < best { best = e; cx = tx; cy = ty; }
            }
        }
    }
    let r = sqrt((x0 - cx) * (x0 - cx) + (y0 - cy) * (y0 - cy));
    let a0 = atan(y0 - cy, x0 - cx);
    let a1 = atan(y1 - cy, x1 - cx);
    let sweep = a1 - a0;
    if cw { while sweep > 0.0 { sweep -= 2.0 * PI(); } } else { while sweep < 0.0 { sweep += 2.0 * PI(); } }
    if abs(x1 - x0) < 0.000001 && abs(y1 - y0) < 0.000001 { sweep = if cw { -2.0 * PI() } else { 2.0 * PI() }; }
    arc_points(cx, cy, r, a0, sweep)
}

fn read_gerber(text, role) {
    let src = text;
    src.replace("\r", "");
    src.replace("\n", "");
    let parts = src.split('%');
    let fmt = #{ int: 2, dec: 4, trail: false };
    let u = 1.0;
    let macros = #{};
    let cur_macro = "";
    let aps = #{};
    let ap = #{ t: "?" };
    let kind = role;
    let out = [];
    let x = 0.0;
    let y = 0.0;
    let mode = 1;
    let single = false;
    let region = false;
    let contour = [];
    let trace = [];
    let tw = 0.0;
    let warned_clear = false;
    let warned_shape = false;
    for pi in 0..parts.len() { for cc in parts[pi].split('*') {
        let ext = pi % 2 == 1;
        let c = cc;
        c.trim();
        if c == "" { continue; }
        if ext {
            if c.starts_with("FS") {
                let xi = c.index_of("X");
                if xi >= 0 { fmt.int = parse_int(c.sub_string(xi + 1, 1)); fmt.dec = parse_int(c.sub_string(xi + 2, 1)); }
                fmt.trail = c.sub_string(2, 1) == "T";
            } else if c.starts_with("MOIN") {
                u = 25.4;
            } else if c.starts_with("MOMM") {
                u = 1.0;
            } else if c.starts_with("AM") {
                cur_macro = c.sub_string(2);
                macros[cur_macro] = [];
            } else if c.starts_with("ADD") {
                let a = aperture_def(c, macros, u);
                aps[a.id] = a;
            } else if c.starts_with("LPC") {
                if !warned_clear { warn("clear polarity (LPC) is not read: the drawing after it is added, not cut out"); warned_clear = true; }
            } else if c.starts_with("SR") && c.len() > 2 {
                warn("step and repeat (SR) is not read");
            } else if cur_macro != "" && !c.starts_with("T") && !c.starts_with("L") {
                macros[cur_macro].push(c);
            }
            continue;
        }
        if cur_macro != "" { cur_macro = ""; }
        if c.starts_with("G04") || c.starts_with("M02") || c.starts_with("M00") { continue; }
        let s = scan(c);
        for g in s.g {
            let n = parse_int(g);
            if n == 1 { mode = 1; } else if n == 2 { mode = 2; } else if n == 3 { mode = 3; }
            else if n == 74 { single = true; } else if n == 75 { single = false; }
            else if n == 70 { u = 25.4; } else if n == 71 { u = 1.0; }
            else if n == 36 { region = true; contour = []; }
            else if n == 37 {
                if contour.len() >= 3 { out.push(m_poly(kind, contour)); }
                region = false;
                contour = [];
            }
        }
        let nx = if s["X"] != () { gnum(s["X"], fmt) * u } else { x };
        let ny = if s["Y"] != () { gnum(s["Y"], fmt) * u } else { y };
        let ci = if s["I"] != () { gnum(s["I"], fmt) * u } else { 0.0 };
        let cj = if s["J"] != () { gnum(s["J"], fmt) * u } else { 0.0 };
        let d = if s["D"] != () { parse_int(s["D"]) } else { -1 };
        if d >= 10 {
            if trace.len() >= 2 { out.push(m_trace(kind, trace, tw)); }
            trace = [];
            let a = aps["" + d];
            ap = if a == () { #{ t: "?" } } else { a };
            continue;
        }
        if d == -1 && s["X"] == () && s["Y"] == () { continue; }
        if d == -1 { d = 1; }
        if d == 1 {
            let seg = if mode == 1 { [[x, y], [nx, ny]] } else { gerber_arc(x, y, nx, ny, ci, cj, mode == 2, single) };
            if region {
                if contour.len() == 0 { contour.push([x, y]); }
                for k in 1..seg.len() { contour.push(seg[k]); }
            } else {
                if ap.t != "C" && !warned_shape && ap.t != "?" { warn("a line drawn with a rectangular aperture is drawn with the width " + (if ap.t == "R" || ap.t == "O" { "of its smaller side" } else { "0" })); warned_shape = true; }
                let w = if ap.t == "C" { ap.d } else if ap.t == "R" || ap.t == "O" { (if ap.w < ap.h { ap.w } else { ap.h }) } else { 0.0 };
                if trace.len() > 0 && abs(trace[trace.len() - 1][0] - x) < 0.0000001 && abs(trace[trace.len() - 1][1] - y) < 0.0000001 {
                    for k in 1..seg.len() { trace.push(seg[k]); }
                } else {
                    if trace.len() >= 2 { out.push(m_trace(kind, trace, tw)); }
                    trace = seg;
                }
                tw = w;
            }
        } else if d == 2 {
            if region {
                if contour.len() >= 3 { out.push(m_poly(kind, contour)); }
                contour = [];
            }
            if trace.len() >= 2 { out.push(m_trace(kind, trace, tw)); }
            trace = [];
        } else if d == 3 {
            if trace.len() >= 2 { out.push(m_trace(kind, trace, tw)); }
            trace = [];
            for f in flash(kind, ap, nx, ny) { out.push(f); }
        }
        x = nx;
        y = ny;
    } }
    if trace.len() >= 2 { out.push(m_trace(kind, trace, tw)); }
    out
}

// ---- Excellon drill files ----
fn lead_float(s) {
    let t = "";
    for ch in s.chars() {
        if (ch >= '0' && ch <= '9') || ch == '.' { t += ch; } else { break; }
    }
    if t == "" { 0.0 } else { parse_float(t) }
}

fn read_drill(text) {
    let out = [];
    let u = 1.0;
    let lead = false;       // LZ: zeros in front are kept, those behind are left out
    let tools = #{};
    let tool = 0.0;
    let in_header = true;
    let skipped = 0;
    let dec = 3;
    let x = 0.0;
    let y = 0.0;
    let body = text;
    body.replace("\r", "");
    for raw in body.split('\n') {
        let l = raw;
        l.trim();
        if l == "" || l.starts_with(";") { continue; }
        if l.starts_with("M48") { in_header = true; continue; }
        if l == "%" || l.starts_with("M95") { in_header = false; continue; }
        if l.starts_with("METRIC") || l.starts_with("INCH") {
            u = if l.starts_with("INCH") { 25.4 } else { 1.0 };
            dec = if l.starts_with("INCH") { 4 } else { 3 };
            lead = l.contains("LZ");
            continue;
        }
        if l.starts_with("G90") || l.starts_with("G05") || l.starts_with("M71") || l.starts_with("M72") || l.starts_with("FMAT") || l.starts_with("ICI") || l.starts_with("VER") { continue; }
        if l.starts_with("T") {
            let ci = l.index_of("C");
            if ci > 0 {
                tools[l.sub_string(1, ci - 1)] = lead_float(l.sub_string(ci + 1)) * u;
            } else {
                let key = l.sub_string(1);
                if tools[key] != () { tool = tools[key]; in_header = false; }
            }
            continue;
        }
        if l.starts_with("M30") || l.starts_with("M00") { break; }
        if l.contains("G85") || l.starts_with("G00") || l.starts_with("G01") || l.starts_with("G02") || l.starts_with("G03") || l.starts_with("M15") || l.starts_with("M16") {
            skipped += 1;
            continue;
        }
        if in_header { continue; }
        if l.starts_with("X") || l.starts_with("Y") {
            let s = scan(l);
            let f = #{ int: 6 - dec, dec: dec, trail: lead };
            if s["X"] != () { x = gnum(s["X"], f) * u; }
            if s["Y"] != () { y = gnum(s["Y"], f) * u; }
            if tool > 0.0 { out.push(m_hole(x, y, tool)); }
        }
    }
    if skipped > 0 { warn("slots (routed holes) are not read: " + skipped + " lines left out"); }
    out
}

fn role_of(text, role) {
    if role == "Copper" { return "copper"; }
    if role == "Board outline" { return "outline"; }
    if role == "Legend (silkscreen)" { return "legend"; }
    let i = text.index_of("TF.FileFunction,");
    if i >= 0 {
        let line = text.sub_string(i, 80);
        if line.contains("Profile") { return "outline"; }
        if line.contains("Legend") { return "legend"; }
    }
    "copper"
}

fn read(text, ctx) {
    let p = ctx.p;
    let prims = if text.contains("M48") && !text.contains("%FS") { read_drill(text) } else { read_gerber(text, role_of(text, p.role)) };
    finish(prims, p, ctx)
}
