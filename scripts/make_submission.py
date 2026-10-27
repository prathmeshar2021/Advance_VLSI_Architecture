#!/usr/bin/env python3
"""
make_submission.py - assemble docs/submission.md : the concise report body
plus a compact Verilog appendix taken from the real source files.

The appendix strips the long banner comments and the `default_nettype pragmas
so the code fits the page budget, but keeps the logic and the short inline
comments exactly as synthesised.

Usage:  python3 -I scripts/make_submission.py
"""

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

APPENDIX = [
    ("Top-level selector", "rtl/simd_exec_top.v"),
    ("Shared design, behavioural (V2)", "rtl/simd_exec_v2_shared.v"),
    ("Structural design, fast (V4)", "rtl/simd_exec_v4_struct_fast.v"),
    ("Full adder and half adder", "rtl/lib/prim.v"),
    ("SIMD adder, ripple carry", "rtl/lib/add_simd_rca.v"),
    ("SIMD adder, carry select", "rtl/lib/add_simd_csel.v"),
    ("Equality comparator", "rtl/lib/eq_simd.v"),
    ("SIMD multiplier, shift-add array", "rtl/lib/mult_simd_array.v"),
]


def compact(path):
    """Strip the leading banner comment, pragma lines and dash separators."""
    with open(os.path.join(ROOT, path)) as f:
        lines = f.read().rstrip("\n").split("\n")

    # drop the leading run of blank / comment lines (the file banner)
    i = 0
    while i < len(lines) and (lines[i].strip() == ""
                              or lines[i].lstrip().startswith("//")):
        i += 1
    lines = lines[i:]

    out = []
    for ln in lines:
        s = ln.strip()
        if s.startswith("`default_nettype"):
            continue
        if re.match(r"^//\s*-{3,}\s*$", s):          # pure dash separators
            continue
        out.append(ln.rstrip())

    # collapse runs of blank lines
    res = []
    blank = False
    for ln in out:
        if ln == "":
            if blank:
                continue
            blank = True
        else:
            blank = False
        res.append(ln)
    return "\n".join(res).strip("\n")


def main():
    with open(os.path.join(ROOT, "docs", "submission_body.md")) as f:
        body = f.read().rstrip("\n")

    parts = [body, "", "## Appendix: Verilog source", ""]
    parts.append("The code below is the design as synthesised. The Kogge-Stone "
                 "adder and the Dadda-tree multiplier used by V4 are generated "
                 "building blocks and are included in the submitted project "
                 "files.")
    parts.append("")
    for title, path in APPENDIX:
        parts.append("### %s" % title)
        parts.append("")
        parts.append("```verilog")
        parts.append(compact(path))
        parts.append("```")
        parts.append("")

    dest = os.path.join(ROOT, "docs", "submission.md")
    with open(dest, "w") as f:
        f.write("\n".join(parts).rstrip("\n") + "\n")
    print("wrote docs/submission.md (%d lines)" % sum(1 for _ in open(dest)))


if __name__ == "__main__":
    main()
