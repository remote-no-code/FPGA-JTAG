# =========================================================
# Task 3A - JTAG IDCODE FPGA Test
# =========================================================

TOP            = top_jtag_idcode
VERILOG_FILE   = jtag_tap.v top_jtag_idcode.v

PCF_FILE       = VSDSquadronFM

FPGA_VARIANT   = up5k
FPGA_PACKAGE   = sg48
BOARD_FREQ     = 12

build:
	yosys -q \
		-p "synth_ice40 -top $(TOP) -json $(TOP).json" \
		$(VERILOG_FILE)

	nextpnr-ice40 \
		--json $(TOP).json \
		--pcf $(PCF_FILE).pcf \
		--asc $(TOP).asc \
		--freq $(BOARD_FREQ) \
		--$(FPGA_VARIANT) \
		--package $(FPGA_PACKAGE)

	icetime \
		-p $(PCF_FILE).pcf \
		-P $(FPGA_PACKAGE) \
		-r $(TOP).timings \
		-d $(FPGA_VARIANT) \
		-t $(TOP).asc

	icepack $(TOP).asc $(TOP).bin

flash:
	iceprog $(TOP).bin

clean:
	rm -f *.json *.asc *.bin *.timings
