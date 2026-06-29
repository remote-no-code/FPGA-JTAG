`timescale 1ns/1ps

module tb_jtag;

reg clk;
reg reset;
reg tck;
reg tms;
reg tdi;
reg trst;
reg rxd;

wire tdo;

reg [31:0] dr_read;

localparam IDCODE       = 4'h1;
localparam DEBUG_CTRL   = 4'h2;
localparam DEBUG_STATUS = 4'h3;
localparam DEBUG_PC     = 4'h4;

SOC dut (
    .CLK(clk),
    .RESET(reset),
    .tck(tck),
    .tms(tms),
    .tdi(tdi),
    .trst(trst),
    .LEDS(),
    .LED_EXT(),
    .RXD(rxd),
    .TXD(),
    .tdo(tdo)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

task jtag_clock;
begin
    #5;
    tck = 0;
    #5;
    tck = 1;
    #5;
    tck = 0;
end
endtask

task jtag_reset;
integer i;
begin
    trst = 1;
    tms = 1;
    for(i=0;i<6;i=i+1)
        jtag_clock();
    trst = 0;
end
endtask

task goto_idle;
begin
    tms = 0;
    jtag_clock();
end
endtask

task goto_shift_ir;
begin
    tms = 1;
    jtag_clock();
    tms = 1;
    jtag_clock();
    tms = 0;
    jtag_clock();
    tms = 0;
    jtag_clock();
end
endtask

task shift_ir;
input [3:0] ir;
integer i;
begin
    for(i=0;i<4;i=i+1)
    begin
        tdi = ir[i];
        if(i==3)
            tms = 1;
        else
            tms = 0;
        jtag_clock();
    end
    tms = 1;
    jtag_clock();
    tms = 0;
    jtag_clock();
end
endtask

task goto_shift_dr;
begin
    tms = 1;
    jtag_clock();
    tms = 0;
    jtag_clock();
    tms = 0;
    jtag_clock();
end
endtask

task shift_dr;
input [31:0] tx_data;
output [31:0] rx_data;
integer i;
reg [31:0] temp;
begin
    temp = 32'h00000000;
    for(i=0;i<32;i=i+1)
	begin
		$display("%0t i=%0d  tdo=%b", $time, i, tdo);
	    tdi = tx_data[i];

	    if(i==31)
		tms = 1;
	    else
		tms = 0;

	    tck = 0;
	    #5;

	    tck = 1;
	    #5;            // allow TAP to update tdo_reg

	    temp[i] = tdo; // sample here

	    tck = 0;
	    #5;
	end
	rx_data = temp;
    tms = 1;
    jtag_clock();
    tms = 0;
    jtag_clock();
end
endtask

always @(posedge tck)
begin
    case(dut.tap0.state)
        0:  $display("%0t TEST_LOGIC_RESET",$time);
        1:  $display("%0t RUN_TEST_IDLE",$time);
        2:  $display("%0t SHIFT_IR",$time);
        3:  $display("%0t UPDATE_IR",$time);
        4:  $display("%0t SELECT_IR",$time);
        5:  $display("%0t CAPTURE_IR",$time);
        6:  $display("%0t EXIT1_IR",$time);
        7:  $display("%0t PAUSE_IR",$time);
        8:  $display("%0t EXIT2_IR",$time);
        9:  $display("%0t SHIFT_DR",$time);
        10: $display("%0t UPDATE_DR",$time);
        11: $display("%0t SELECT_DR",$time);
        12: $display("%0t CAPTURE_DR",$time);
        13: $display("%0t EXIT1_DR",$time);
        14: $display("%0t PAUSE_DR",$time);
        15: $display("%0t EXIT2_DR",$time);
    endcase
end

always @(posedge clk)
begin
    $display("%0t PC=%h HALTED=%b",$time,dut.debug_pc,dut.debug_halted);
end

initial
begin
    $dumpfile("step3.vcd");
    $dumpvars(0,tb_jtag);

    tck = 0;
    tms = 1;
    tdi = 0;
    trst = 1;
    reset = 1;
    rxd = 1'b1;

    #100;

    reset = 0;

    jtag_reset();

    goto_idle();

    $display("\nLoading IR = %h", DEBUG_CTRL);
    goto_shift_ir();
    shift_ir(DEBUG_CTRL);

    goto_shift_dr();
    shift_dr(32'h00000001, dr_read);

    #200;

    goto_shift_dr();
    shift_dr(32'h00000002, dr_read);
    $display("RESUME READBACK = %08h", dr_read);

    #200;

    goto_shift_dr();
    shift_dr(32'h00000004, dr_read);
    $display("RESET READBACK = %08h", dr_read);

    #200;

    $display("\nLoading IR = %h", IDCODE);
    goto_shift_ir();
    shift_ir(IDCODE);

    goto_shift_dr();
    shift_dr(32'h00000000, dr_read);
    $display("IDCODE = %08h", dr_read);

    $display("\nLoading IR = %h", DEBUG_STATUS);
    goto_shift_ir();
    shift_ir(DEBUG_STATUS);

    goto_shift_dr();
    shift_dr(32'h00000000, dr_read);
    $display("DEBUG_STATUS = %08h", dr_read);

    $display("\nLoading IR = %h", DEBUG_PC);
    goto_shift_ir();
    shift_ir(DEBUG_PC);

    goto_shift_dr();
    shift_dr(32'h00000000, dr_read);
    $display("DEBUG_PC = %08h", dr_read);

    #500;

    $finish;
end

endmodule
