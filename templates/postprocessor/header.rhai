// lines is an array of strings; return the new lines. Controller commands ($..., ~, !, ?) are refused by the program.
fn post(lines, ctx) {
    let out = ["(made by " + ctx.app + ")"];
    for l in lines { out.push(l); }
    out
}
