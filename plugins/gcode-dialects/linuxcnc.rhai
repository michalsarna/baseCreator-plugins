// LinuxCNC: the program between two % lines, path blending, the pause for a change of the bit with a message, and M2 at the end.
fn post(lines, ctx) {
    let out = ["%"];
    let header_done = false;
    for l in lines {
        let t = l;
        t.trim();
        if !header_done && t != "" && !t.starts_with("(") {
            out.push("G17 G21 G90 G94 G40 G49 G80");
            out.push("G64 P0.02");
            header_done = true;
        }
        if t.starts_with("M0 (Change the bit to:") {
            let msg = t.sub_string(3);
            msg.trim();
            out.push("M5");
            out.push("(MSG, " + msg.sub_string(1));
            out.push("M0");
        } else if t == "M30" {
            out.push("M5");
            out.push("M2");
        } else {
            out.push(l);
        }
    }
    out.push("%");
    out
}
