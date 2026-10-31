// Barcodes as rectangles: Code 39, Code 128 and EAN-13. Bars are `narrow` mm wide at the narrowest.
// Each of the bar patterns below is a list of widths (bar, space, bar, …) in modules.

fn code39_pattern(ch) {
    let chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%*";
    let pats = ["000110100", "100100001", "001100001", "101100000", "000110001", "100110000", "001110000", "000100101", "100100100", "001100100",
        "100001001", "001001001", "101001000", "000011001", "100011000", "001011000", "000001101", "100001100", "001001100", "000011100",
        "100000011", "001000011", "101000010", "000010011", "100010010", "001010010", "000000111", "100000110", "001000110", "000010110",
        "110000001", "011000001", "111000000", "010010001", "110010000", "011010000", "010000101", "110000100", "011000100", "010101000",
        "010100010", "010001010", "000101010", "010010100"];
    let i = chars.index_of(ch);
    if i < 0 { return (); }
    pats[i]
}

// Code 39: returns the widths in modules (a wide element is 2.5 modules), or () for a character the code does not have.
fn code39(text) {
    let s = "*" + text.to_upper() + "*";
    let w = [];
    for n in 0..s.len() {
        let p = code39_pattern(s.sub_string(n, 1));
        if p == () { return (); }
        for k in 0..9 { w.push(if p.sub_string(k, 1) == "1" { 2.5 } else { 1.0 }); }
        if n + 1 < s.len() { w.push(1.0); }
    }
    w
}

fn code128_table() {
    ["212222","222122","222221","121223","121322","131222","122213","122312","132212","221213","221312","231212","112232","122132","122231","113222","123122","123221","223211","221132","221231","213212","223112","312131","311222","321122","321221","312212","322112","322211","212123","212321","232121","111323","131123","131321","112313","132113","132311","211313","231113","231311","112133","112331","132131","113123","113321","133121","313121","211331","231131","213113","213311","213131","311123","311321","331121","312113","312311","332111","314111","221411","431111","111224","111422","121124","121421","141122","141221","112214","112412","122114","122411","142112","142211","241211","221114","413111","241112","134111","111242","121142","121241","114212","124112","124211","411212","421112","421211","212141","214121","412121","111143","111341","131141","114113","114311","411113","411311","113141","114131","311141","411131","211412","211214","211232","2331112"]
}

// Code 128: subset C for an even number of digits, otherwise subset B (characters 32 to 126). () when a character does not fit.
fn code128(text) {
    let t = code128_table();
    let all_digits = text.len() >= 2 && text.len() % 2 == 0;
    for n in 0..text.len() {
        let c = text.sub_string(n, 1);
        if c < "0" || c > "9" { all_digits = false; }
    }
    let values = [];
    if all_digits {
        values.push(105);
        for n in range(0, text.len(), 2) { values.push(parse_int(text.sub_string(n, 2))); }
    } else {
        values.push(104);
        let printable = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
        for n in 0..text.len() {
            let i = printable.index_of(text.sub_string(n, 1));
            if i < 0 { return (); }
            values.push(i);
        }
    }
    let sum = values[0];
    for i in 1..values.len() { sum += i * values[i]; }
    values.push(sum % 103);
    values.push(106);
    let w = [];
    for v in values {
        let p = t[v];
        for k in 0..p.len() { w.push(parse_int(p.sub_string(k, 1)).to_float()); }
    }
    w
}

// EAN-13 from 12 digits (the check digit is added) or 13 (it is checked): the widths in modules, or () when it is not right.
fn ean13(text) {
    if text.len() != 12 && text.len() != 13 { return (); }
    let d = [];
    for n in 0..text.len() {
        let c = text.sub_string(n, 1);
        if c < "0" || c > "9" { return (); }
        d.push(parse_int(c));
    }
    let sum = 0;
    for i in 0..12 { sum += d[i] * (if i % 2 == 0 { 1 } else { 3 }); }
    let check = (10 - sum % 10) % 10;
    if d.len() == 13 && d[12] != check { return (); }
    if d.len() == 12 { d.push(check); }
    let l = ["0001101","0011001","0010011","0111101","0100011","0110001","0101111","0111011","0110111","0001011"];
    let parity = ["LLLLLL","LLGLGG","LLGGLG","LLGGGL","LGLLGG","LGGLLG","LGGGLL","LGLGLG","LGLGGL","LGGLGL"];
    let bits = "101";
    for i in 1..7 {
        let code = l[d[i]];
        if parity[d[0]].sub_string(i - 1, 1) == "G" {
            // G is the L code read backwards with the bars and spaces swapped: the R code reversed.
            let r = "";
            for k in 0..7 { r += if code.sub_string(k, 1) == "1" { "0" } else { "1" }; }
            let g = "";
            for k in 0..7 { g += r.sub_string(6 - k, 1); }
            bits += g;
        } else {
            bits += code;
        }
    }
    bits += "01010";
    for i in 7..13 {
        let code = l[d[i]];
        for k in 0..7 { bits += if code.sub_string(k, 1) == "1" { "0" } else { "1" }; }
    }
    bits += "101";
    // The runs of equal bits are the widths, starting with a bar.
    let w = [];
    let run = 1;
    for k in 1..bits.len() {
        if bits.sub_string(k, 1) == bits.sub_string(k - 1, 1) { run += 1; } else { w.push(run.to_float()); run = 1; }
    }
    w.push(run.to_float());
    w
}

fn generate(p, ctx) {
    let text = p.text;
    let w = if p.kind == "Code 39" { code39(text) } else if p.kind == "Code 128" { code128(text) } else { ean13(text) };
    if w == () {
        warn("This text cannot be written as " + p.kind + (if p.kind == "EAN-13" { " (12 or 13 digits, the check digit is checked)." } else if p.kind == "Code 39" { " (capitals, digits and - . $ / + % and spaces)." } else { " (characters from space to ~)." }));
        return [];
    }
    let total = 0.0;
    for v in w { total += v; }
    let m = p.narrow;
    // Quiet zone of 10 modules on each side is left empty; the code stands in the middle of the work area.
    let x = (ctx.area_w - total * m) / 2.0;
    let y = (ctx.area_h - p.height) / 2.0;
    let out = [];
    let bar = true;
    for v in w {
        if bar {
            let r = rect(x, y, v * m, p.height);
            r.layer = p.layer.to_int();
            out.push(r);
        }
        x += v * m;
        bar = !bar;
    }
    out
}
