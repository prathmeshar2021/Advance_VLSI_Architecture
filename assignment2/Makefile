# ---------------------------------------------------------------------------
# MEL G624 Advanced VLSI Architectures - Assignment 2
# Interleaved data memory system - simulation (Icarus Verilog)
#
#   make sim    compile and run both test cases, writing the transcript
#   make wave   same, and open the VCD in GTKWave
#   make clean
# ---------------------------------------------------------------------------
IVERILOG ?= iverilog
VVP      ?= vvp
RTL      := rtl/mem_bank.v rtl/mem_system.v
TB       := tb/tb_mem_system.v
IVFLAGS  := -g2012 -Wall -Wno-timescale

.PHONY: sim wave clean
sim:
	$(IVERILOG) $(IVFLAGS) -o sim/sim.out $(RTL) $(TB)
	cd sim && $(VVP) sim.out | tee ../results/sim_transcript.txt

wave: sim
	gtkwave sim/tb_mem_system.vcd &

clean:
	rm -f sim/sim.out sim/*.vcd
