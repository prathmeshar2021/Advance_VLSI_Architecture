#!/usr/bin/env python3
"""
make_report.py - assemble docs/REPORT.md from the hand-written body plus
source listings pulled straight out of the repository.

Keeping the appendix generated means the listings in the report can never
drift away from the code that was actually simulated and synthesised.

Usage:  python3 -I scripts/make_report.py
"""

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (section heading, [(path, language, max_lines_or_None)])
SECTIONS = [
    ("A.1  Top level and the four variants", [
        ("rtl/simd_exec_top.v", "verilog", None),
        ("rtl/simd_exec_v1_naive.v", "verilog", None),
        ("rtl/simd_exec_v2_shared.v", "verilog", None),
        ("rtl/simd_exec_v3_struct_rca.v", "verilog", None),
        ("rtl/simd_exec_v4_struct_fast.v", "verilog", None),
        ("rtl/simd_exec_timed.v", "verilog", None),
    ]),
    ("A.2  Arithmetic building blocks", [
        ("rtl/lib/prim.v", "verilog", None),
        ("rtl/lib/adder_rca.v", "verilog", None),
        ("rtl/lib/adder_ks.v", "verilog", None),
        ("rtl/lib/add_simd_rca.v", "verilog", None),
        ("rtl/lib/add_simd_csel.v", "verilog", None),
        ("rtl/lib/eq_simd.v", "verilog", None),
        ("rtl/lib/mult_simd_array.v", "verilog", None),
    ]),
    ("A.3  Dadda-tree multiplier (generated)", [
        ("rtl/lib/mult_simd_dadda.v", "verilog", 60),
        ("scripts/gen_dadda.py", "python", None),
    ]),
    ("A.4  Verification", [
        ("tb/tb_simd_exhaustive.v", "verilog", None),
        ("tb/tb_simd_wave.v", "verilog", None),
    ]),
]


def listing(path, lang, max_lines):
    full = os.path.join(ROOT, path)
    with open(full) as f:
        text = f.read().rstrip("\n")
    lines = text.split("\n")
    note = ""
    if max_lines is not None and len(lines) > max_lines:
        kept = lines[:max_lines]
        omitted = len(lines) - max_lines
        kept.append("")
        kept.append("    // ... %d further generated lines omitted ..." % omitted)
        kept.append("    // (the complete file is in the repository; it is")
        kept.append("    //  produced by scripts/gen_dadda.py, listed below)")
        text = "\n".join(kept)
        note = " *(excerpt — %d lines total)*" % len(lines)
    return "### `%s`%s\n\n```%s\n%s\n```\n" % (path, note, lang, text)


def main():
    with open(os.path.join(ROOT, "docs", "report_body.md")) as f:
        body = f.read().rstrip("\n")

    out = [body, ""]
    for heading, files in SECTIONS:
        out.append("## " + heading)
        out.append("")
        for path, lang, maxl in files:
            out.append(listing(path, lang, maxl))

    dest = os.path.join(ROOT, "docs", "REPORT.md")
    with open(dest, "w") as f:
        f.write("\n".join(out).rstrip("\n") + "\n")

    n = sum(1 for _ in open(dest))
    print("wrote docs/REPORT.md (%d lines)" % n)


if __name__ == "__main__":
    main()
