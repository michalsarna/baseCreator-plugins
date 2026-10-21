// A box to cut out of plywood, acrylic or card with a laser and put together without glue: every face is a separate piece and
// the edges that meet have fingers and notches (a box joint) that fit into each other. The material thickness is taken into
// account: the sizes are the OUTER sizes of the box, the fingers are as deep as the material is thick (on a slanted joint as
// deep as the other piece reaches), and a kerf can be added so that the joint is snug.
//
// A prism, a truncated prism (the top slanted) or a pyramid on a polygon is made of flat faces: they are unfolded one by one from
// their 3D corners. A cylinder, a slanted cylinder, a cone and a truncated cone on a circle or an ellipse have a bent wall: the wall
// is a strip (a fan) that is closed by a comb along its two ends, and the discs have fingers along the rim.
//
// Everything is first made in millimetres with Y up; at the end the pieces are packed in rows in the middle of the work area.

fn dist(a, b) {
    let dx = b[0] - a[0];
    let dy = b[1] - a[1];
    sqrt(dx * dx + dy * dy)
}

fn sub3(a, b) { [a[0] - b[0], a[1] - b[1], a[2] - b[2]] }
fn dot3(a, b) { a[0] * b[0] + a[1] * b[1] + a[2] * b[2] }
fn cross3(a, b) { [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]] }
fn unit3(a) {
    let l = sqrt(dot3(a, a));
    if l < 0.000001 { [0.0, 0.0, 0.0] } else { [a[0] / l, a[1] / l, a[2] / l] }
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

// The point of a polyline at the distance s from its start and the normal (to the left) there: [x, y, nx, ny].
fn at(pts, cum, s) {
    let n = pts.len();
    let i = 0;
    while i < n - 2 && cum[i + 1] < s {
        i += 1;
    }
    let a = pts[i];
    let b = pts[i + 1];
    let l = cum[i + 1] - cum[i];
    let f = if l > 0.0 { (s - cum[i]) / l } else { 0.0 };
    if f < 0.0 { f = 0.0; }
    if f > 1.0 { f = 1.0; }
    let dx = b[0] - a[0];
    let dy = b[1] - a[1];
    let ll = sqrt(dx * dx + dy * dy);
    if ll < 0.0000001 {
        return [a[0], a[1], 0.0, 0.0];
    }
    [a[0] + dx * f, a[1] + dy * f, -dy / ll, dx / ll]
}

// The edge `src` (the interior of the piece on its left) with fingers and notches: `owner` has fingers at the ends (an odd number of
// parts about `w` wide, the first `in0` and the last `in1` of the edge left out because another piece stands there), `rec` is how
// deep the notches are cut into the piece, `kerf` widens the fingers. `rev`: the parts are counted from the end of the edge, so that
// the two pieces of a joint count from the same end.
fn edge_profile(src, owner, rec, w, in0, in1, kerf, rev, sk0, sk1) {
    let pts = [];
    let a0 = in0;
    let a1 = in1;
    let sgn = 1.0;
    if rev {
        let n = src.len();
        for i in 0..n {
            pts.push(src[n - 1 - i]);
        }
        a0 = in1;
        a1 = in0;
        sgn = -1.0;
        let sw = sk0;
        sk0 = sk1;
        sk1 = sw;
    } else {
        pts = src;
    }
    let n = pts.len();
    let cum = [0.0];
    for i in 1..n {
        cum.push(cum[i - 1] + dist(pts[i - 1], pts[i]));
    }
    let len = cum[n - 1];
    let usable = len - a0 - a1;
    if usable < 0.3 * w {
        // Too short for a joint: the part is left as it is.
        a0 = 0.0;
        a1 = 0.0;
        usable = len;
    }
    let want = usable / w;
    let k = want.round().to_int();
    if k < 1 { k = 1; }
    if k % 2 == 0 {
        k = if want > k.to_float() { k + 1 } else { k - 1 };
        if k < 1 { k = 1; }
    }
    let sw = usable / k.to_float();
    let b = [];
    for j in 0..(k + 1) {
        b.push(a0 + sw * j.to_float());
    }
    for j in 1..k {
        let left_finger = (owner && (j - 1) % 2 == 0) || (!owner && (j - 1) % 2 == 1);
        b[j] += if left_finger { kerf / 2.0 } else { -kerf / 2.0 };
    }
    let out = [];
    for j in 0..k {
        let finger = (owner && j % 2 == 0) || (!owner && j % 2 == 1);
        let lv = if finger { 0.0 } else { rec };
        let s0 = max(b[j], sk0);
        let s1 = min(b[j + 1], len - sk1);
        if s1 <= s0 + 0.000001 {
            continue;
        }
        let p0 = at(pts, cum, s0);
        out.push([p0[0] + sgn * p0[2] * lv, p0[1] + sgn * p0[3] * lv]);
        for i in 1..(n - 1) {
            if cum[i] > s0 + 0.000001 && cum[i] < s1 - 0.000001 {
                let q = at(pts, cum, cum[i]);
                out.push([q[0] + sgn * q[2] * lv, q[1] + sgn * q[3] * lv]);
            }
        }
        let p1 = at(pts, cum, s1);
        out.push([p1[0] + sgn * p1[2] * lv, p1[1] + sgn * p1[3] * lv]);
    }
    if rev {
        out.reverse();
    }
    out
}

// Takes out the doubled points and the points on a straight line (also the ones where the line turns back on itself).
fn clean(src) {
    let out = [];
    for q in src {
        out.push(q);
        let again = true;
        while again && out.len() >= 3 {
            let m = out.len();
            let a = out[m - 3];
            let b = out[m - 2];
            let c = out[m - 1];
            let cr = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]);
            if dist(b, c) < 0.0001 {
                out.pop();
            } else if abs(cr) < 0.0000001 {
                out.remove(m - 2);
            } else {
                again = false;
            }
        }
    }
    // The closing of the loop.
    let again = true;
    while again && out.len() >= 4 {
        let m = out.len();
        again = false;
        if dist(out[m - 1], out[0]) < 0.0001 {
            out.pop();
            again = true;
            continue;
        }
        let a = out[m - 2];
        let b = out[m - 1];
        let c = out[0];
        let cr = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]);
        if abs(cr) < 0.0000001 {
            out.pop();
            again = true;
            continue;
        }
        let a = out[m - 1];
        let b = out[0];
        let c = out[1];
        let cr = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]);
        if abs(cr) < 0.0000001 {
            out.remove(0);
            again = true;
        }
    }
    out
}

// One piece from its edges: #{ pts, joint, owner, rec, in0, in1, rev }; an edge that is not a joint is taken as it is.
fn build_panel(edges, w, kerf) {
    let poly = [];
    for e in edges {
        if e.joint {
            poly.append(edge_profile(e.pts, e.owner, e.rec, w, e.in0, e.in1, kerf, e.rev, e.sk0, e.sk1));
        } else {
            poly.append(e.pts);
        }
    }
    clean(poly)
}

fn plain(pts) { #{ pts: pts, joint: false, owner: false, rec: 0.0, in0: 0.0, in1: 0.0, rev: false, sk0: 0.0, sk1: 0.0 } }
fn joint(pts, owner, rec, in0, in1, rev) { #{ pts: pts, joint: true, owner: owner, rec: rec, in0: in0, in1: in1, rev: rev, sk0: 0.0, sk1: 0.0 } }

// The same edge, but the first sk0 and the last sk1 of it (along the edge) are not drawn: the outline comes from the neighbour there.
fn skipping(e, sk0, sk1) {
    e.sk0 = sk0;
    e.sk1 = sk1;
    e
}

fn sin_floor(x) {
    let s = abs(x);
    if s < 0.25 { 0.25 } else { s }
}

// ---------- Flat faces ----------

// How much of an edge between two side faces is left free at each end: the bottom or the lid stands there (and the notches of
// the edge along it), or the edges meet at a tip.
fn edge_insets(V, F, major, normals, flat, info, t, fi, i, dir, len) {
    let m = F[fi].len();
    let ends = [F[fi][i], F[fi][(i + 1) % m]];
    let ins = [0.0, 0.0];
    for k in 0..2 {
        let v = ends[k];
        let cnt = 0;
        let mj = -1;
        for g in 0..F.len() {
            if F[g].contains(v) {
                cnt += 1;
                if major.contains(g) { mj = g; }
            }
        }
        if mj >= 0 {
            ins[k] = t / sin_floor(dot3(dir, normals[mj]));
            let ne = if k == 0 { (i + m - 1) % m } else { (i + 1) % m };
            if major.contains(info[fi][ne].g) {
                let own = flat[fi][i];
                let oth = flat[fi][(i + 1) % m];
                let nb = flat[fi][if k == 0 { ne } else { (i + 2) % m }];
                if k == 1 {
                    own = flat[fi][(i + 1) % m];
                    oth = flat[fi][i];
                }
                let more = notch_clearance(own, oth, nb, info[fi][ne].rec + info[fi][i].rec);
                if more > ins[k] { ins[k] = more; }
            }
        } else if cnt >= 3 {
            ins[k] = 3.0 * t;
        }
        if ins[k] > 0.3 * len { ins[k] = 0.3 * len; }
    }
    ins
}

// Where an edge from the corner `own` towards `oth` has left the notch (`rec` deep, with the notch of the edge itself) cut along the
// edge from `own` towards `nb`.
fn notch_clearance(own, oth, nb, rec) {
    let u1 = [oth[0] - own[0], oth[1] - own[1]];
    let u2 = [nb[0] - own[0], nb[1] - own[1]];
    let l1 = sqrt(u1[0] * u1[0] + u1[1] * u1[1]);
    let l2 = sqrt(u2[0] * u2[0] + u2[1] * u2[1]);
    let ca = (u1[0] * u2[0] + u1[1] * u2[1]) / (l1 * l2);
    if ca > -0.9999 && ca < 0.9999 {
        rec / sqrt(1.0 - ca * ca)
    } else {
        0.0
    }
}

// The faces of a solid (corners V as [x, y, z], faces F as lists of corners counter-clockwise seen from outside); `major` are the
// faces (the bottom and the lid) that own the joints along their edges and stand at the ends of the edges between the other faces.
fn solid_panels(V, F, major, p) {
    let t = p.thickness;
    let nf = F.len();
    let normals = [];
    let flat = [];
    for f in F {
        // The normal of the face (Newell's method) and the corners in the plane of the face.
        let nn = [0.0, 0.0, 0.0];
        let m = f.len();
        for i in 0..m {
            let a = V[f[i]];
            let b = V[f[(i + 1) % m]];
            nn[0] += (a[1] - b[1]) * (a[2] + b[2]);
            nn[1] += (a[2] - b[2]) * (a[0] + b[0]);
            nn[2] += (a[0] - b[0]) * (a[1] + b[1]);
        }
        nn = unit3(nn);
        let e1 = unit3(sub3(V[f[1]], V[f[0]]));
        let e2 = cross3(nn, e1);
        let q = [];
        for i in 0..m {
            let d = sub3(V[f[i]], V[f[0]]);
            q.push([dot3(d, e1), dot3(d, e2)]);
        }
        normals.push(nn);
        flat.push(q);
    }
    // For every edge of every face: the face on the other side, how deep the notches are.
    let info = [];
    for fi in 0..nf {
        let f = F[fi];
        let m = f.len();
        let row = [];
        for i in 0..m {
            let a = f[i];
            let b = f[(i + 1) % m];
            let gj = -1;
            for g in 0..nf {
                if g != fi && gj < 0 {
                    let h = F[g];
                    let hm = h.len();
                    for j in 0..hm {
                        if h[j] == b && h[(j + 1) % hm] == a {
                            gj = g;
                        }
                    }
                }
            }
            let rec = t;
            if gj >= 0 {
                // The angle between the two faces inside the solid.
                let dir = unit3(sub3(V[b], V[a]));
                let uf = cross3(normals[fi], dir);
                let ug = cross3(normals[gj], [-dir[0], -dir[1], -dir[2]]);
                let c = dot3(uf, ug);
                if c > 1.0 { c = 1.0; }
                if c < -1.0 { c = -1.0; }
                rec = t / sin_floor(sin(acos(c)));
            }
            row.push(#{ g: gj, rec: rec });
        }
        info.push(row);
    }
    let out = [];
    for fi in 0..nf {
        let f = F[fi];
        let m = f.len();
        let edges = [];
        for i in 0..m {
            let a = f[i];
            let b = f[(i + 1) % m];
            let pa = flat[fi][i];
            let pb = flat[fi][(i + 1) % m];
            let gj = info[fi][i].g;
            if gj < 0 {
                edges.push(plain([pa, pb]));
                continue;
            }
            let dir = unit3(sub3(V[b], V[a]));
            let fm = major.contains(fi);
            let gm = major.contains(gj);
            let owner = if fm { true } else if gm { false } else { fi < gj };
            let len = dist(pa, pb);
            let ins = [0.0, 0.0];
            if !fm && !gm {
                ins = edge_insets(V, F, major, normals, flat, info, t, fi, i, dir, len);
            }
            edges.push(joint([pa, pb], owner, info[fi][i].rec, ins[0], ins[1], a > b));
        }
        out.push(build_panel(edges, p.finger, p.kerf));
    }
    #{ panels: out, discs: 0 }
}

fn prism_solid(pts, h, k, lid, p) {
    let n = pts.len();
    let ymin = 1.0e30;
    for q in pts {
        if q[1] < ymin { ymin = q[1]; }
    }
    let V = [];
    for q in pts {
        V.push([q[0], q[1], 0.0]);
    }
    for q in pts {
        V.push([q[0], q[1], h + k * (q[1] - ymin)]);
    }
    let F = [];
    let bottom = [];
    for i in 0..n {
        bottom.push(n - 1 - i);
    }
    F.push(bottom);
    for i in 0..n {
        let j = (i + 1) % n;
        F.push([i, j, n + j, n + i]);
    }
    let major = [0];
    if lid {
        let top = [];
        for i in 0..n {
            top.push(n + i);
        }
        F.push(top);
        major.push(n + 1);
    }
    solid_panels(V, F, major, p)
}

fn pyramid_solid(pts, h, p) {
    let n = pts.len();
    let cx = 0.0;
    let cy = 0.0;
    for q in pts {
        cx += q[0] / n.to_float();
        cy += q[1] / n.to_float();
    }
    let V = [];
    for q in pts {
        V.push([q[0], q[1], 0.0]);
    }
    V.push([cx, cy, h]);
    let F = [];
    let bottom = [];
    for i in 0..n {
        bottom.push(n - 1 - i);
    }
    F.push(bottom);
    for i in 0..n {
        F.push([i, (i + 1) % n, n]);
    }
    solid_panels(V, F, [0], p)
}

// ---------- Round shapes ----------

// The rim of an ellipse from the angle th0 counter-clockwise, `sy` stretches it along Y.
fn rim_points(ra, rb, th0, m, sy) {
    let q = [];
    for i in 0..(m + 1) {
        let th = th0 + 2.0 * PI() * i.to_float() / m.to_float();
        q.push([ra * cos(th), rb * sy * sin(th)]);
    }
    q
}

// A disc: the rim is one joint edge; the disc owns it.
fn disc_panel(rim, rec, p) {
    build_panel([joint(rim, true, rec, 0.0, 0.0, false)], p.finger, p.kerf)
}

// The line `pts` moved by d to the right of its direction (outwards from the piece).
fn shifted_out(pts, d) {
    let out = [];
    let n = pts.len();
    for i in 0..n {
        let a = pts[if i == 0 { 0 } else { i - 1 }];
        let b = pts[if i == 0 { 1 } else { i }];
        let l = dist(a, b);
        let nx = if l > 0.0 { -(b[1] - a[1]) / l } else { 0.0 };
        let ny = if l > 0.0 { (b[0] - a[0]) / l } else { 0.0 };
        out.push([pts[i][0] - nx * d, pts[i][1] - ny * d]);
    }
    out
}

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

// A cylinder on a circle or an ellipse, straight or cut slantways: two discs and the wall, a strip as long as the rim whose ends
// are closed by a comb `comb` deep.
fn cylinder_panels(p) {
    let ra = 0.0;
    let rb = 0.0;
    if p.base == "Circle" {
        ra = p.circ_r;
        rb = p.circ_r;
    } else {
        ra = p.ell_a;
        rb = p.ell_b;
    }
    let h = p.height;
    let t = p.thickness;
    let lid = p.lid == "Yes";
    let k = if p.solid == "Truncated prism" { p.slant / 100.0 } else { 0.0 };
    let stretch = sqrt(1.0 + k * k);
    let m = 288;
    let rim = rim_points(ra, rb, 1.5 * PI(), m, 1.0);
    let ss = [0.0];
    let zs = [h];
    for i in 1..(m + 1) {
        ss.push(ss[i - 1] + dist(rim[i - 1], rim[i]));
        zs.push(h + k * (rim[i][1] + rb));
    }
    let len = ss[m];
    let c = p.comb;
    let out = [disc_panel(rim, t, p)];
    if lid {
        out.push(disc_panel(rim_points(ra, rb, 1.5 * PI(), m, stretch), t, p));
    }
    let top = [];
    for i in 0..(m + 1) {
        top.push([ss[m - i], zs[m - i]]);
    }
    let edges = [];
    edges.push(joint([[0.0, 0.0], [len, 0.0]], false, t, 0.0, 0.0, false));
    edges.push(joint([[len + c, 0.0], [len + c, h]], true, c, t, if lid { t } else { 0.0 }, false));
    if lid {
        edges.push(joint(top, false, t, 0.0, 0.0, true));
    } else {
        edges.push(plain(top));
    }
    edges.push(joint([[0.0, h], [0.0, 0.0]], false, c, if lid { t } else { 0.0 }, t, true));
    out.push(build_panel(edges, p.finger, p.kerf));
    #{ panels: out, discs: out.len() }
}

// A cone or a truncated cone: the discs and the wall, a fan round the apex (a ring of it for a truncated cone) developed from the rim
// in small steps.
fn cone_panels(p) {
    let ra = 0.0;
    let rb = 0.0;
    if p.base == "Circle" {
        ra = p.circ_r;
        rb = p.circ_r;
    } else {
        ra = p.ell_a;
        rb = p.ell_b;
    }
    let k = if p.solid == "Truncated pyramid" { p.top / 100.0 } else { 0.0 };
    let t = p.thickness;
    let lid = p.lid == "Yes" && k > 0.0000001;
    let hh = p.height / (1.0 - k);
    let m = 288;
    let qs = rim_points(ra, rb, PI(), m, 1.0);
    let bs = [];
    for i in 0..(m + 1) {
        bs.push(sqrt(qs[i][0] * qs[i][0] + qs[i][1] * qs[i][1] + hh * hh));
    }
    let psi = [0.0];
    for i in 0..m {
        let l = dist(qs[i], qs[i + 1]);
        let c = (bs[i] * bs[i] + bs[i + 1] * bs[i + 1] - l * l) / (2.0 * bs[i] * bs[i + 1]);
        if c > 1.0 { c = 1.0; }
        if c < -1.0 { c = -1.0; }
        psi.push(psi[i] + acos(c));
    }
    let pm = psi[m / 2];
    // Seen from outside with the apex at the top: the rim runs from left to right.
    let outer = [];
    let inner = [];
    for i in 0..(m + 1) {
        let a = psi[i] - pm;
        outer.push([bs[i] * sin(a), -bs[i] * cos(a)]);
        inner.push([k * bs[i] * sin(a), -k * bs[i] * cos(a)]);
    }
    // How deep the floor and the lid reach along the slanted edge.
    let rm = sqrt(ra * rb);
    let rec = t / sin_floor(hh / sqrt(rm * rm + hh * hh));
    let c = p.comb;
    let out = [disc_panel(qs, rec, p)];
    if lid {
        let top = [];
        for q in qs {
            top.push([k * q[0], k * q[1]]);
        }
        out.push(disc_panel(top, rec, p));
    }
    let edges = [];
    edges.push(skipping(joint(outer, false, rec, 0.0, 0.0, false), c, 0.0));
    let apex = [0.0, 0.0];
    let seam_end = if k > 0.0000001 { inner[m] } else { apex };
    let seam_start = if k > 0.0000001 { inner[0] } else { apex };
    // The comb is cut c to the side of the seam: on the side that is closed over the seam leaves the notches where the comb end falls on
    // the bottom of the notch of the rim (a circle round the apex), so that no sliver is left.
    let r0 = bs[0];
    let v0 = (r0 - rec) * (r0 - rec) - c * c;
    let in_out_l = if v0 > 0.0 { max(rec, r0 - sqrt(v0)) } else { rec };
    let r1 = k * bs[0];
    let v1 = (r1 + rec) * (r1 + rec) - c * c;
    let in_top_l = if v1 > 0.0 { max(rec, sqrt(v1) - r1) } else { rec };
    let in_top = if lid { rec } else if k > 0.0000001 { 0.0 } else { 3.0 * t };
    let in_top_left = if lid { in_top_l } else { in_top };
    edges.push(joint(shifted_out([outer[m], seam_end], c), true, c, rec, in_top, false));
    if k > 0.0000001 {
        let back = [];
        for i in 0..(m + 1) {
            back.push(inner[m - i]);
        }
        if lid {
            edges.push(skipping(joint(back, false, rec, 0.0, 0.0, true), 0.0, c));
        } else {
            edges.push(plain(back));
        }
    }
    edges.push(joint([seam_start, outer[0]], false, c, in_top_left, in_out_l, true));
    out.push(build_panel(edges, p.finger, p.kerf));
    #{ panels: out, discs: out.len() }
}

// ---------- The whole box ----------

fn box_of(polys) {
    let x0 = 1.0e30;
    let y0 = 1.0e30;
    let x1 = -1.0e30;
    let y1 = -1.0e30;
    for poly in polys {
        for q in poly {
            if q[0] < x0 { x0 = q[0]; }
            if q[0] > x1 { x1 = q[0]; }
            if q[1] < y0 { y0 = q[1]; }
            if q[1] > y1 { y1 = q[1]; }
        }
    }
    [x0, y0, x1, y1]
}

fn generate(p, ctx) {
    if p.thickness * 4.0 > p.height {
        warn("The material is thick for this height");
    }
    let made = #{ panels: [], discs: 0 };
    let lid = p.lid == "Yes";
    if p.base == "Circle" || p.base == "Ellipse" {
        if p.solid == "Pyramid" || p.solid == "Truncated pyramid" {
            made = cone_panels(p);
        } else {
            made = cylinder_panels(p);
        }
    } else {
        let pts = base_polygon(p);
        if pts.len() == 0 {
            return [];
        }
        let solid = p.solid;
        if solid == "Truncated pyramid" {
            warn("A truncated pyramid stands on a circle or an ellipse only: a pyramid is made");
            solid = "Pyramid";
        }
        if solid == "Pyramid" && p.base != "Triangle" && p.base != "Rectangle" {
            warn("A pyramid stands on a triangle or a rectangle only: a prism is made");
            solid = "Prism";
        }
        if solid == "Pyramid" {
            made = pyramid_solid(pts, p.height, p);
        } else {
            let k = if solid == "Truncated prism" { p.slant / 100.0 } else { 0.0 };
            made = prism_solid(pts, p.height, k, lid, p);
        }
    }

    // The pieces in rows, the rows no wider than the work area.
    let out = [];
    let x = 0.0;
    let y = 0.0;
    let row = 0.0;
    let placed = [];
    let idx = 0;
    for poly in made.panels {
        idx += 1;
        if idx > made.discs && !polygon_is_simple(poly) {
            warn("A piece crosses itself (the fingers are too wide for the edge, or the shape is too flat)");
        }
        let b = box_of([poly]);
        let w = b[2] - b[0];
        let h = b[3] - b[1];
        if x > 0.0 && x + w > ctx.area_w {
            x = 0.0;
            y += row + p.space;
            row = 0.0;
        }
        let moved = [];
        for q in poly {
            moved.push([q[0] - b[0] + x, q[1] - b[1] + y]);
        }
        placed.push(moved);
        x += w + p.space;
        if h > row { row = h; }
    }
    let bb = box_of(placed);
    if bb[2] - bb[0] > ctx.area_w || bb[3] - bb[1] > ctx.area_h {
        warn("The pieces are bigger than the work area: " + (bb[2] - bb[0]).round().to_int() + " x " + (bb[3] - bb[1]).round().to_int() + " mm");
    }
    let dx = ctx.area_w / 2.0 - (bb[0] + bb[2]) / 2.0;
    let dy = ctx.area_h / 2.0 - (bb[1] + bb[3]) / 2.0;
    for poly in placed {
        let pl = [];
        for q in poly {
            pl.push([q[0] + dx, q[1] + dy]);
        }
        let s = polygon(pl);
        s.layer = p.cut_layer.to_int();
        out.push(s);
    }
    [group(out)]
}
