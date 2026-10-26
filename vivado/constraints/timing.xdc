# ---------------------------------------------------------------------------
# timing.xdc : constraints for simd_exec_timed
#
# The execution stage is pure combinational logic, so it is wrapped in input
# and output registers (simd_exec_timed) to give static timing analysis
# something to measure.  The clock period below is deliberately aggressive so
# that the slower variants close with NEGATIVE slack - that is fine and in
# fact desirable, because the achievable frequency is then read off as
#
#       Fmax = 1 / (PERIOD - WNS)
#
# which is valid whether the slack is positive or negative.
# ---------------------------------------------------------------------------

create_clock -period 5.000 -name clk -waveform {0.000 2.500} [get_ports clk]

# Budget a small slice of the period to the surrounding logic so the reported
# path is dominated by the execution stage itself.
set_input_delay  -clock clk 0.500 [get_ports {A_in[*] B_in[*] fn_in[*] size_in}]
set_input_delay  -clock clk 0.500 [get_ports rst_n]
set_output_delay -clock clk 0.500 [get_ports {C_out[*] D_out[*]}]

# The reset is asynchronous and is not part of any timed path.
set_false_path -from [get_ports rst_n]
