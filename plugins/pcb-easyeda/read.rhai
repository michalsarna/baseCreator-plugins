// Circuit board: an EasyEDA (Standard) PCB document. See README.md.

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

// ---- EasyEDA (Standard edition) PCB document (.json) -------------------------------------------------------------------------
// The file lists the shapes of the board as strings "TRACK~...", "PAD~...", separated by "~". One unit is 10 mil (0.254 mm),
// Y counts down. Read: tracks, arcs, circles, solid regions, pads (ellipse, rectangle, oval, polygon), vias and holes by layer
// (1 top copper, 2 bottom copper, 3 / 4 silkscreen, 10 board outline, 11 all layers). Not read: copper areas (pours; the file holds
// only their outline), text, slots of oval holes, the Pro edition (.epro).

fn u(s) { parse_float(s) * 0.254 }

fn fields(s) { s.split('~') }

fn nums(s) {
    let out = [];
    let t = s;
    t.replace(",", " ");
    for w in t.split() { out.push(parse_float(w) * 0.254); }
    out
}

fn ekind2(l, p) {
    if l == 10 { return if p.outline { "outline" } else { "" }; }
    if l == 1 { return if p.copper_top { "copper" } else { "" }; }
    if l == 2 { return if p.copper_bottom { "copper" } else { "" }; }
    if l == 3 { return if p.legend_top { "legend" } else { "" }; }
    if l == 4 { return if p.legend_bottom { "legend" } else { "" }; }
    ""
}

fn lay(s) { if s == "" { 0 } else { parse_int(s) } }

// Points of a path of the kind "M x y L x y ... Z" (a straight-edged one) or "M x y A rx ry rot large sweep x y".
fn path_points(d) {
    let t = d;
    t.replace(",", " ");
    t.replace("M", " M ");
    t.replace("L", " L ");
    t.replace("A", " A ");
    t.replace("Z", " Z ");
    let w = t.split();
    let pts = [];
    let i = 0;
    while i < w.len() {
        let c = w[i];
        if (c == "M" || c == "L") && i + 2 < w.len() {
            pts.push([parse_float(w[i + 1]) * 0.254, -parse_float(w[i + 2]) * 0.254]);
            i += 3;
        } else if c == "A" && i + 7 < w.len() {
            let p1 = pts[pts.len() - 1];
            let p2 = [parse_float(w[i + 6]) * 0.254, -parse_float(w[i + 7]) * 0.254];
            for q in svg_arc(p1, p2, parse_float(w[i + 1]) * 0.254, w[i + 4] == "1", w[i + 5] == "1") { pts.push(q); }
            i += 8;
        } else {
            i += 1;
        }
    }
    pts
}

// An SVG arc between two points (Y up here, so a "sweep" arc, clockwise on the screen, turns the negative way).
fn svg_arc(p1, p2, r, large, sweep) {
    let dx = p2[0] - p1[0];
    let dy = p2[1] - p1[1];
    let d = sqrt(dx * dx + dy * dy);
    if d < 0.000001 { return [p2]; }
    if r < d / 2.0 { r = d / 2.0; }
    let h = sqrt(r * r - d * d / 4.0);
    let ccw = !sweep;
    let left = ccw != large;
    let sgn = if left { 1.0 } else { -1.0 };
    let cx = (p1[0] + p2[0]) / 2.0 - dy / d * h * sgn;
    let cy = (p1[1] + p2[1]) / 2.0 + dx / d * h * sgn;
    let a0 = atan(p1[1] - cy, p1[0] - cx);
    let a1 = atan(p2[1] - cy, p2[0] - cx);
    let s = wrap_pos(a1 - a0);
    if !ccw { s = s - 2.0 * PI(); }
    let pts = arc_points(cx, cy, r, a0, s);
    pts.remove(0);
    pts
}

fn pad_prims2(f, p) {
    let out = [];
    // PAD~shape~x~y~width~height~layer~net~number~holeRadius~points~rotation~id~holeLength~...
    let l = lay(f[6]);
    let cx = u(f[2]);
    let cy = -u(f[3]);
    let w = u(f[4]);
    let h = u(f[5]);
    let rot = if f.len() > 11 && f[11] != "" { -parse_float(f[11]) } else { 0.0 };
    let on = (l == 1 || l == 11) && p.copper_top || (l == 2 || l == 11) && p.copper_bottom;
    if on {
        let shape = f[1];
        let pts = [];
        if shape == "POLYGON" {
            let n = nums(f[10]);
            let i = 0;
            while i + 1 < n.len() { pts.push([n[i], -n[i + 1]]); i += 2; }
        } else if shape == "ELLIPSE" {
            if abs(w - h) < 0.0001 { out.push(m_disc("copper", cx, cy, w / 2.0)); }
            else {
                for q in circle_pts(0.0, 0.0, 1.0) { pts.push([q[0] * w / 2.0, q[1] * h / 2.0]); }
                pts = rot_all(pts, rot);
                let moved = [];
                for q in pts { moved.push([cx + q[0], cy + q[1]]); }
                pts = moved;
                out.push(m_poly("copper", pts));
                pts = [];
            }
        } else if shape == "OVAL" {
            let base = if w >= h { capsule([-(w - h) / 2.0, 0.0], [(w - h) / 2.0, 0.0], h) } else { capsule([0.0, -(h - w) / 2.0], [0.0, (h - w) / 2.0], w) };
            for q in rot_all(base, rot) { pts.push([cx + q[0], cy + q[1]]); }
        } else {
            for q in rot_all(rect_pts(0.0, 0.0, w, h), rot) { pts.push([cx + q[0], cy + q[1]]); }
        }
        if pts.len() >= 3 { out.push(m_poly("copper", pts)); }
    }
    let hr = u(f[9]);
    if hr > 0.0 && p.holes { out.push(m_hole(cx, cy, hr * 2.0)); }
    out
}

fn read(text, ctx) {
    let p = ctx.p;
    let prims = [];
    let parts = text.split('"');
    let seen = 0;
    let pours = 0;
    for s in parts {
        if !s.contains("~") { continue; }
        let f = fields(s);
        let t = f[0];
        if t == "TRACK" && f.len() > 4 {
            seen += 1;
            let kind = ekind2(lay(f[2]), p);
            if kind == "" { continue; }
            let n = nums(f[4]);
            let pts = [];
            let i = 0;
            while i + 1 < n.len() { pts.push([n[i], -n[i + 1]]); i += 2; }
            if pts.len() >= 2 { prims.push(m_trace(kind, pts, u(f[1]))); }
        } else if t == "ARC" && f.len() > 4 {
            seen += 1;
            let kind = ekind2(lay(f[2]), p);
            if kind == "" { continue; }
            let pts = path_points(f[4]);
            if pts.len() >= 2 { prims.push(m_trace(kind, pts, u(f[1]))); }
        } else if t == "CIRCLE" && f.len() > 5 {
            seen += 1;
            let kind = ekind2(lay(f[5]), p);
            if kind == "" { continue; }
            let pts = circle_pts(u(f[1]), -u(f[2]), u(f[3]));
            pts.push(pts[0]);
            prims.push(m_trace(kind, pts, u(f[4])));
        } else if t == "SOLIDREGION" && f.len() > 3 {
            seen += 1;
            let kind = ekind2(lay(f[1]), p);
            if kind == "" { continue; }
            let pts = path_points(f[3]);
            if pts.len() >= 3 { prims.push(m_poly(kind, pts)); }
        } else if t == "COPPERAREA" {
            pours += 1;
        } else if t == "PAD" && f.len() > 11 {
            seen += 1;
            for q in pad_prims2(f, p) { prims.push(q); }
        } else if t == "VIA" && f.len() > 5 {
            seen += 1;
            let cx = u(f[1]);
            let cy = -u(f[2]);
            if p.copper_top || p.copper_bottom { prims.push(m_disc("copper", cx, cy, u(f[3]) / 2.0)); }
            if p.holes { prims.push(m_hole(cx, cy, u(f[5]) * 2.0)); }
        } else if t == "HOLE" && f.len() > 3 {
            seen += 1;
            if p.holes { prims.push(m_hole(u(f[1]), -u(f[2]), u(f[3]))); }
        }
    }
    if seen == 0 { warn("this file has no EasyEDA PCB shapes (TRACK, PAD, ...): is it a PCB document of the Standard edition?"); }
    if pours > 0 { warn(pours + " copper area(s) are left out: the file holds only their outline, not the clearances around other traces"); }
    finish(prims, p, ctx)
}
