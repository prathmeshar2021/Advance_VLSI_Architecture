# ---------------------------------------------------------------------------
# create_project.tcl : Vivado simulation project for Assignment 2.
#
# No synthesis is required for this assignment; this project is purely for
# running the testbench and viewing the waveform in the Vivado simulator.
#
#   Vivado Tcl console:
#       cd {C:/path/to/Advance_VLSI_Architecture/assignment2}
#       source vivado/create_project.tcl
#   or:
#       vivado -mode batch -source vivado/create_project.tcl
#
# Then: SIMULATION -> Run Simulation -> Run Behavioral Simulation.
# ---------------------------------------------------------------------------
set origin [file normalize [file dirname [info script]]/..]
set proj   simd_mem_sim
set pdir   $origin/vivado/$proj

create_project -force $proj $pdir -part xc7a35tcpg236-1

add_files -norecurse [list \
    $origin/rtl/mem_bank.v \
    $origin/rtl/mem_system.v ]
add_files -fileset sim_1 -norecurse $origin/tb/tb_mem_system.v

set_property top tb_mem_system [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# let the testbench run to its own $finish
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

puts ""
puts "Project created: $pdir/$proj.xpr"
puts "Run: SIMULATION > Run Simulation > Run Behavioral Simulation"
