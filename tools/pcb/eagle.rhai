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
