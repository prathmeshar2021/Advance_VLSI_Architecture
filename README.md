# Advance_VLSI_Architecture

**MEL G624 — Advanced VLSI Architectures (Semester I, 2026–27)**
Assignment 1: a SIMD-capable execution stage in Verilog, with synthesis and
characterisation.

---

## What this implements

An execution stage that performs **unsigned addition, unsigned multiplication
or an equality test** on two 8-bit inputs, treating each input either as one
8-bit operand or as **two packed 4-bit operands**, under a 2-bit function
select and a 1-bit size control.

| Signal | Width | Meaning |
|---|---|---|
| `A`, `B` | 8 | operands, unsigned |
| `fn` | 2 | `00` add, `01` multiply, `10` equality, `11` reserved |
| `size` | 1 | `0` = one 8-bit operand, `1` = two packed 4-bit operands |
| `C`, `D` | 8 each | results |

Four design variants are built and measured:

| Variant | Sharing | Arithmetic structure |
|---|---|---|
| V1 naive | none — duplicated units | inferred by the synthesiser |
| V2 shared | full | inferred by the synthesiser |
| V3 structural RCA | full | ripple-carry adder, shift-and-add array multiplier |
| V4 structural fast | full | carry-select adder, Dadda tree + Kogge-Stone adder |

### The key idea

With `A = 16·A_H + A_L` and `B = 16·B_H + B_L`,

```
A × B = 256·(A_H·B_H) + 16·(A_H·B_L + A_L·B_H) + (A_L·B_L)
```

Force the two cross terms to zero and what remains is `256·(A_H·B_H) +
(A_L·B_L)`. Since `A_L·B_L ≤ 225 < 256` the terms occupy disjoint bit ranges,
so the 16-bit product collapses to the concatenation `{A_H·B_H, A_L·B_L}` —
exactly the packed 4-bit SIMD result.

One 8×8 multiplier therefore serves both modes with **no duplicated datapath
and no output multiplexer**; the only cost is that 32 of the 64
partial-product AND gates take `~size` as a third input. Likewise the adder
needs just **one AND gate** to break its carry chain at the nibble boundary.

## Headline results

Verified exhaustively — 524 288 vectors against 4 variants = **2 097 152
comparisons, zero mismatches**.

Synthesised with Yosys + ABC against the Nangate 45 nm open cell library:

| Variant | Area (µm²) | Delay (ps) | Area–delay product |
|---|---|---|---|
| V1 naive | 583.1 | 1056 | 615 955 |
| V2 shared | 469.8 | 1075 | 504 992 |
| V3 structural RCA | **423.7** | 1550 | 656 712 |
| V4 structural fast | 438.9 | **880** | **386 144** |

*(area-oriented mapping; the report also gives delay-oriented numbers)*

- Sharing alone (V1→V2) removes **19 % of the area** for under 2 % delay cost.
- The multiplier is **85–88 % of the area and >90 % of the critical path** —
  optimising the adder is close to wasted effort.
- **V4 is the recommended design**: best area–delay product under both mapping
  targets, fastest overall, within 3.6 % of the minimum-area design.

Full analysis in **[`docs/REPORT.md`](docs/REPORT.md)**.

## Repository layout

```
rtl/
  lib/                    arithmetic building blocks
    prim.v                full adder, half adder
    adder_rca.v           parameterised ripple-carry adder
    adder_ks.v            parameterised Kogge-Stone prefix adder
    add_simd_rca.v        breakable 8-bit adder, ripple carry
    add_simd_csel.v       breakable 8-bit adder, carry select
    eq_simd.v             nibble-wise equality comparator
    mult_simd_array.v     gated partial products, shift-and-add array
    mult_simd_dadda.v     gated partial products, Dadda tree (generated)
  simd_exec_v1_naive.v    variant 1
  simd_exec_v2_shared.v   variant 2
  simd_exec_v3_struct_rca.v
  simd_exec_v4_struct_fast.v
  simd_exec_top.v         VARIANT-parameterised selector
  simd_exec_timed.v       registered wrapper, for timing closure
tb/
  tb_simd_exhaustive.v    524 288 vectors against a golden model
  tb_simd_wave.v          24 labelled stimuli, for waveform inspection
vivado/
  create_project.tcl      builds the Vivado project
  run_all_synth.tcl       synthesises all four variants, writes the tables
  build_all.tcl           both of the above
  constraints/timing.xdc
synth/
  run_asic.py             Yosys + ABC characterisation of the four variants
  run_blocks.py           ... of the individual arithmetic blocks
scripts/
  gen_dadda.py            emits rtl/lib/mult_simd_dadda.v
  make_report.py          assembles docs/REPORT.md with source listings
  make_a4_reference.py    A4 pandoc template
  make_pdf.sh             renders the report to A4 PDF and DOCX
docs/
  REPORT.md / .pdf        the report (full, with Verilog listings)
  REPORT_body.pdf         the report without the listings appendix
  REPORT.docx             editable - fill in name and ID before printing
  VIVADO.md               how to open and drive the project in Vivado
results/asic/             characterisation output (CSV, Markdown, logs)
```

## Running it

### Vivado on Windows — schematics and waveforms

```tcl
cd {C:/path/to/Advance_VLSI_Architecture}
source vivado/create_project.tcl
```

Then *RTL ANALYSIS → Open Elaborated Design* for schematics, *SIMULATION →
Run Simulation* for waveforms, *SYNTHESIS → Run Synthesis* for utilisation and
timing. Full instructions, including the two settings that matter for a fair
comparison, are in [`docs/VIVADO.md`](docs/VIVADO.md).

### Open-source flow — Icarus Verilog + Yosys

```
make lint             # elaboration check
make sim              # short waveform testbench
make wave             # same, dumping a VCD for GTKWave
make sim-exhaustive   # 524 288 vectors x 4 variants (~13 min)
make report           # synthesis + characterisation -> results/asic/
sh scripts/make_pdf.sh   # render the report to A4 PDF and DOCX
```

`make report` downloads the Nangate45 liberty file on first use.

---

## Assignment brief (as issued)

> Please find the details for Assignment 1 of MEL G624 - Advanced VLSI
> Architectures (Semester I, 2026-27) below.
>
> Assignment Issue Date: October 24, 2026
>
> Submission Date: November 3, 2026
>
> Maximum Marks: 10
>
> **Submission Guidelines**
>
> The assignment must be submitted as a hard copy on A4-size paper.
>
> Students must use a neat, properly formatted, and optimized layout, with
> clear headings, appropriate diagrams, tables, and equations wherever
> required.
>
> The submission must be technically sound, well-organized, and concise.
>
> Submit the hard copy in Room 2219-D on November 3, 2026, between 10:30 AM
> and 11:00 AM only.
>
> Please ensure that you submit your assignment within the specified time.
>
> Please note that the evaluation will comprise three assignments (10 marks
> each) and a 3-minute presentation-cum-viva covering all three assignments
> (10 marks).
>
> Best regards,
> Govind Prasad

The full specification is in [`Assignment1.pdf`](Assignment1.pdf).

> **Note on the submission date.** The announcement above says **November 3**;
> `Assignment1.pdf` says **November 4**. Confirm which applies before
> submitting — the earlier date is the safer assumption.
