// The net of a box (a prism, a pyramid, a truncated prism, a cylinder on a circle or an ellipse, straight or cut slantways) for cutting out of paper or card and folding by hand.
//
// The net is ONE piece when the shape allows it: the sides are a strip (a fan for a pyramid), and the bottom and the top are
// folded on to it along one of their edges, so there is a single outline to cut (a continuous line) and the folds are dashed
// lines. The glue tabs sit on the other edges of the bottom and the top, and one closes the strip. When no edge of a polygon
// gives a layout without overlaps, that polygon is a separate piece, with its tabs on the strip. Everything comes out as one
// group.
//
// Everything is first made in millimetres with Y down, from the top left of the strip; at the end the net is put in the middle of
// the work area.

fn dist(a, b) {
    let dx = b[0] - a[0];
    let dy = b[1] - a[1];
    sqrt(dx * dx + dy * dy)
}

// The corners of the base, counter-clockwise (Y up), the first edge along X at the bottom (the longest side of a triangle, the
// longer base of a trapezoid), or [] when the sizes do not make a shape.
fn base_polygon(p) {
    let kind = p.base;
    if kind == "Triangle" {
        let a = p.tri_a;
        let b = p.tri_b;
        let c = p.tri_c;
        if a + b <= c || a + c <= b || b + c <= a {
            warn("The three sides do not make a triangle");
            return [];
        }
        // The longest side lies at the bottom: both its angles are acute, so the triangle does not stick out sideways.
        let base = max(a, max(b, c));
        let rest = [];
        let used = false;
        for s in [a, b, c] {
            if s == base && !used {
                used = true;
            } else {
                rest.push(s);
            }
        }
        let u = rest[0];
        let v = rest[1];
        let x = (u * u + base * base - v * v) / (2.0 * base);
        let y2 = u * u - x * x;
        let y = if y2 > 0.0 { sqrt(y2) } else { 0.0 };
        [[0.0, 0.0], [base, 0.0], [x, y]]
    } else if kind == "Rectangle" {
        [[0.0, 0.0], [p.rect_w, 0.0], [p.rect_w, p.rect_d], [0.0, p.rect_d]]
    } else if kind == "Trapezoid" {
        let a = max(p.trap_a, p.trap_b);
        let b = min(p.trap_a, p.trap_b);
        let o = (a - b) / 2.0;
        [[0.0, 0.0], [a, 0.0], [o + b, p.trap_d], [o, p.trap_d]]
    } else {
        let n = p.poly_n.to_int();
        let r = p.poly_side / (2.0 * sin(PI() / n.to_float()));
        let pts = [];
        for i in 0..n {
            // Turned so that the first edge is the one at the bottom.
            let a = 2.0 * PI() * i.to_float() / n.to_float() - PI() / 2.0 - PI() / n.to_float();
            pts.push([r * cos(a), r * sin(a)]);
        }
        pts
    }
}

// A glue tab on the edge p-q, on the side away from the point `away`, `d` deep, the ends slanted by `cf` * d:
// #{ cut: the outline from p to q (p, two corners, q), fold: [p, q] }.
fn tab(p, q, away, d, cf) {
    if d < 0.05 {
        return #{ cut: [p, q], fold: [p, q] };
    }
    let l = dist(p, q);
    let ex = (q[0] - p[0]) / l;
    let ey = (q[1] - p[1]) / l;
    let nx = ey;
    let ny = -ex;
    let mx = (p[0] + q[0]) / 2.0 - away[0];
    let my = (p[1] + q[1]) / 2.0 - away[1];
    if nx * mx + ny * my < 0.0 {
        nx = -nx;
        ny = -ny;
    }
    // The ends of the tab are slanted, so that the tabs of two neighbouring edges do not meet.
    let c = min(d * cf, l / 3.0);
    let pd = [p[0] + nx * d + ex * c, p[1] + ny * d + ey * c];
    let qd = [q[0] + nx * d - ex * c, q[1] + ny * d - ey * c];
    #{ cut: [p, pd, qd, q], fold: [p, q] }
}

// The tab of the edge a-b as outline points after a (up to b), pushed to `pts`, and its fold to `folds`.
fn edge_tab(a, b, away, d, cf) {
    let t = tab(a, b, away, d, cf);
    let pts = [];
    for k in 1..(t.cut.len() - 1) {
        pts.push(t.cut[k]);
    }
    pts.push(b);
    #{ pts: pts, fold: t.fold }
}

// The polygon `poly` (plan, counter-clockwise) moved so that its edge i -> i+1 lies on a -> b. `flip` mirrors it first (the
// polygon then lies on the right of a -> b instead of the left).
fn place(poly, i, a, b, flip) {
    let n = poly.len();
    let j = (i + 1) % n;
    let q = [];
    for p in poly {
        q.push([p[0], if flip { -p[1] } else { p[1] }]);
    }
    let ex = q[j][0] - q[i][0];
    let ey = q[j][1] - q[i][1];
    let fx = b[0] - a[0];
    let fy = b[1] - a[1];
    let le = sqrt(ex * ex + ey * ey);
    let lf = sqrt(fx * fx + fy * fy);
    let ux = ex / le;
    let uy = ey / le;
    let vx = fx / lf;
    let vy = fy / lf;
    let c = ux * vx + uy * vy;
    let s = ux * vy - uy * vx;
    let out = [];
    for p in q {
        let dx = p[0] - q[i][0];
        let dy = p[1] - q[i][1];
        out.push([a[0] + c * dx - s * dy, a[1] + s * dx + c * dy]);
    }
    out
}

// The way round a placed polygon from its corner i to the corner i+1 (`desc`) or back (not `desc`), without the shared edge: a tab
// on every other edge. #{ pts: the outline after the first corner (the last point is the corner reached), folds }.
fn detour(q, i, desc, d, cf) {
    let n = q.len();
    let cx = 0.0;
    let cy = 0.0;
    for p in q {
        cx += p[0] / n.to_float();
        cy += p[1] / n.to_float();
    }
    let pts = [];
    let folds = [];
    let j = (i + 1) % n;
    for s in 0..(n - 1) {
        let a = if desc { q[((i - s) % n + n) % n] } else { q[(j + s) % n] };
        let b = if desc { q[((i - s - 1) % n + n) % n] } else { q[(j + s + 1) % n] };
        let et = edge_tab(a, b, [cx, cy], d, cf);
        pts.append(et.pts);
        folds.push(et.fold);
    }
    #{ pts: pts, folds: folds }
}

// What the edge a-b of the strip (or the fan) adds to the outline and the folds: the polygon `q` folded on to it (this edge is the
// polygon's edge kk), a tab of its own (kk == -1), or nothing (-2). `desc`: the outline goes the way of the polygon's order.
fn side(i, kk, q, tabs, a, b, away, desc) {
    let pts = [];
    let folds = [];
    if i == kk {
        folds.push([a, b]);
        let dt = detour(q, i, desc, tabs[0], tabs[1]);
        for k in 0..(dt.pts.len() - 1) {
            pts.push(dt.pts[k]);
        }
        pts.push(b);
        folds.append(dt.folds);
    } else if kk == -1 {
        let et = edge_tab(a, b, away, tabs[0], tabs[1]);
        pts.append(et.pts);
        folds.push(et.fold);
    } else {
        pts.push(b);
    }
    #{ pts: pts, folds: folds }
}

// The outline of a net of a prism: the strip of the sides with the bottom (edge kb) and the top (edge kt) folded on to it.
// kb / kt: the edge, -1 = a separate piece (tabs on the strip), -2 = nothing there. qb / qt: the placed polygons.
// tb / tt: [depth, slant] of the tabs of the bottom and of the top.
fn prism_net(xs, zs, n, kb, qb, tb, kt, qt, tt, d) {
    let pts = [[0.0, 0.0]];
    let folds = [];
    for i in 0..n {
        let a = [xs[i], 0.0];
        let b = [xs[i + 1], 0.0];
        let sd = side(i, kb, qb, tb, a, b, [(a[0] + b[0]) / 2.0, -1.0], true);
        pts.append(sd.pts);
        folds.append(sd.folds);
    }
    let last = xs[n];
    let closing = tab([last, 0.0], [last, -zs[0]], [last - 1.0, -zs[0] / 2.0], d, 0.7);
    for k in 1..closing.cut.len() {
        pts.push(closing.cut[k]);
    }
    folds.push(closing.fold);
    for r in 0..n {
        let i = n - 1 - r;
        let a = [xs[i + 1], -zs[i + 1]];
        let b = [xs[i], -zs[i]];
        let sd = side(i, kt, qt, tt, a, b, [(a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0 + 1.0], false);
        pts.append(sd.pts);
        folds.append(sd.folds);
    }
    for i in 1..n {
        folds.push([[xs[i], 0.0], [xs[i], -zs[i]]]);
    }
    #{ pts: pts, folds: folds }
}

// The outline of a net of a pyramid: the fan of the sides, the base folded on to the edge kb (-1 = separate: tabs on the fan).
fn pyramid_net(corners, n, kb, qb, tb, d) {
    let apex = [0.0, 0.0];
    let pts = [apex, corners[0]];
    let folds = [];
    for i in 0..n {
        let sd = side(i, kb, qb, tb, corners[i], corners[i + 1], apex, true);
        pts.append(sd.pts);
        folds.append(sd.folds);
        if i > 0 {
            folds.push([apex, corners[i]]);
        }
    }
    let closing = tab(apex, corners[n], corners[n - 1], d, 0.7);
    if closing.cut.len() > 3 {
        pts.push(closing.cut[2]);
        pts.push(closing.cut[1]);
    }
    folds.push(closing.fold);
    #{ pts: pts, folds: folds }
}

// The sizes of the tabs to try, deepest first: [the share of the depth, the slant of the ends in depths]. A polygon with wide
// corners leaves a narrow space beside the edge it is folded on to: a shallow tab with a long slant fits there.
fn tab_tries() {
    [[1.0, 0.7], [1.0, 1.6], [0.7, 1.6], [0.5, 2.5], [0.3, 4.0], [0.15, 6.0], [0.07, 12.0]]
}

// The edges to try for a polygon of n sides: all of a small one; of a big regular one the ones at the ends of the strip (the middle
// edges only have neighbours on both sides).
fn candidates(n) {
    let v = [];
    if n <= 6 {
        for k in 0..n {
            v.push(k);
        }
    } else {
        v = [0, n - 1, 1, n - 2];
    }
    v
}

fn first_of(a, m) {
    let v = [];
    for k in 0..min(m, a.len()) {
        v.push(a[k]);
    }
    v
}

// A line from a to b as dashes (they start and end with a dash), on a layer.
fn dashes(a, b, dash, gap, layer) {
    let out = [];
    let l = dist(a, b);
    if l < 0.000001 {
        return out;
    }
    let k = ((l + gap) / (dash + gap)).floor().to_int();
    if k < 1 {
        k = 1;
    }
    let dl = (l - (k - 1).to_float() * gap) / k.to_float();
    let ux = (b[0] - a[0]) / l;
    let uy = (b[1] - a[1]) / l;
    for i in 0..k {
        let s = i.to_float() * (dl + gap);
        let e = s + dl;
        let ln = line(a[0] + ux * s, a[1] + uy * s, a[0] + ux * e, a[1] + uy * e);
        ln.layer = layer;
        out.push(ln);
    }
    out
}

// The box [min x, min y, max x, max y] round some polylines.
fn box_of(lines) {
    let b = [1.0e30, 1.0e30, -1.0e30, -1.0e30];
    for l in lines {
        for q in l {
            if q[0] < b[0] { b[0] = q[0]; }
            if q[1] < b[1] { b[1] = q[1]; }
            if q[0] > b[2] { b[2] = q[0]; }
            if q[1] > b[3] { b[3] = q[1]; }
        }
    }
    b
}

// A point of the rim of an ellipse drawn at (x0, y0) with the semi-axes ra, rb; sg: +1 or -1, the way the angle turns on the sheet.
fn rim(x0, y0, sg, ra, rb, phi) {
    [x0 + ra * cos(phi), y0 + sg * rb * sin(phi)]
}

// A disc (the bottom or the top of a cylinder) joined to the wall by a chord: the outline from one end of the chord round the
// disc to the other (first point included), with a ring of glue tabs, and the folds of the tabs. phs / dir: the angle of the
// first end and the way round; the arc covers pi + 2 * phi0. yline: the line of the chord (no tab may cross it, the wall is
// beyond it).
fn disc(x0, y0, sg, ra, rb, phi0, phs, dir, yline, d, cf) {
    let span = PI() + 2.0 * phi0;
    let pts = [rim(x0, y0, sg, ra, rb, phs)];
    let folds = [];
    if d < 0.05 {
        for k in 1..73 {
            pts.push(rim(x0, y0, sg, ra, rb, phs + dir * span * k.to_float() / 72.0));
        }
        return #{ pts: pts, folds: folds };
    }
    let est = 0.0;
    let prev = pts[0];
    for k in 1..73 {
        let q = rim(x0, y0, sg, ra, rb, phs + dir * span * k.to_float() / 72.0);
        est += dist(prev, q);
        prev = q;
    }
    let nt = max(4, (est / (2.4 * d)).round().to_int());
    let w = 1.0 / nt.to_float();
    for j in 0..nt {
        let f0 = j.to_float() * w;
        let f1 = f0 + w;
        let fa = f0 + 0.15 * w;
        let fb = f1 - 0.15 * w;
        let p = rim(x0, y0, sg, ra, rb, phs + dir * span * fa);
        let q = rim(x0, y0, sg, ra, rb, phs + dir * span * fb);
        let tb = tab(p, q, [x0, y0], d, cf);
        let ok = true;
        for c in tb.cut {
            if (yline - c[1]) * sg < 0.3 {
                ok = false;
            }
        }
        for k in 1..3 {
            pts.push(rim(x0, y0, sg, ra, rb, phs + dir * span * (f0 + (fa - f0) * k.to_float() / 2.0)));
        }
        if ok {
            pts.push(tb.cut[1]);
            pts.push(tb.cut[2]);
            pts.push(q);
            folds.push(tb.fold);
        } else {
            for k in 1..5 {
                pts.push(rim(x0, y0, sg, ra, rb, phs + dir * span * (fa + (fb - fa) * k.to_float() / 4.0)));
            }
        }
        for k in 1..3 {
            pts.push(rim(x0, y0, sg, ra, rb, phs + dir * span * (fb + (f1 - fb) * k.to_float() / 2.0)));
        }
    }
    #{ pts: pts, folds: folds }
}

// The height of the wall at the length x along the strip (the table of lengths ss and heights zs).
fn z_at(ss, zs, x) {
    let n = ss.len();
    for i in 0..(n - 1) {
        if ss[i + 1] >= x {
            let l = ss[i + 1] - ss[i];
            let f = if l > 0.0 { (x - ss[i]) / l } else { 0.0 };
            return zs[i] + (zs[i + 1] - zs[i]) * f;
        }
    }
    zs[n - 1]
}

// The net of a cylinder on a circle or an ellipse (ra along X, rb along Y), straight or cut slantways (the top rises towards the
// back by `slant`): the wall is a strip as long as the rim, and the bottom and the top are joined to it in the middle by a short
// chord (a disc cannot lie along a straight edge by more than a point), with a ring of glue tabs. One tab closes the wall.
fn cylinder_net(p) {
    let ra = 0.0;
    let rb = 0.0;
    if p.base == "Circle" {
        ra = p.circ_r;
        rb = p.circ_r;
    } else {
        ra = p.ell_a;
        rb = p.ell_b;
    }
    if p.solid == "Pyramid" {
        warn("A pyramid stands on a triangle or a rectangle only: a prism is made");
    }
    let h = p.height;
    let d = p.tab;
    let t = if p.solid == "Truncated prism" { p.slant / 100.0 } else { 0.0 };
    let stretch = sqrt(1.0 + t * t);
    // The tabs round a small disc are no deeper than the disc allows.
    let dt = min(d, 0.6 * min(ra, rb));

    // The way round the rim from the front (the lowest point of the wall) with the height of the wall there.
    let m = 288;
    let ss = [0.0];
    let zs = [h];
    let prev = [0.0, -rb];
    for i in 1..(m + 1) {
        let th = 1.5 * PI() + 2.0 * PI() * i.to_float() / m.to_float();
        let q = [ra * cos(th), rb * sin(th)];
        ss.push(ss[i - 1] + dist(prev, q));
        zs.push(h + t * (q[1] + rb));
        prev = q;
    }
    let len = ss[m];
    let x0 = len / 2.0;
    // The discs join the wall at the back (the highest point of a slanted cut) by a chord 2u long.
    let u = min(0.3 * ra, 20.0);
    let z1 = (z_at(ss, zs, x0 - u) + z_at(ss, zs, x0 + u)) / 2.0;
    let phi0 = acos(u / ra);

    let folds = [];
    let pts = [[0.0, 0.0]];
    let bottom = disc(x0, rb * sin(phi0), -1.0, ra, rb, phi0, PI() - phi0, 1.0, 0.0, dt, 0.7);
    pts.append(bottom.pts);
    folds.append(bottom.folds);
    folds.push([[x0 - u, 0.0], [x0 + u, 0.0]]);

    pts.push([len, 0.0]);
    let closing = tab([len, 0.0], [len, -h], [len - 1.0, -h / 2.0], d, 0.7);
    for k in 1..closing.cut.len() {
        pts.push(closing.cut[k]);
    }
    folds.push(closing.fold);

    // The top edge back to the start: the curve of the cut up to the disc, the disc, the rest of the curve.
    let i = m - 1;
    if t > 0.0000001 {
        while i > 0 && ss[i] > x0 + u {
            pts.push([ss[i], -zs[i]]);
            i -= 1;
        }
    }
    let ytop = rb * stretch * sin(phi0);
    let top = disc(x0, -z1 - ytop, 1.0, ra, rb * stretch, phi0, phi0, -1.0, -z1, dt, 0.7);
    pts.append(top.pts);
    folds.append(top.folds);
    folds.push([[x0 - u, -z1], [x0 + u, -z1]]);
    if t > 0.0000001 {
        while i > 0 {
            if ss[i] < x0 - u {
                pts.push([ss[i], -zs[i]]);
            }
            i -= 1;
        }
    }
    pts.push([0.0, -h]);
    #{ pts: pts, folds: folds }
}

fn generate(p, ctx) {
    if p.base == "Circle" || p.base == "Ellipse" {
        let net = cylinder_net(p);
        return finish(net, [], p, ctx);
    }
    let pts = base_polygon(p);
    if pts.len() == 0 {
        return [];
    }
    let n = pts.len();
    let kind = p.base;
    let solid = p.solid;
    if solid == "Pyramid" && kind != "Triangle" && kind != "Rectangle" {
        warn("A pyramid stands on a triangle or a rectangle only: a prism is made");
        solid = "Prism";
    }
    let h = p.height;
    let t = if solid == "Truncated prism" { p.slant / 100.0 } else { 0.0 };
    let d = p.tab;
    let tries = tab_tries();

    let ymin = 1.0e30;
    for q in pts {
        if q[1] < ymin { ymin = q[1]; }
    }

    let net = ();
    // Pieces that could not be folded on to the net: closed outlines placed under it.
    let loose = [];

    if solid == "Pyramid" {
        // A fan of triangles round the apex, at (0, 0): the angle at the apex of every one comes from its three sides.
        let cx = 0.0;
        let cy = 0.0;
        for q in pts {
            cx += q[0] / n.to_float();
            cy += q[1] / n.to_float();
        }
        let b = [];
        for q in pts {
            b.push(sqrt((q[0] - cx) * (q[0] - cx) + (q[1] - cy) * (q[1] - cy) + h * h));
        }
        let corners = [];
        let phi = 0.0;
        for i in 0..n {
            corners.push([b[i] * cos(phi), b[i] * sin(phi)]);
            let j = (i + 1) % n;
            let l = dist(pts[i], pts[j]);
            let c = (b[i] * b[i] + b[j] * b[j] - l * l) / (2.0 * b[i] * b[j]);
            if c > 1.0 { c = 1.0; }
            if c < -1.0 { c = -1.0; }
            phi += acos(c);
        }
        corners.push([b[0] * cos(phi), b[0] * sin(phi)]);
        let kb = -1;
        let qb = [];
        let tb = [d, 0.7];
        let found = false;
        for at in tries {
            if found { break; }
            for k in 0..n {
                let q = place(pts, k, corners[k], corners[k + 1], true);
                let cand = pyramid_net(corners, n, k, q, [d * at[0], at[1]], d);
                if polygon_is_simple(cand.pts) {
                    kb = k;
                    qb = q;
                    tb = [d * at[0], at[1]];
                    found = true;
                    break;
                }
            }
        }
        if !found {
            warn("The base could not be folded on to the sides without overlaps: it is a separate piece");
            loose.push(pts);
        }
        net = pyramid_net(corners, n, kb, qb, tb, d);
    } else {
        // A strip of the sides: the bottoms in a line, the heights as the sides have them (a truncated prism is cut by a plane
        // that rises towards the back of the base).
        let xs = [0.0];
        let zs = [];
        for i in 0..n {
            let j = (i + 1) % n;
            xs.push(xs[i] + dist(pts[i], pts[j]));
            zs.push(h + t * (pts[i][1] - ymin));
        }
        zs.push(zs[0]);
        // The top is the base stretched along Y (the cut plane is slanted).
        let stretch = sqrt(1.0 + t * t);
        let top = [];
        for q in pts {
            top.push([q[0], ymin + (q[1] - ymin) * stretch]);
        }
        // The bottom: the first edge that gives an outline without overlaps.
        let kb = -1;
        let qb = [];
        let tb = [d, 0.7];
        let found = false;
        for at in tries {
            if found { break; }
            for k in candidates(n) {
                let q = place(pts, k, [xs[k], 0.0], [xs[k + 1], 0.0], false);
                let cand = prism_net(xs, zs, n, k, q, [d * at[0], at[1]], -2, [], [d, 0.7], d);
                if polygon_is_simple(cand.pts) {
                    kb = k;
                    qb = q;
                    tb = [d * at[0], at[1]];
                    found = true;
                    break;
                }
            }
        }
        if !found {
            warn("The bottom could not be folded on to the sides without overlaps: it is a separate piece");
            loose.push(pts);
        }
        // The top: the highest edges first (nothing of the strip is above them).
        let order = [];
        for k in 0..n {
            order.push(k);
        }
        let hs = [];
        for k in 0..n {
            hs.push(zs[k] + zs[k + 1]);
        }
        order.sort(|a, b| if hs[a] > hs[b] + 0.000001 { -1 } else if hs[a] < hs[b] - 0.000001 { 1 } else { 0 });
        let kt = -1;
        let qt = [];
        let tt = [d, 0.7];
        found = false;
        for at in tries {
            if found { break; }
            for k in first_of(order, 5) {
                let q = place(top, k, [xs[k], -zs[k]], [xs[k + 1], -zs[k + 1]], true);
                let cand = prism_net(xs, zs, n, if kb >= 0 { kb } else { -2 }, qb, tb, k, q, [d * at[0], at[1]], d);
                if polygon_is_simple(cand.pts) {
                    kt = k;
                    qt = q;
                    tt = [d * at[0], at[1]];
                    found = true;
                    break;
                }
            }
        }
        if !found {
            warn("The top could not be folded on to the sides without overlaps: it is a separate piece");
            loose.push(top);
        }
        net = prism_net(xs, zs, n, kb, qb, tb, kt, qt, tt, d);
    }
    finish(net, loose, p, ctx)
}

// The outline of the net and the separate pieces put in the middle of the work area, the folds dashed, all as one group.
fn finish(net, loose, p, ctx) {
    if !polygon_is_simple(net.pts) {
        warn("The outline of the net crosses itself (the shape is too flat or too sharp to unfold in one piece)");
    }

    // The separate pieces go under the net.
    let main = box_of([net.pts]);
    let pieces = [];
    let place_x = main[0];
    let place_y = main[3] + p.space;
    for poly in loose {
        let pb = box_of([poly]);
        let moved = [];
        for q in poly {
            moved.push([q[0] - pb[0] + place_x, q[1] - pb[1] + place_y]);
        }
        pieces.push(moved);
        place_x += (pb[2] - pb[0]) + p.space;
    }

    // Into the middle of the work area.
    let all = [net.pts];
    all.append(pieces);
    let bb = box_of(all);
    let dx = ctx.area_w / 2.0 - (bb[0] + bb[2]) / 2.0;
    let dy = ctx.area_h / 2.0 - (bb[1] + bb[3]) / 2.0;
    if bb[2] - bb[0] > ctx.area_w || bb[3] - bb[1] > ctx.area_h {
        warn("The net is bigger than the work area: " + (bb[2] - bb[0]).round().to_int() + " x " + (bb[3] - bb[1]).round().to_int() + " mm");
    }

    let cut_layer = p.cut_layer.to_int();
    let fold_layer = p.fold_layer.to_int();
    let out = [];
    let outline = [];
    for q in net.pts {
        outline.push([q[0] + dx, q[1] + dy]);
    }
    let s = polygon(outline);
    s.layer = cut_layer;
    out.push(s);
    for l in pieces {
        let pl = [];
        for q in l {
            pl.push([q[0] + dx, q[1] + dy]);
        }
        let s = polygon(pl);
        s.layer = cut_layer;
        out.push(s);
    }
    for f in net.folds {
        let a = [f[0][0] + dx, f[0][1] + dy];
        let b = [f[1][0] + dx, f[1][1] + dy];
        out.append(dashes(a, b, p.dash, p.dash_gap, fold_layer));
    }
    // One group: the box is moved, scaled and selected as a whole.
    [group(out)]
}
