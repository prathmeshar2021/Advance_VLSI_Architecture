#!/usr/bin/env python3
"""
make_submission.py - assemble assignment2/docs/submission.md : the report body
plus a compact, well-commented Verilog appendix taken from the real sources.
"""
import os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (title, path) for files included whole
WHOLE = [
    ("Memory bank (mem_bank.v)", "rtl/mem_bank.v"),
    ("Memory system (mem_system.v)", "rtl/mem_system.v"),
]

def compact(text):
    """Drop the pragma lines and pure-dash separator comments; keep the rest."""
    out = []
    for ln in text.rstrip("\n").split("\n"):
        s = ln.strip()
        if s.startswith("`timescale") or s.startswith("`default_nettype"):
            continue
        if re.match(r"^//\s*=+\s*$", s) or re.match(r"^//\s*-{3,}\s*$", s):
            continue
        out.append(ln.rstrip())
    # collapse blank runs
    res, blank = [], False
    for ln in out:
        if ln == "":
            if blank:
                continue
            blank = True
        else:
            blank = False
        res.append(ln)
    return "\n".join(res).strip("\n")

def compact_file(path):
    with open(os.path.join(ROOT, path)) as f:
        return compact(f.read())

def tb_excerpt():
    """Extract the processor-model section from the testbench."""
    with open(os.path.join(ROOT, "tb/tb_mem_system.v")) as f:
        t = f.read()
    start = t.index("    // Processor stimulus: drive req")
    end = t.index("    // defensive check")
    # back up to the comment banner line before 'defensive check'
    end = t.rindex("\n", 0, end)
    end = t.rindex("\n", 0, end)  # drop the separator line too
    return compact(t[start:end])

def main():
    with open(os.path.join(ROOT, "docs", "submission_body.md")) as f:
        body = f.read().rstrip("\n")

    parts = [body, "", "## Appendix: Verilog code", ""]
    parts.append("The memory bank and the memory system below are the complete, "
                 "commented model. The testbench processor model that drives the "
                 "two test cases follows; it issues one read per cycle and holds "
                 "the access whenever stall is high.")
    parts.append("")
    for title, path in WHOLE:
        parts.append("### " + title)
        parts.append("")
        parts.append("```verilog")
        parts.append(compact_file(path))
        parts.append("```")
        parts.append("")
    parts.append("### Testbench, processor model (tb_mem_system.v)")
    parts.append("")
    parts.append("```verilog")
    parts.append(tb_excerpt())
    parts.append("```")
    parts.append("")

    dest = os.path.join(ROOT, "docs", "submission.md")
    with open(dest, "w") as f:
        f.write("\n".join(parts).rstrip("\n") + "\n")
    print("wrote docs/submission.md (%d lines)" % sum(1 for _ in open(dest)))

if __name__ == "__main__":
    main()
