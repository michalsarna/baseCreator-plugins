// Classic fractals as outlines. Every kind is made in its own units, then moved to the corner, scaled to the requested
// width and put in the middle of the work area (or at its top left corner).
//
// Y counts down, like in the drawing. Rhai strings and arrays are values: a function returns what it builds.

// ---- Sierpinski triangle: the smallest triangles that are left ----
fn sierpinski(x, y, s, d) {
    let h = s * 0.8660254037844386;
    if d == 0 {
        return [polygon([[x, y + h], [x + s, y + h], [x + s / 2.0, y]])];
    }
    let half = s / 2.0;
    let out = sierpinski(x, y + h / 2.0, half, d - 1);
    out += sierpinski(x + half, y + h / 2.0, half, d - 1);
    out += sierpinski(x + s / 4.0, y, half, d - 1);
    out
}

// ---- Sierpinski carpet: the squares that are cut out in the middle at every level ----
fn carpet(x, y, s, d) {
    let t = s / 3.0;
    let out = [rect(x + t, y + t, t, t)];
    if d > 1 {
        for i in 0..3 {
            for j in 0..3 {
                if i != 1 || j != 1 {
                    out += carpet(x + t * i.to_float(), y + t * j.to_float(), t, d - 1);
                }
            }
        }
    }
    out
}

// ---- Koch snowflake ----
fn koch(d) {
    let h = 0.8660254037844386;
    // A triangle that goes round clockwise on the screen (Y down), so that the points grow outwards.
    let pts = [[0.0, 0.0], [0.5, -h], [1.0, 0.0]];
    for step in 0..d {
        let next = [];
        for i in 0..pts.len() {
            let a = pts[i];
            let b = pts[(i + 1) % pts.len()];
            let dx = (b[0] - a[0]) / 3.0;
            let dy = (b[1] - a[1]) / 3.0;
            let p1 = [a[0] + dx, a[1] + dy];
            let p2 = [a[0] + 2.0 * dx, a[1] + 2.0 * dy];
            // The tip: the middle third turned by 60 degrees to the outside.
            let c = 0.5;
            let sn = 0.8660254037844386;
            let tip = [p1[0] + dx * c + dy * sn, p1[1] - dx * sn + dy * c];
            next.push(a);
            next.push(p1);
            next.push(tip);
            next.push(p2);
        }
        pts = next;
    }
    [polygon(pts)]
}

// ---- Hilbert curve ----
fn hilbert(order) {
    let n = 1;
    for i in 0..order { n *= 2; }
    let pts = [];
    for d in 0..(n * n) {
        let x = 0;
        let y = 0;
        let t = d;
        let s = 1;
        while s < n {
            let rx = 1 & (t / 2);
            let ry = 1 & (t ^ rx);
            if ry == 0 {
                if rx == 1 {
                    x = s - 1 - x;
                    y = s - 1 - y;
                }
                let tmp = x;
                x = y;
                y = tmp;
            }
            x += s * rx;
            y += s * ry;
            t /= 4;
            s *= 2;
        }
        pts.push([x.to_float(), y.to_float()]);
    }
    [polyline(pts)]
}

// ---- Dragon curve ----
fn dragon(d) {
    // turns(0) = [], turns(n+1) = turns(n) + [1] + reverse(flip(turns(n))).
    let turns = [];
    for i in 0..d {
        let next = turns;
        next.push(1);
        let k = turns.len();
        while k > 0 {
            k -= 1;
            next.push(-turns[k]);
        }
        turns = next;
    }
    let x = 0.0;
    let y = 0.0;
    let dx = 1.0;
    let dy = 0.0;
    let pts = [[x, y]];
    x += dx;
    pts.push([x, y]);
    for t in turns {
        let ndx = -dy * t.to_float();
        let ndy = dx * t.to_float();
        dx = ndx;
        dy = ndy;
        x += dx;
        y += dy;
        pts.push([x, y]);
    }
    [polyline(pts)]
}

// ---- Pythagoras tree ----
fn tree(ax, ay, bx, by, d, ca, sa) {
    // The square stands on the line A to B; "up" is the direction turned by -90 degrees (Y down).
    let ux = bx - ax;
    let uy = by - ay;
    let cx = bx + uy;
    let cy = by - ux;
    let dx = ax + uy;
    let dy = ay - ux;
    let out = [polygon([[ax, ay], [bx, by], [cx, cy], [dx, dy]])];
    if d > 1 {
        // The top of the square is D to C; the triangle on it has its right angle at E.
        let vx = cx - dx;
        let vy = cy - dy;
        // Turn the top edge by the angle towards the outside (up) and shorten it by cos(angle).
        let ex = dx + ca * (vx * ca + vy * sa);
        let ey = dy + ca * (-vx * sa + vy * ca);
        out += tree(dx, dy, ex, ey, d - 1, ca, sa);
        out += tree(ex, ey, cx, cy, d - 1, ca, sa);
    }
    out
}

fn bbox(shapes) {
    let minx = 1.0e30;
    let miny = 1.0e30;
    let maxx = -1.0e30;
    let maxy = -1.0e30;
    for s in shapes {
        if "points" in s {
            for p in s.points {
                if p[0] < minx { minx = p[0]; }
                if p[1] < miny { miny = p[1]; }
                if p[0] > maxx { maxx = p[0]; }
                if p[1] > maxy { maxy = p[1]; }
            }
        } else {
            // rect / ellipse
            if s.x < minx { minx = s.x; }
            if s.y < miny { miny = s.y; }
            if s.x + s.w > maxx { maxx = s.x + s.w; }
            if s.y + s.h > maxy { maxy = s.y + s.h; }
        }
    }
    [minx, miny, maxx, maxy]
}

fn generate(p, ctx) {
    let kind = p.kind;
    let depth = p.depth.to_int();
    // The most steps that still give a drawing a machine can follow.
    let limit = 7;
    if kind == "Sierpinski carpet" { limit = 4; }
    if kind == "Koch snowflake" { limit = 5; }
    if kind == "Hilbert curve" { limit = 7; }
    if kind == "Dragon curve" { limit = 14; }
    if kind == "Pythagoras tree" { limit = 11; }
    if depth > limit {
        warn("depth " + depth + " is too much for " + kind + "; used " + limit);
        depth = limit;
    }
    if depth < 1 { depth = 1; }

    let shapes = [];
    if kind == "Sierpinski triangle" {
        shapes = sierpinski(0.0, 0.0, 100.0, depth - 1);
    } else if kind == "Sierpinski carpet" {
        shapes = [rect(0.0, 0.0, 100.0, 100.0)];
        shapes += carpet(0.0, 0.0, 100.0, depth);
    } else if kind == "Koch snowflake" {
        shapes = koch(depth - 1);
    } else if kind == "Hilbert curve" {
        shapes = hilbert(depth);
    } else if kind == "Dragon curve" {
        shapes = dragon(depth);
    } else {
        let a = p.angle.to_radians();
        shapes = tree(0.0, 0.0, 10.0, 0.0, depth, cos(a), sin(a));
    }

    // Move to the corner, scale to the width, then put it in place.
    let b = bbox(shapes);
    let w = b[2] - b[0];
    let h = b[3] - b[1];
    let k = p.width / w;
    let tx = 0.0;
    let ty = 0.0;
    if p.middle {
        tx = (ctx.area_w - w * k) / 2.0;
        ty = (ctx.area_h - h * k) / 2.0;
    }
    let layer = p.layer.to_int();
    for i in 0..shapes.len() { shapes[i].layer = layer; }
    let g2 = group(shapes);
    g2 = translate(g2, -b[0], -b[1]);
    g2 = scale(g2, k, k);
    g2 = translate(g2, tx, ty);
    [g2]
}
