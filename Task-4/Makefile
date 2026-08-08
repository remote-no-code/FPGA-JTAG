# =========================================================
# RISC-V Debug Specification
# VSDSquadron FM
# =========================================================

TOP = SOC
TB  = tb_soc_debug

# ---------------------------------------------------------
# RTL Sources
# ---------------------------------------------------------
RTL = \
	rtl/riscv.v \
	rtl/riscv_jtag_dtm.v \
	rtl/dmi_cdc.v \
	rtl/dmi_interface.v \
	rtl/riscv_debug_module_minimal.v \
	rtl/abstract_access_unit.v \
	rtl/core_debug_adapter.v

# ---------------------------------------------------------
# Simulation Sources
# ---------------------------------------------------------
SIM = \
	sim/tb_soc_debug.v

# ---------------------------------------------------------
# FPGA
# ---------------------------------------------------------
PCF_FILE = rtl/VSDSquadronFM.pcf

FPGA_VARIANT = up5k
FPGA_PACKAGE = sg48
BOARD_FREQ   = 12

LOGDIR = logs

# ---------------------------------------------------------
# Default Target
# ---------------------------------------------------------
all: build

# ---------------------------------------------------------
# Simulation
# ---------------------------------------------------------
sim:
	iverilog -g2012 -DBENCH \
	-I rtl \
	-s tb_soc_debug \
	-o simv \
	rtl/riscv.v \
	rtl/riscv_jtag_dtm.v \
	rtl/dmi_cdc.v \
	rtl/dmi_interface.v \
	rtl/riscv_debug_module_minimal.v \
	rtl/abstract_access_unit.v \
	rtl/core_debug_adapter.v \
	sim/tb_soc_debug.v

run: sim
	vvp simv | tee terminal.txt

wave: run
	gtkwave tb_soc_debug.vcd

# ---------------------------------------------------------
# FPGA Build
# ---------------------------------------------------------
build:
	mkdir -p $(LOGDIR)

	yosys -p "\
    read_verilog $(RTL); \
    hierarchy -check -top $(TOP); \
    synth_ice40 -top $(TOP); \
    stat; \
    write_json $(TOP).json"
	$(RTL) \
	2>&1 | tee $(LOGDIR)/synth.log

	nextpnr-ice40 \
	--$(FPGA_VARIANT) \
	--package $(FPGA_PACKAGE) \
	--json $(TOP).json \
	--pcf $(PCF_FILE) \
	--asc $(TOP).asc \
	--freq $(BOARD_FREQ) \
	2>&1 | tee $(LOGDIR)/pnr.log

	icetime \
	-d $(FPGA_VARIANT) \
	-P $(FPGA_PACKAGE) \
	-p $(PCF_FILE) \
	-r $(TOP).timings \
	-t $(TOP).asc \
	2>&1 | tee $(LOGDIR)/timing.log

	icepack $(TOP).asc $(TOP).bin

# ---------------------------------------------------------
# Program FPGA
# ---------------------------------------------------------
flash:
	mkdir -p $(LOGDIR)
	iceprog $(TOP).bin \
	2>&1 | tee $(LOGDIR)/programming.log

prog: flash

# ---------------------------------------------------------
# Clean
# ---------------------------------------------------------
clean:
	rm -rf \
	simv \
	terminal.txt \
	tb_soc_debug.vcd \
	*.json \
	*.asc \
	*.bin \
	*.timings \
	$(LOGDIR)

