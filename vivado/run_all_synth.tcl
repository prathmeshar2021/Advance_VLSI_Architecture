# ---------------------------------------------------------------------------
# run_all_synth.tcl : synthesise all four variants and characterise them.
#
# Run this AFTER create_project.tcl, with the project open:
#       source vivado/run_all_synth.tcl
#
# Produces, under results/vivado/ :
#       util_v<n>.txt      full utilisation report
#       timing_v<n>.txt    timing summary
#       paths_v<n>.txt     ten worst paths
#       summary.csv        machine-readable comparison table
#       summary.md         the table to paste into the report
#
# All four runs use -max_dsp 0 so the multipliers stay in fabric logic and the
# area comparison means something.
# ---------------------------------------------------------------------------

set script_dir [file normalize [file dirname [info script]]]
set origin_dir [file normalize "$script_dir/.."]
set rpt_dir    "$origin_dir/results/vivado"
file mkdir $rpt_dir

# Clock period declared in vivado/constraints/timing.xdc
set period 5.000

set names(1) "V1 naive behavioural"
set names(2) "V2 shared behavioural"
set names(3) "V3 structural RCA + array"
set names(4) "V4 structural CSel + Dadda"

set rows {}

foreach v {1 2 3 4} {
    set rn "synth_v$v"
    puts "\n================ synthesising $rn : $names($v) ================"

    reset_run  $rn
    launch_runs $rn -jobs 4
    wait_on_run $rn

    if {[get_property PROGRESS [get_runs $rn]] != "100%"} {
        error "run $rn did not complete - check the run log"
    }

    open_run $rn -name "netlist_v$v"

    report_utilization    -file "$rpt_dir/util_v$v.txt"
    report_timing_summary -file "$rpt_dir/timing_v$v.txt"
    report_timing -delay_type max -max_paths 10 -nworst 10 \
                  -file "$rpt_dir/paths_v$v.txt"

    # ---- primitive counts ------------------------------------------------
    set n_lut   [llength [get_cells -hier -quiet -filter {PRIMITIVE_GROUP == LUT}]]
    set n_ff    [llength [get_cells -hier -quiet -filter {PRIMITIVE_GROUP == FLOP_LATCH}]]
    set n_carry [llength [get_cells -hier -quiet -filter {PRIMITIVE_GROUP == CARRY}]]
    set n_mux   [llength [get_cells -hier -quiet -filter {PRIMITIVE_GROUP == MUXFX}]]
    set n_dsp   [llength [get_cells -hier -quiet -filter {PRIMITIVE_GROUP == DSP}]]

    # ---- worst setup path ------------------------------------------------
    set path [lindex [get_timing_paths -delay_type max_rise_fall -max_paths 1 -nworst 1] 0]
    set wns     [get_property SLACK          $path]
    set levels  [get_property LOGIC_LEVELS   $path]
    set dpath   [get_property DATAPATH_DELAY $path]

    # Fmax is valid for positive and negative slack alike.
    set fmax [expr {1000.0 / ($period - $wns)}]

    if {$n_dsp > 0} {
        puts "WARNING: $rn inferred $n_dsp DSP block(s) - the area comparison"
        puts "         is distorted.  Check that -max_dsp 0 is in effect."
    }

    puts [format "  LUT=%d  FF=%d  CARRY=%d  MUX=%d  DSP=%d" \
                 $n_lut $n_ff $n_carry $n_mux $n_dsp]
    puts [format "  WNS=%.3f ns  logic levels=%d  datapath=%.3f ns  Fmax=%.1f MHz" \
                 $wns $levels $dpath $fmax]

    lappend rows [list $v $names($v) $n_lut $n_ff $n_carry $n_mux $n_dsp \
                       $wns $levels $dpath $fmax]

    close_design
}

# ------------------------------------------------------------------ CSV ---
set fh [open "$rpt_dir/summary.csv" w]
puts $fh "variant,description,luts,ffs,carry8,muxfx,dsp,wns_ns,logic_levels,datapath_ns,fmax_mhz"
foreach r $rows {
    puts $fh [format "%s,\"%s\",%s,%s,%s,%s,%s,%.3f,%s,%.3f,%.1f" \
        [lindex $r 0] [lindex $r 1] [lindex $r 2] [lindex $r 3] [lindex $r 4] \
        [lindex $r 5] [lindex $r 6] [lindex $r 7] [lindex $r 8] [lindex $r 9] \
        [lindex $r 10]]
}
close $fh

# ------------------------------------------------------------- markdown ---
set fh [open "$rpt_dir/summary.md" w]
puts $fh "| Variant | LUTs | FFs | CARRY4 | Logic levels | Datapath (ns) | WNS (ns) | Fmax (MHz) |"
puts $fh "|---|---|---|---|---|---|---|---|"
foreach r $rows {
    puts $fh [format "| %s | %s | %s | %s | %s | %.3f | %.3f | %.1f |" \
        [lindex $r 1] [lindex $r 2] [lindex $r 3] [lindex $r 4] \
        [lindex $r 8] [lindex $r 9] [lindex $r 7] [lindex $r 10]]
}
close $fh

puts "\n============================================================"
puts " Reports written to results/vivado/"
puts "   summary.csv / summary.md  <- the comparison table"
puts "============================================================"
