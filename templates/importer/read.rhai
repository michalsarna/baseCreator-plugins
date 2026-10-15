// text is the whole file; the function returns shapes. Y counts down from the top of the work area.
fn read(text, ctx) {
    let out = [];
    for raw in text.split('\n') {
        let line = raw;
        line.trim();                    // trim() changes the string itself and returns nothing
        if line == "" || line.starts_with("#") { continue; }
        let f = line.split(' ');
        if f.len() < 4 {
            warn("skipped: " + line);
            continue;
        }
        out.push(rect(parse_float(f[0]), parse_float(f[1]), parse_float(f[2]), parse_float(f[3])));
    }
    out
}
