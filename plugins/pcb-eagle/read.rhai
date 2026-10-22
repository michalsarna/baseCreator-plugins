// Circuit board: an EAGLE board file. See README.md.

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

// ---- Autodesk EAGLE / Fusion Electronics board (.brd, XML) -------------------------------------------------------------------
// Read: the board outline (layer 20 Dimension), copper wires, vias, pads, SMD pads and holes (also inside the parts of the
// libraries, placed with their rotation and mirroring), the silkscreen (21 tPlace, 22 bPlace), rectangles and circles.
// Not read: copper pours (polygons in the signals: the file holds only their outline, not the clearances), text, a pad with
// no diameter in the file gets twice its drill.

// One tag of the file (the text after a "<") -> [name, closing, self-closing, [attribute, value, ...]], or () for a comment or a header.
fn xml_event(t) {
    let gt = t.index_of(">");
    if gt < 0 { return (); }
    let tag = t.sub_string(0, gt);
    if tag.starts_with("?") || tag.starts_with("!") { return (); }
    let close = tag.starts_with("/");
    let selfc = tag.ends_with("/");
    let pieces = tag.split('"');
    let first = pieces[0];
    first.trim();
    let name = if close { first.sub_string(1) } else { first.split(' ')[0] };
    if name.ends_with("/") { name = name.sub_string(0, name.len() - 1); }
    let flat = [];
    if !close {
        for k in 0..pieces.len() {
            if k % 2 == 1 { continue; }
            let lead = pieces[k];
            lead.trim();
            if !lead.ends_with("=") { continue; }
            let words = lead.sub_string(0, lead.len() - 1).split(' ');
            if k + 1 < pieces.len() { flat.push(words[words.len() - 1]); flat.push(pieces[k + 1]); }
        }
    }
    [name, close, selfc, flat]
}

fn amap(e) {
    let m = #{};
    let f = e[3];
    let i = 0;
    while i + 1 < f.len() { m[f[i]] = f[i + 1]; i += 2; }
    m
}

fn ea(e, k) {
    let f = e[3];
    let i = 0;
    while i + 1 < f.len() {
        if f[i] == k { return f[i + 1]; }
        i += 2;
    }
    ()
}

fn fa(m, k, d) { if m[k] == () { d } else { parse_float(m[k]) } }

fn eplace(q, xf) {
    let x = if xf.mir { -q[0] } else { q[0] };
    let r = rot_pt(x, q[1], xf.a);
    [r[0] + xf.x, r[1] + xf.y]
}

fn elayer(l, mir) {
    if !mir { return l; }
    if l == 1 { 16 } else if l == 16 { 1 } else if l == 21 { 22 } else if l == 22 { 21 } else { l }
}

fn ekind(l, p) {
    if l == 20 { return if p.outline { "outline" } else { "" }; }
    if l == 1 { return if p.copper_top { "copper" } else { "" }; }
    if l == 16 { return if p.copper_bottom { "copper" } else { "" }; }
    if l == 21 { return if p.legend_top { "legend" } else { "" }; }
    if l == 22 { return if p.legend_bottom { "legend" } else { "" }; }
    ""
}

fn eagle_xf(rot, x, y) {
    let r = rot;
    let mir = false;
    if r.starts_with("M") { mir = true; r = r.sub_string(1); }
    if r.starts_with("S") { r = r.sub_string(1); }
    if r.starts_with("R") { r = r.sub_string(1); }
    #{ x: x, y: y, a: if r == "" { 0.0 } else { parse_float(r) }, mir: mir }
}

fn ring_trace(kind, cx, cy, r, w, xf) {
    let pts = [];
    for q in circle_pts(cx, cy, r) { pts.push(eplace(q, xf)); }
    pts.push(pts[0]);
    m_trace(kind, pts, w)
}

// One drawing item of the board or of a package -> pieces.
fn eagle_item(e, xf, p) {
    let out = [];
    let a = amap(e);
    let nm = e[0];
    let l = elayer(fa(a, "layer", 0.0).to_int(), xf.mir);
    if nm == "wire" {
        let kind = ekind(l, p);
        if kind == "" { return out; }
        let p1 = [fa(a, "x1", 0.0), fa(a, "y1", 0.0)];
        let p2 = [fa(a, "x2", 0.0), fa(a, "y2", 0.0)];
        let curve = fa(a, "curve", 0.0);
        let pts = [];
        if curve == 0.0 {
            pts = [p1, p2];
        } else {
            let dx = p2[0] - p1[0];
            let dy = p2[1] - p1[1];
            let c = sqrt(dx * dx + dy * dy);
            let t = tan(curve * PI() / 360.0);
            if c > 0.0 && t != 0.0 {
                let h = c / 2.0 / t;
                pts = arc_centre((p1[0] + p2[0]) / 2.0 - dy / c * h, (p1[1] + p2[1]) / 2.0 + dx / c * h, p1[0], p1[1], curve);
            } else { pts = [p1, p2]; }
        }
        let placed = [];
        for q in pts { placed.push(eplace(q, xf)); }
        out.push(m_trace(kind, placed, fa(a, "width", 0.0)));
    } else if nm == "smd" {
        let kind = ekind(l, p);
        if kind != "copper" { return out; }
        let dx = fa(a, "dx", 0.0);
        let dy = fa(a, "dy", 0.0);
        let rd = fa(a, "roundness", 0.0);
        let m = if dx < dy { dx } else { dy };
        let shape = if rd > 0.0 { rrect_pts(dx, dy, rd / 100.0 * m / 2.0) } else { rect_pts(0.0, 0.0, dx, dy) };
        let rot = eagle_xf(if a["rot"] == () { "R0" } else { a["rot"] }, 0.0, 0.0);
        let at = eplace([fa(a, "x", 0.0), fa(a, "y", 0.0)], xf);
        let pts = [];
        for q in rot_all(shape, (if xf.mir { -rot.a } else { rot.a }) + xf.a) { pts.push([at[0] + q[0], at[1] + q[1]]); }
        out.push(m_poly("copper", pts));
    } else if nm == "pad" || nm == "via" {
        let drill = fa(a, "drill", 0.0);
        let dia = fa(a, "diameter", 0.0);
        if dia <= 0.0 { dia = drill * 2.0; }
        let at = eplace([fa(a, "x", 0.0), fa(a, "y", 0.0)], xf);
        if p.copper_top || p.copper_bottom {
            let shape = if a["shape"] == () { "round" } else { a["shape"] };
            if nm == "via" || shape == "round" {
                out.push(m_disc("copper", at[0], at[1], dia / 2.0));
            } else {
                let rot = eagle_xf(if a["rot"] == () { "R0" } else { a["rot"] }, 0.0, 0.0);
                let ang = (if xf.mir { -rot.a } else { rot.a }) + xf.a;
                let pts = [];
                let base = if shape == "square" { rect_pts(0.0, 0.0, dia, dia) } else if shape == "octagon" { regular_pts(0.0, 0.0, dia / cos(PI() / 8.0), 8, 22.5) } else { capsule([-dia / 2.0, 0.0], [dia / 2.0, 0.0], dia) };
                for q in rot_all(base, ang) { pts.push([at[0] + q[0], at[1] + q[1]]); }
                out.push(m_poly("copper", pts));
            }
        }
        if p.holes && drill > 0.0 { out.push(m_hole(at[0], at[1], drill)); }
    } else if nm == "hole" {
        let at = eplace([fa(a, "x", 0.0), fa(a, "y", 0.0)], xf);
        if p.holes { out.push(m_hole(at[0], at[1], fa(a, "drill", 0.0))); }
    } else if nm == "circle" {
        let kind = ekind(l, p);
        if kind == "" { return out; }
        let w = fa(a, "width", 0.0);
        let r = fa(a, "radius", 0.0);
        if w == 0.0 && kind == "copper" {
            let at = eplace([fa(a, "x", 0.0), fa(a, "y", 0.0)], xf);
            out.push(m_disc(kind, at[0], at[1], r));
        } else {
            out.push(ring_trace(kind, fa(a, "x", 0.0), fa(a, "y", 0.0), r, w, xf));
        }
    } else if nm == "rectangle" {
        let kind = ekind(l, p);
        if kind == "" { return out; }
        let x1 = fa(a, "x1", 0.0);
        let y1 = fa(a, "y1", 0.0);
        let x2 = fa(a, "x2", 0.0);
        let y2 = fa(a, "y2", 0.0);
        let rot = eagle_xf(if a["rot"] == () { "R0" } else { a["rot"] }, 0.0, 0.0);
        let c = [(x1 + x2) / 2.0, (y1 + y2) / 2.0];
        let pts = [];
        for q in rot_all(rect_pts(0.0, 0.0, abs(x2 - x1), abs(y2 - y1)), rot.a) { pts.push(eplace([c[0] + q[0], c[1] + q[1]], xf)); }
        if kind == "copper" { out.push(m_poly(kind, pts)); }
        else { pts.push(pts[0]); out.push(m_trace(kind, pts, 0.1)); }
    }
    out
}

fn read(text, ctx) {
    let p = ctx.p;
    let parts = text.split('<');
    // the parts of the libraries
    let pk = #{};
    let lib = "";
    let cur = "";
    for i in 1..parts.len() {
        let e = xml_event(parts[i]);
        if e == () { continue; }
        if e[1] {
            if e[0] == "package" { cur = ""; } else if e[0] == "library" { lib = ""; }
            continue;
        }
        if e[0] == "library" { lib = if ea(e, "name") == () { "" } else { ea(e, "name") }; }
        else if e[0] == "package" { cur = lib + "/" + ea(e, "name"); pk[cur] = []; }
        else if cur != "" && (e[0] == "wire" || e[0] == "smd" || e[0] == "pad" || e[0] == "hole" || e[0] == "circle" || e[0] == "rectangle") { pk[cur].push(e); }
    }
    // the board
    let prims = [];
    let ident = #{ x: 0.0, y: 0.0, a: 0.0, mir: false };
    let section = "";
    let poly = ();
    let pours = 0;
    for i in 1..parts.len() {
        let e = xml_event(parts[i]);
        if e == () { continue; }
        if e[1] {
            if e[0] == "plain" || e[0] == "signals" || e[0] == "elements" { section = ""; }
            if e[0] == "polygon" && poly != () {
                let kind = ekind(poly.layer, p);
                if kind != "" && poly.pts.len() >= 3 {
                    poly.pts.push(poly.pts[0]);
                    prims.push(m_trace(kind, poly.pts, poly.width));
                }
                poly = ();
            }
            continue;
        }
        if e[0] == "plain" || e[0] == "signals" || e[0] == "elements" { section = e[0]; continue; }
        if section == "elements" && e[0] == "element" {
            let xf = eagle_xf(if ea(e, "rot") == () { "R0" } else { ea(e, "rot") }, fa(amap(e), "x", 0.0), fa(amap(e), "y", 0.0));
            let items = pk[ea(e, "library") + "/" + ea(e, "package")];
            if items == () { warn("the part " + ea(e, "name") + " has no package in the file"); continue; }
            for it in items { for q in eagle_item(it, xf, p) { prims.push(q); } }
        } else if section == "plain" && e[0] == "polygon" {
            poly = #{ layer: fa(amap(e), "layer", 0.0).to_int(), width: fa(amap(e), "width", 0.0), pts: [] };
        } else if section == "plain" && e[0] == "vertex" && poly != () {
            poly.pts.push([fa(amap(e), "x", 0.0), fa(amap(e), "y", 0.0)]);
        } else if section == "signals" && e[0] == "polygon" {
            pours += 1;
        } else if section == "plain" || section == "signals" {
            if e[0] == "wire" || e[0] == "via" || e[0] == "pad" || e[0] == "hole" || e[0] == "circle" || e[0] == "rectangle" || e[0] == "smd" {
                for q in eagle_item(e, ident, p) { prims.push(q); }
            }
        }
    }
    if pours > 0 { warn(pours + " copper pour(s) are left out: the file holds only their outline, not the clearances around other traces"); }
    finish(prims, p, ctx)
}
