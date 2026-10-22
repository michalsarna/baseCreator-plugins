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
