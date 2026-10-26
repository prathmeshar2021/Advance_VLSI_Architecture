# ---------------------------------------------------------------------------
# build_all.tcl : one-shot - create the project and characterise all variants.
#
#   vivado -mode batch -source vivado/build_all.tcl
# ---------------------------------------------------------------------------
set script_dir [file normalize [file dirname [info script]]]
source "$script_dir/create_project.tcl"
source "$script_dir/run_all_synth.tcl"
