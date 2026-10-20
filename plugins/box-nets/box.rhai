// The net of a box (a prism, a pyramid, a truncated prism) for cutting out of paper or card and folding by hand.
//
// The outline is drawn with a continuous line (layer "cut"), the folds with a dashed one (layer "fold"). The sides of a prism are one
// strip; the bottom and the top are separate pieces, and the strip has glue tabs on its top and bottom edges, and one on its end.
// A pyramid is a fan of triangles round the apex (one tab closes it), with the base as a separate piece and a tab on every base
// edge. A tab is glued under the edge of the piece it meets.
//
// Everything is first made in millimetres with Y down, from the top left of the strip; at the end the net is put in the middle of
// the work area.

fn dist(a, b) {
    let dx = b[0] - a[0];
    let dy = b[1] - a[1];
    sqrt(dx * dx + dy * dy)
}

// The corners of the base, counter-clockwise (Y up), or [] when the sizes do not make a shape.
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
        let x = (b * b + c * c - a * a) / (2.0 * c);
        let y2 = b * b - x * x;
        let y = if y2 > 0.0 { sqrt(y2) } else { 0.0 };
        [[0.0, 0.0], [c, 0.0], [x, y]]
    } else if kind == "Rectangle" {
        [[0.0, 0.0], [p.rect_w, 0.0], [p.rect_w, p.rect_d], [0.0, p.rect_d]]
    } else if kind == "Trapezoid" {
        let a = p.trap_a;
        let b = p.trap_b;
        let o = (a - b) / 2.0;
        [[0.0, 0.0], [a, 0.0], [o + b, p.trap_d], [o, p.trap_d]]
    } else {
        let n = p.poly_n.to_int();
        let r = p.poly_side / (2.0 * sin(PI() / n.to_float()));
        let pts = [];
        for i in 0..n {
            let a = 2.0 * PI() * i.to_float() / n.to_float();
            pts.push([r * cos(a), r * sin(a)]);
        }
        pts
    }
}

// A glue tab on the edge p-q, on the side away from the point `away`: [the outline (open), the fold line].
fn tab(p, q, away, d) {
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
    let c = min(d * 0.7, l / 3.0);
    let pd = [p[0] + nx * d + ex * c, p[1] + ny * d + ey * c];
    let qd = [q[0] + nx * d - ex * c, q[1] + ny * d - ey * c];
    #{ cut: [p, pd, qd, q], fold: [p, q] }
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

fn generate(p, ctx) {
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

    let ymin = 1.0e30;
    let cx = 0.0;
    let cy = 0.0;
    for q in pts {
        if q[1] < ymin { ymin = q[1]; }
        cx += q[0] / n.to_float();
        cy += q[1] / n.to_float();
    }

    let cut = [];
    let fold = [];

    if solid == "Pyramid" {
        // A fan of triangles round the apex, at (0, 0): the angle at the apex of every one comes from its three sides.
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
        if phi > 2.0 * PI() - 0.8 {
            warn("The pyramid is so flat that its closing tab may lie on the first side");
        }
        let apex = [0.0, 0.0];
        cut.push([apex, corners[0]]);
        for i in 0..n {
            let tb = tab(corners[i], corners[i + 1], apex, d);
            cut.push(tb.cut);
            fold.push(tb.fold);
            if i > 0 {
                fold.push([apex, corners[i]]);
            }
        }
        let closing = tab(apex, corners[n], corners[n - 1], d);
        cut.push(closing.cut);
        fold.push(closing.fold);
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
        cut.push([[0.0, 0.0], [0.0, -zs[0]]]);
        for i in 0..n {
            let a = [xs[i], 0.0];
            let b = [xs[i + 1], 0.0];
            let tb = tab(a, b, [(xs[i] + xs[i + 1]) / 2.0, -1.0], d);
            cut.push(tb.cut);
            fold.push(tb.fold);
            let ta = [xs[i], -zs[i]];
            let tc = [xs[i + 1], -zs[i + 1]];
            let tt = tab(ta, tc, [(xs[i] + xs[i + 1]) / 2.0, 0.0], d);
            cut.push(tt.cut);
            fold.push(tt.fold);
            if i > 0 {
                fold.push([[xs[i], 0.0], [xs[i], -zs[i]]]);
            }
        }
        let last = xs[n];
        let closing = tab([last, 0.0], [last, -zs[0]], [last - 1.0, -zs[0] / 2.0], d);
        cut.push(closing.cut);
        fold.push(closing.fold);
    }

    // The separate pieces below the strip (or the fan): the base, and the top of a prism, which a slanted cut makes longer.
    let main = box_of(cut);
    let pieces = [];
    let place_x = main[0];
    let place_y = main[3] + p.space;
    let stretch = sqrt(1.0 + t * t);
    let count = if solid == "Pyramid" { 1 } else { 2 };
    for k in 0..count {
        let poly = [];
        for q in pts {
            poly.push([q[0], if k == 1 { ymin + (q[1] - ymin) * stretch } else { q[1] }]);
        }
        let pb = box_of([poly]);
        let moved = [];
        for q in poly {
            moved.push([q[0] - pb[0] + place_x, q[1] - pb[1] + place_y]);
        }
        pieces.push(moved);
        place_x += (pb[2] - pb[0]) + p.space;
    }

    // Into the middle of the work area.
    let all = [];
    all.append(cut);
    all.append(pieces);
    for f in fold {
        all.push(f);
    }
    let bb = box_of(all);
    let dx = ctx.area_w / 2.0 - (bb[0] + bb[2]) / 2.0;
    let dy = ctx.area_h / 2.0 - (bb[1] + bb[3]) / 2.0;
    if bb[2] - bb[0] > ctx.area_w || bb[3] - bb[1] > ctx.area_h {
        warn("The net is bigger than the work area: " + (bb[2] - bb[0]).round().to_int() + " x " + (bb[3] - bb[1]).round().to_int() + " mm");
    }

    let cut_layer = p.cut_layer.to_int();
    let fold_layer = p.fold_layer.to_int();
    let out = [];
    for l in cut {
        let pl = [];
        for q in l {
            pl.push([q[0] + dx, q[1] + dy]);
        }
        let s = polyline(pl);
        s.layer = cut_layer;
        out.push(s);
    }
    for l in pieces {
        let pl = [];
        for q in l {
            pl.push([q[0] + dx, q[1] + dy]);
        }
        let s = polygon(pl);
        s.layer = cut_layer;
        out.push(s);
    }
    for f in fold {
        let a = [f[0][0] + dx, f[0][1] + dy];
        let b = [f[1][0] + dx, f[1][1] + dy];
        out.append(dashes(a, b, p.dash, p.dash_gap, fold_layer));
    }
    out
}
