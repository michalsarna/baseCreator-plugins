// Mach3 / Mach4 and UCCNC: a safe state at the start, the pause for a change of the bit with a message the controller shows, and
// the spindle off before the program ends.
fn post(lines, ctx) {
    let out = [];
    let header_done = false;
    for l in lines {
        let t = l;
        t.trim();
        // The first line that is not a comment gets the safe modes before it.
        if !header_done && t != "" && !t.starts_with("(") {
            out.push("G17 G21 G90 G94 G40 G49 G80");
            header_done = true;
        }
        if t.starts_with("M0 (Change the bit to:") {
            let msg = t.sub_string(3);
            msg.trim();
            // "(Change the bit to: X)" becomes a message: (MSG, Change the bit to: X)
            out.push("M5");
            out.push("(MSG, " + msg.sub_string(1));
            out.push("M0");
        } else if t == "M30" {
            out.push("M5");
            out.push("M30");
        } else {
            out.push(l);
        }
    }
    out
}
