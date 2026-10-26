# ---------------------------------------------------------------------------
# MEL G624 Advanced VLSI Architectures - Assignment 1
# SIMD execution stage : simulation and standard-cell characterisation
#
# This Makefile drives the open-source flow (Icarus Verilog + Yosys + ABC)
# used to verify the RTL and to produce the numbers in docs/REPORT.md.
# The Vivado flow is separate - see docs/VIVADO.md.
#
#   make lint             syntax/elaboration check of everything
#   make sim              short waveform testbench
#   make wave             same, dumping tb_simd_wave.vcd for GTKWave
#   make sim-exhaustive   all 524288 vectors x 4 variants (~13 min)
#   make lib              download the Nangate45 liberty file
#   make synth            characterise the four variants (area + delay)
#   make blocks           characterise the individual arithmetic blocks
#   make report           synth + blocks
#   make dadda            regenerate rtl/lib/mult_simd_dadda.v
#   make clean
# ---------------------------------------------------------------------------

IVERILOG  ?= iverilog
VVP       ?= vvp
YOSYS     ?= yosys
PYTHON    ?= python3

BUILD     := build
RTL       := $(wildcard rtl/lib/*.v) $(wildcard rtl/*.v)
IVFLAGS   := -g2012 -Wall -Wno-timescale

LIB       ?= $(BUILD)/ng45.lib
LIB_URL   := https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD/master/test/Nangate45/Nangate45_typ.lib

.PHONY: all lint sim wave sim-exhaustive synth blocks report dadda lib clean

all: lint sim

$(BUILD):
	@mkdir -p $(BUILD)

# --- elaboration check -----------------------------------------------------
lint: | $(BUILD)
	$(IVERILOG) $(IVFLAGS) -o $(BUILD)/lint.out $(RTL) tb/tb_simd_wave.v
	@echo "lint: OK"

# --- short, waveform-oriented testbench ------------------------------------
sim: | $(BUILD)
	$(IVERILOG) $(IVFLAGS) -o $(BUILD)/sim_wave.out $(RTL) tb/tb_simd_wave.v
	$(VVP) $(BUILD)/sim_wave.out

wave: | $(BUILD)
	$(IVERILOG) $(IVFLAGS) -DDUMP_VCD -o $(BUILD)/sim_wave.out $(RTL) tb/tb_simd_wave.v
	cd $(BUILD) && $(VVP) sim_wave.out
	@echo "VCD written to $(BUILD)/tb_simd_wave.vcd  (open with: gtkwave $(BUILD)/tb_simd_wave.vcd)"

# --- exhaustive proof ------------------------------------------------------
sim-exhaustive: | $(BUILD)
	$(IVERILOG) $(IVFLAGS) -o $(BUILD)/sim_exh.out $(RTL) tb/tb_simd_exhaustive.v
	$(VVP) $(BUILD)/sim_exh.out

# --- standard cell library -------------------------------------------------
lib: $(LIB)

$(LIB): | $(BUILD)
	@echo "fetching Nangate45 open cell library ..."
	curl -sSL -o $(LIB) "$(LIB_URL)"
	@test -s $(LIB) || (echo "download failed"; rm -f $(LIB); exit 1)
	@echo "liberty file: $(LIB)"

# --- characterisation ------------------------------------------------------
synth: $(LIB)
	$(PYTHON) -I synth/run_asic.py --lib $(LIB)

blocks: $(LIB)
	$(PYTHON) -I synth/run_blocks.py --lib $(LIB)

report: synth blocks
	@echo ""
	@echo "Tables written to results/asic/ - paste summary.md and blocks.md"
	@echo "into docs/REPORT.md."

# --- generated RTL ---------------------------------------------------------
dadda:
	$(PYTHON) -I scripts/gen_dadda.py

clean:
	rm -rf $(BUILD)
	rm -f *.vcd
