# ---------------------------------------------------------------------------
# create_project.tcl : build the Vivado project for Assignment 1.
#
# MEL G624 Advanced VLSI Architectures - SIMD execution stage
#
# HOW TO RUN (Windows)
# --------------------
#   Option A - GUI:
#       Start Vivado, then in the Tcl Console at the bottom:
#           cd {C:/path/to/Advance_VLSI_Architecture}
#           source vivado/create_project.tcl
#
#   Option B - command line (Vivado Tcl shell / "Vivado HLx Command Prompt"):
#           cd C:\path\to\Advance_VLSI_Architecture
#           vivado -mode batch -source vivado/create_project.tcl
#
# The project is written to  vivado/simd_exec/simd_exec.xpr
# Open that file to get the schematic viewer, the simulator and the reports.
#
# To target a different board, set the environment variable SIMD_PART before
# running, e.g.  set SIMD_PART=xc7a100tcsg324-1
# ---------------------------------------------------------------------------

set script_dir [file normalize [file dirname [info script]]]
set origin_dir [file normalize "$script_dir/.."]

# --- FPGA part -------------------------------------------------------------
# Artix-7 35T (Basys-3) is in the free Vivado WebPACK device set.
set part_name "xc7a35tcpg236-1"
if {[info exists ::env(SIMD_PART)]} {
    set part_name $::env(SIMD_PART)
}

set proj_name "simd_exec"
set proj_dir  "$origin_dir/vivado/$proj_name"

puts "INFO: repository root : $origin_dir"
puts "INFO: target part     : $part_name"
puts "INFO: project dir     : $proj_dir"

create_project -force $proj_name $proj_dir -part $part_name

# --- design sources --------------------------------------------------------
add_files -norecurse [glob "$origin_dir/rtl/lib/*.v"]
add_files -norecurse [glob "$origin_dir/rtl/*.v"]
set_property library xil_defaultlib [get_files -of [get_filesets sources_1]]

# simd_exec_timed is the synthesis top: the registers around the combinational
# stage are what make the timing report meaningful.
set_property top simd_exec_timed [get_filesets sources_1]
update_compile_order -fileset sources_1

# --- constraints -----------------------------------------------------------
add_files -fileset constrs_1 -norecurse "$origin_dir/vivado/constraints/timing.xdc"

# --- simulation set 1 : short, waveform friendly (default) -----------------
add_files -fileset sim_1 -norecurse "$origin_dir/tb/tb_simd_wave.v"
set_property top tb_simd_wave [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1

# --- simulation set 2 : exhaustive proof (slow in XSim, ~400k vectors) -----
if {[llength [get_filesets -quiet sim_exhaustive]] == 0} {
    create_fileset -simset sim_exhaustive
}
add_files -fileset sim_exhaustive -norecurse "$origin_dir/tb/tb_simd_exhaustive.v"
set_property top tb_simd_exhaustive [get_filesets sim_exhaustive]
set_property top_lib xil_defaultlib [get_filesets sim_exhaustive]
update_compile_order -fileset sim_exhaustive

# Let both testbenches run to their own $finish instead of stopping at 1000ns.
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_exhaustive]
# Log every signal so the waveform window is populated without re-running.
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

current_fileset -simset [get_filesets sim_1]

# --- one synthesis run per variant ----------------------------------------
# -max_dsp 0 is ESSENTIAL: without it Vivado maps the "*" operators in
# variants 1 and 2 onto hard DSP48 blocks, the multiplier disappears from the
# LUT count, and the area comparison becomes meaningless.
set synth_flow [get_property FLOW [get_runs synth_1]]

foreach v {1 2 3 4} {
    set rn "synth_v$v"
    if {[llength [get_runs -quiet $rn]]} {
        delete_run $rn
    }
    create_run $rn -flow $synth_flow -constrset constrs_1
    set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
                 -value "-generic VARIANT=$v -max_dsp 0" \
                 -objects [get_runs $rn]
    puts "INFO: created run $rn (VARIANT=$v)"
}

# Point the default run at the recommended variant too, so pressing
# "Run Synthesis" in the GUI does something sensible.
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
             -value "-generic VARIANT=4 -max_dsp 0" \
             -objects [get_runs synth_1]

puts ""
puts "============================================================"
puts " Project created: $proj_dir/$proj_name.xpr"
puts ""
puts " Next steps in the GUI:"
puts "   RTL ANALYSIS  > Open Elaborated Design   -> schematic"
puts "   SIMULATION    > Run Simulation           -> waveform"
puts "   SYNTHESIS     > Run Synthesis            -> VARIANT 4"
puts ""
puts " To characterise all four variants and write the report files:"
puts "   source vivado/run_all_synth.tcl"
puts "============================================================"
