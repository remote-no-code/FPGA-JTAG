# =========================================================
# Task 3C - Step 1
# JTAG TAP + Dummy Debug Registers
# =========================================================

TOP = SOC

VERILOG_FILES = \
	jtag_tap.v \
	jtag_debug_cdc.v \
	riscv.v

PCF_FILE = VSDSquadronFM

FPGA_VARIANT = up5k
FPGA_PACKAGE = sg48
BOARD_FREQ = 12

LOGDIR = logs

all: build

build:
	mkdir -p $(LOGDIR)

	yosys \
		-p "synth_ice40 -top $(TOP) -json $(TOP).json" \
		$(VERILOG_FILES) \
		2>&1 | tee $(LOGDIR)/synth.log

	nextpnr-ice40 \
		--$(FPGA_VARIANT) \
		--package $(FPGA_PACKAGE) \
		--json $(TOP).json \
		--pcf $(PCF_FILE).pcf \
		--asc $(TOP).asc \
		--freq $(BOARD_FREQ) \
		2>&1 | tee $(LOGDIR)/pnr.log

	icetime \
		-d $(FPGA_VARIANT) \
		-P $(FPGA_PACKAGE) \
		-p $(PCF_FILE).pcf \
		-r $(TOP).timings \
		-t $(TOP).asc \
		2>&1 | tee $(LOGDIR)/timing.log

	icepack $(TOP).asc $(TOP).bin

flash:
	mkdir -p $(LOGDIR)
	iceprog $(TOP).bin \
		2>&1 | tee $(LOGDIR)/programming.log

prog: flash

clean:
	rm -rf *.json *.asc *.bin *.timings $(LOGDIR)
