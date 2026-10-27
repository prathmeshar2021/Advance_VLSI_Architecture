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
    ("Shared design, written with operators (V2)", "rtl/simd_exec_v2_shared.v"),
    ("Full adder and half adder", "rtl/lib/prim.v"),
    ("Ripple-carry adder", "rtl/lib/adder_rca.v"),
    ("Breakable SIMD adder", "rtl/lib/add_simd_rca.v"),
    ("Equality comparator", "rtl/lib/eq_simd.v"),
    ("SIMD multiplier (gated partial products)", "rtl/lib/mult_simd_array.v"),
    ("Structural design that connects the blocks (V3)",
     "rtl/simd_exec_v3_struct_rca.v"),
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

    parts = [body, "", "## Appendix: Verilog code", ""]
    parts.append("The first module is the shared design written with the +, "
                 "\\* and == operators (V2). The next modules are the "
                 "gate-level building blocks, followed by the structural "
                 "design that connects them (V3). The faster design (V4) "
                 "replaces the ripple-carry adder with a carry-select adder "
                 "and the array multiplier with a Dadda-tree multiplier; both "
                 "use the same carry-breaking and cross-term gating shown "
                 "here, and are standard structures.")
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
