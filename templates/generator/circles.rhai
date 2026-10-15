// p holds the values of the form, ctx the program and the size of the work area (mm, Y down).
fn generate(p, ctx) {
    let n = p.count.to_int();          // numbers arrive as floats
    let d = p.diameter;
    let step = d + p.gap;
    let total = step * n.to_float() - p.gap;
    let x0 = (ctx.area_w - total) / 2.0;
    let y = ctx.area_h / 2.0;
    let out = [];
    for i in 0..n {
        let c = circle(x0 + d / 2.0 + step * i.to_float(), y, d / 2.0);
        c.layer = p.layer.to_int();
        out.push(c);
    }
    out
}
