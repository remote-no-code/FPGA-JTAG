`timescale 1ns/1ps

module tb_jtag_idcode;

reg tck;
reg tms;
reg tdi;
reg trst;

wire tdo;

jtag_tap dut (
    .tck(tck),
    .tms(tms),
    .tdi(tdi),
    .trst(trst),
    .tdo(tdo),

    .debug_halt_req(),
    .debug_resume_req(),
    .debug_reset_req(),

    .debug_halted(1'b0),
    .debug_pc(32'h0)
);

initial begin
    tck = 0;
    forever #5 tck = ~tck;
end

task jtag_cycle;
input tms_i;
input tdi_i;
begin
    @(negedge tck);
    tms = tms_i;
    tdi = tdi_i;
    @(posedge tck);
end
endtask

integer i;
reg [31:0] idcode;

initial begin

    $dumpfile("jtag_idcode.vcd");
    $dumpvars(0,tb_jtag_idcode);

    tms  = 1;
    tdi  = 0;
    trst = 1;

    #20;
    trst = 0;

    // Force TAP reset
    repeat(6)
        jtag_cycle(1,0);

    // Idle
    jtag_cycle(0,0);

    //--------------------------------------------------
    // SHIFT IR
    //--------------------------------------------------

    jtag_cycle(1,0); // Select DR
    jtag_cycle(1,0); // Select IR
    jtag_cycle(0,0); // Capture IR
    jtag_cycle(0,0); // Shift IR

    // Try loading IDCODE = 0001

    jtag_cycle(0,1);
    jtag_cycle(0,0);
    jtag_cycle(0,0);
    jtag_cycle(1,0);

    jtag_cycle(1,0); // Update IR
    jtag_cycle(0,0); // Idle

    #20;

    $display("IR loaded = %b", dut.ir);

    //--------------------------------------------------
    // SHIFT DR
    //--------------------------------------------------

    jtag_cycle(1,0); // Select DR
    jtag_cycle(0,0); // Capture DR
    jtag_cycle(0,0); // Shift DR
    #1;
    $display("dr_shift = %h", dut.dr_shift);
    

    idcode = 32'h0;

    for(i=0;i<32;i=i+1) begin
		@(negedge tck);

		tms = (i==31);
		tdi = 0;

		@(posedge tck);
		#1;

		idcode[i] = tdo;
	end
    jtag_cycle(1,0); // Update DR
    jtag_cycle(0,0); // Idle

    $display("IDCODE = %h", idcode);
   

    #50;
    $finish;
end

endmodule
