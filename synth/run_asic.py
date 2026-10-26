#!/usr/bin/env python3
"""
run_asic.py - standard-cell characterisation of the four SIMD execution-stage
variants using Yosys + ABC against the Nangate 45 nm Open Cell Library.

Each variant is mapped twice:

  area   : ABC "map -a"   - area-oriented technology mapping
  delay  : ABC "map -B 0.9" followed by buffering and gate up/down-sizing
           - delay-oriented mapping

Mapping every variant under BOTH targets is what makes the comparison honest:
a design that wins on area under an area-oriented tool may still be the wrong
choice once the tool is told to chase frequency, and vice versa.

Outputs (under results/asic/):
    summary.csv   machine readable
    summary.md    table for the report
    log_v<n>_<target>.txt   full Yosys transcript for each run

Usage:  python3 -I synth/run_asic.py [--lib /path/to/liberty.lib]
"""

import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESULTS = os.path.join(ROOT, "results", "asic")

# Nangate45 NAND2_X1 cell area - the gate-equivalent (GE) unit.
NAND2_AREA = 0.798

VARIANTS = {
    1: "V1 naive behavioural",
    2: "V2 shared behavioural",
    3: "V3 structural RCA + array",
    4: "V4 structural CSel + Dadda",
}

# ABC command strings.  Commas become spaces, ';' separates commands.
ABC_SCRIPTS = {
    "area":  "+strash;dch,-f;map,-a;topo;stime,-c",
    "delay": "+strash;dch,-f;map,-B,0.9;topo;stime,-c;"
             "buffer,-c;upsize,-c;dnsize,-c;stime,-c",
}


def run_one(variant, target, lib):
    """Synthesise one variant under one optimisation target."""
    script = """
read_verilog {root}/rtl/lib/adder_ks.v {root}/rtl/lib/adder_rca.v \
             {root}/rtl/lib/add_simd_csel.v {root}/rtl/lib/add_simd_rca.v \
             {root}/rtl/lib/eq_simd.v {root}/rtl/lib/mult_simd_array.v \
             {root}/rtl/lib/mult_simd_dadda.v {root}/rtl/lib/prim.v
read_verilog {root}/rtl/simd_exec_v1_naive.v {root}/rtl/simd_exec_v2_shared.v \
             {root}/rtl/simd_exec_v3_struct_rca.v \
             {root}/rtl/simd_exec_v4_struct_fast.v {root}/rtl/simd_exec_top.v
hierarchy -top simd_exec_top -chparam VARIANT {v}
flatten
proc
opt -full
techmap
opt -full
abc -liberty {lib} -script {abc}
opt_clean
stat -liberty {lib}
""".format(root=ROOT, v=variant, lib=lib, abc=ABC_SCRIPTS[target])

    proc = subprocess.run(["yosys", "-p", script],
                          capture_output=True, text=True)
    log = proc.stdout + proc.stderr
    if proc.returncode != 0:
        sys.stderr.write(log[-3000:])
        raise SystemExit("yosys failed for variant %d / %s" % (variant, target))

    os.makedirs(RESULTS, exist_ok=True)
    with open(os.path.join(RESULTS, "log_v%d_%s.txt" % (variant, target)), "w") as f:
        f.write(log)

    # --- parse -------------------------------------------------------------
    m = re.search(r"Chip area for module '\\simd_exec_top':\s+([\d.]+)", log)
    if not m:
        raise SystemExit("could not find chip area (v%d/%s)" % (variant, target))
    area = float(m.group(1))

    m = re.search(r"Number of cells:\s+(\d+)", log)
    cells = int(m.group(1))

    # the LAST stime line is the final timed netlist
    delays = re.findall(r"Delay =\s*([\d.]+)\s*ps", log)
    if not delays:
        raise SystemExit("could not find delay (v%d/%s)" % (variant, target))
    delay_ps = float(delays[-1])

    # per-cell-type histogram, for the report
    hist = dict(re.findall(r"^\s+([A-Z][A-Z0-9_]+_X\d+)\s+(\d+)$", log, re.M))

    return {
        "variant": variant,
        "target": target,
        "cells": cells,
        "area_um2": area,
        "ge": area / NAND2_AREA,
        "delay_ps": delay_ps,
        "fmax_mhz": 1.0e6 / delay_ps,
        "hist": hist,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lib", default="/tmp/pdk/ng45.lib",
                    help="Liberty standard-cell library")
    args = ap.parse_args()

    if not os.path.isfile(args.lib):
        raise SystemExit(
            "Liberty file not found: %s\n"
            "Fetch the Nangate45 open cell library, e.g.\n"
            "  curl -L -o ng45.lib https://raw.githubusercontent.com/"
            "The-OpenROAD-Project/OpenROAD/master/test/Nangate45/Nangate45_typ.lib\n"
            "then re-run with --lib ng45.lib" % args.lib)

    rows = []
    for v in sorted(VARIANTS):
        for target in ("area", "delay"):
            print("synthesising variant %d, %s-oriented ..." % (v, target),
                  flush=True)
            r = run_one(v, target, args.lib)
            print("    cells=%-4d area=%8.2f um2 (%6.1f GE)  delay=%7.1f ps"
                  % (r["cells"], r["area_um2"], r["ge"], r["delay_ps"]))
            rows.append(r)

    os.makedirs(RESULTS, exist_ok=True)

    # ---- CSV --------------------------------------------------------------
    with open(os.path.join(RESULTS, "summary.csv"), "w") as f:
        f.write("variant,description,target,cells,area_um2,gate_equivalents,"
                "delay_ps,fmax_mhz\n")
        for r in rows:
            f.write("%d,\"%s\",%s,%d,%.3f,%.1f,%.1f,%.1f\n"
                    % (r["variant"], VARIANTS[r["variant"]], r["target"],
                       r["cells"], r["area_um2"], r["ge"], r["delay_ps"],
                       r["fmax_mhz"]))

    # ---- Markdown ---------------------------------------------------------
    base_area = {}
    for r in rows:
        if r["variant"] == 1:
            base_area[r["target"]] = r["area_um2"]

    with open(os.path.join(RESULTS, "summary.md"), "w") as f:
        for target in ("area", "delay"):
            f.write("\n**%s-oriented mapping**\n\n" % target.capitalize())
            f.write("| Variant | Cells | Area (um^2) | Gate equiv. | "
                    "Delay (ps) | Fmax (MHz) | Area vs V1 |\n")
            f.write("|---|---|---|---|---|---|---|\n")
            for r in rows:
                if r["target"] != target:
                    continue
                rel = 100.0 * r["area_um2"] / base_area[target]
                f.write("| %s | %d | %.1f | %.0f | %.0f | %.0f | %.0f%% |\n"
                        % (VARIANTS[r["variant"]], r["cells"], r["area_um2"],
                           r["ge"], r["delay_ps"], r["fmax_mhz"], rel))

    print("\nwrote %s/summary.csv and summary.md" % RESULTS)


if __name__ == "__main__":
    main()
