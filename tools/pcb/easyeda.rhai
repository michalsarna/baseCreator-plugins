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
