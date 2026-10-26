# Opening this project in Vivado on Windows

Everything needed is in the repository; nothing is pre-built, so the project
regenerates cleanly on any machine and any Vivado version from 2019.1 onward.

## 1. Get the files onto the Windows PC

```
git clone <this repo>
```

or download the ZIP and extract it. Note the path, e.g. `C:\work\Advance_VLSI_Architecture`.

## 2. Create the Vivado project

Start Vivado, and in the **Tcl Console** at the bottom of the window:

```tcl
cd {C:/work/Advance_VLSI_Architecture}
source vivado/create_project.tcl
```

Use forward slashes and braces in the `cd`, as shown — that is Tcl syntax, not
a typo.

Alternatively, from the *Vivado HLx Command Prompt*:

```
cd C:\work\Advance_VLSI_Architecture
vivado -mode batch -source vivado/create_project.tcl
```

The project is written to `vivado/simd_exec/simd_exec.xpr`. Open that file on
later visits instead of re-running the script.

The default part is **xc7a35tcpg236-1** (Artix-7 35T, the Basys-3 part), which
is in the free WebPACK device set. To target something else, set the
environment variable `SIMD_PART` before launching Vivado, e.g.
`set SIMD_PART=xc7a100tcsg324-1`.

## 3. What you can look at

### Schematics — *RTL ANALYSIS → Open Elaborated Design*

Gives the pre-synthesis schematic. Expand `u_exec` to walk down into the
selected variant, then into `u_mul`, `u_add` and `u_eq`. The Dadda tree in
variant 4 is worth opening: the compressor stages are visible as rows of `fa`
and `ha` instances.

*SYNTHESIS → Open Synthesized Design → Schematic* shows the same thing after
technology mapping, in LUTs and CARRY4 chains.

### Waveforms — *SIMULATION → Run Simulation → Run Behavioral Simulation*

The default simulation set is `sim_1`, which runs `tb_simd_wave`. It applies
24 labelled stimuli covering every operating mode and finishes in 250 ns, so
the whole thing fits on one screen. All four variants run side by side; the
transcript prints a line per stimulus and flags any disagreement.

Useful signals to add to the wave window: `A`, `B`, `fn`, `size`, `C4`, `D4`.
Right-click a bus → *Radix → Hexadecimal* to make the values readable.

To run the exhaustive proof instead, switch simulation sets first:

```tcl
current_fileset -simset [get_filesets sim_exhaustive]
launch_simulation
```

That is 524 288 vectors against four variants. XSim will take a while — the
same testbench takes about 13 minutes under Icarus Verilog. It is the real
correctness argument, but you do not need to re-run it to look at waveforms.

To get back to the short one:

```tcl
current_fileset -simset [get_filesets sim_1]
```

### Area and timing — *SYNTHESIS → Run Synthesis*

The default run `synth_1` builds variant 4. Four extra runs, `synth_v1`
through `synth_v4`, are pre-configured, one per variant; pick them from the
*Design Runs* tab.

To synthesise all four and write the comparison tables in one go:

```tcl
source vivado/run_all_synth.tcl
```

This writes utilisation, timing-summary and worst-path reports plus
`summary.csv` and `summary.md` into `results/vivado/`.

## 4. Two things worth knowing before you read the numbers

**The synthesis top is `simd_exec_timed`, not `simd_exec_top`.** The execution
stage is pure combinational logic, so static timing analysis has nothing to
measure it against. `simd_exec_timed` wraps it in input and output registers,
which is both how the block would really sit in a pipeline and what makes the
timing report meaningful. The 27 flip-flops it adds are identical across all
four variants, so LUT counts remain directly comparable.

**All runs pass `-max_dsp 0`.** Without it Vivado maps the `*` operators in
variants 1 and 2 onto hard DSP48 blocks. The multiplier then vanishes from the
LUT count and the area comparison becomes meaningless — variants 1 and 2 would
look dramatically smaller than the structural ones purely because their
multiplier moved into a different kind of silicon. Forcing fabric logic keeps
all four designs on the same footing.

The clock constraint in `vivado/constraints/timing.xdc` is 5.000 ns. Slower
variants will close with negative slack; that is expected and fine. Read the
achievable frequency off as

```
Fmax = 1 / (5.000 ns - WNS)
```

which holds whether the slack is positive or negative.

## 5. FPGA numbers will not match the ASIC numbers in the report

`docs/REPORT.md` characterises the design against a 45 nm standard-cell
library, where area is µm² of gates and delay is a gate-level critical path.
Vivado reports 6-input LUTs and dedicated CARRY4 chains on a fixed FPGA
fabric. The two will rank the variants differently in places — in particular
FPGA carry chains are so fast that ripple-carry structures are penalised far
less on an FPGA than in an ASIC.

That difference is itself a legitimate observation for the report rather than
a problem to hide: the "optimal" architecture depends on the implementation
medium, which is exactly the judgement the assignment asks you to make.
