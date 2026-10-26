#!/usr/bin/env python3
"""
run_blocks.py - characterise the individual arithmetic building blocks.

The top-level numbers from run_asic.py say which variant wins; these numbers
say WHY.  Each adder, multiplier and comparator is synthesised on its own so
the critical path of the full execution stage can be attributed to a specific
sub-block.

Usage:  python3 -I synth/run_blocks.py [--lib /path/to/liberty.lib]
"""

import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESULTS = os.path.join(ROOT, "results", "asic")
NAND2_AREA = 0.798

LIBFILES = [
    "rtl/lib/prim.v", "rtl/lib/adder_rca.v", "rtl/lib/adder_ks.v",
    "rtl/lib/add_simd_rca.v", "rtl/lib/add_simd_csel.v",
    "rtl/lib/eq_simd.v", "rtl/lib/mult_simd_array.v",
    "rtl/lib/mult_simd_dadda.v",
]

BLOCKS = [
    ("add_simd_rca",    "SIMD adder, ripple carry"),
    ("add_simd_csel",   "SIMD adder, carry select"),
    ("eq_simd",         "SIMD equality comparator"),
    ("mult_simd_array", "SIMD multiplier, shift-add array"),
    ("mult_simd_dadda", "SIMD multiplier, Dadda + Kogge-Stone"),
]

ABC_DELAY = ("+strash;dch,-f;map,-B,0.9;topo;stime,-c;"
             "buffer,-c;upsize,-c;dnsize,-c;stime,-c")
ABC_AREA = "+strash;dch,-f;map,-a;topo;stime,-c"


def run(top, lib, abc):
    files = " ".join(os.path.join(ROOT, f) for f in LIBFILES)
    script = """
read_verilog {files}
hierarchy -top {top}
flatten
proc
opt -full
techmap
opt -full
abc -liberty {lib} -script {abc}
opt_clean
stat -liberty {lib}
""".format(files=files, top=top, lib=lib, abc=abc)

    p = subprocess.run(["yosys", "-p", script], capture_output=True, text=True)
    log = p.stdout + p.stderr
    if p.returncode != 0:
        sys.stderr.write(log[-3000:])
        raise SystemExit("yosys failed for %s" % top)

    area = float(re.search(
        r"Chip area for module '\\%s':\s+([\d.]+)" % top, log).group(1))
    cells = int(re.search(r"Number of cells:\s+(\d+)", log).group(1))
    delay = float(re.findall(r"Delay =\s*([\d.]+)\s*ps", log)[-1])
    return cells, area, delay


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lib", default="/tmp/pdk/ng45.lib")
    args = ap.parse_args()
    if not os.path.isfile(args.lib):
        raise SystemExit("Liberty file not found: %s" % args.lib)

    os.makedirs(RESULTS, exist_ok=True)
    rows = []
    for top, desc in BLOCKS:
        ca, aa, da = run(top, args.lib, ABC_AREA)
        cd, ad, dd = run(top, args.lib, ABC_DELAY)
        print("%-18s area-opt: %6.1f um2 %7.1f ps | delay-opt: %6.1f um2 %7.1f ps"
              % (top, aa, da, ad, dd))
        rows.append((top, desc, ca, aa, da, cd, ad, dd))

    with open(os.path.join(RESULTS, "blocks.csv"), "w") as f:
        f.write("block,description,cells_area,area_um2_area,delay_ps_area,"
                "cells_delay,area_um2_delay,delay_ps_delay\n")
        for r in rows:
            f.write("%s,\"%s\",%d,%.3f,%.1f,%d,%.3f,%.1f\n" % r)

    with open(os.path.join(RESULTS, "blocks.md"), "w") as f:
        f.write("| Block | Area-opt area (um^2) | Area-opt delay (ps) | "
                "Delay-opt area (um^2) | Delay-opt delay (ps) | GE (area-opt) |\n")
        f.write("|---|---|---|---|---|---|\n")
        for top, desc, ca, aa, da, cd, ad, dd in rows:
            f.write("| %s | %.1f | %.0f | %.1f | %.0f | %.0f |\n"
                    % (desc, aa, da, ad, dd, aa / NAND2_AREA))

    print("\nwrote %s/blocks.csv and blocks.md" % RESULTS)


if __name__ == "__main__":
    main()
