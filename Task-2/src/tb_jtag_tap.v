module tb_jtag;

reg tck;
reg tms;
reg tdi;
reg trst;

wire tdo;

wire debug_halt_req;
wire debug_resume_req;
wire debug_reset_req;

reg debug_halted;
reg [31:0] debug_pc;

reg [31:0] dr_data;

integer i; 

jtag_tap dut(
	.tck(tck),
	.tms(tms),
	.tdi(tdi),
	.trst(trst),
	
	.tdo(tdo),
	
	.debug_halt_req(debug_halt_req),
	.debug_resume_req(debug_resume_req),
	.debug_reset_req(debug_reset_req),
	
	.debug_halted(debug_halted),
	.debug_pc(debug_pc)
);

always #5 tck = ~tck;

task jtag_clk;  // perform ONE JTAG clock operation
begin
	@(posedge tck);
	#1;             // signals samples too early
end 
endtask

task tap_reset;
integer k;
begin

	tms = 1;
	for(k = 0; k < 6; k = k + 1) jtag_clk();
	
	tms = 1;
	jtag_clk();
	
end 
endtask

// What operations we want done by SHIFT_IR

task shift_ir;  
input [3:0] instruction; //4 bit instruction 
integer i;


begin
	tms = 0; jtag_clk(); //run-test idle
	tms = 1; jtag_clk(); //Select DR scan
	tms = 1; jtag_clk(); //Select IR scan
	tms = 0; jtag_clk(); //Capture IR
	tms = 0; jtag_clk(); //Shift Ir
	
	
	for( i = 0; i < 4; i = i + 1) begin   //JTAG is serial send bit one by one
		
		tdi = instruction[i];
		
		if(i == 3)       //after final bit change state
			tms = 1;     // moves to update_ir
		else
			tms = 0;
			
		jtag_clk();
	end

	
	tms = 1; //update ir
	jtag_clk();
	
	tms = 0; //run test idle
	jtag_clk();
end 
endtask


task shift_dr_read32;  //instructions loaded now data reading
output [31:0] data;
integer i;

begin
	
	tms = 0; jtag_clk(); //run-test idle
	tms = 1; jtag_clk(); //select dr scan
	tms = 0; jtag_clk(); //capture dr
	tms = 0; jtag_clk(); //shift dr
	
	data = 32'h00000000;
	
	for(i = 0; i < 32; i = i + 1) begin
		
		if( i == 31)
			tms = 1;
		else 
			tms = 0;
		
		tdi=0;
		jtag_clk();
		
		data[i] = tdo;
		$display("Bit %d : TDO = %b", i, tdo);
	end
	
	tms = 1; jtag_clk(); //update dr
	tms = 0; jtag_clk();
	
end
endtask

task shift_dr_write32;
input [31:0] data;
integer i;

begin 
	tms = 1; jtag_clk(); // Select DR Scan
	tms = 0; jtag_clk(); // capture_dr
	tms = 0; jtag_clk(); // shift_dr
	
	for(i = 0; i < 32; i = i+1) begin
		tdi = data[i];
		
		if( i == 31) tms = 1;
		else tms = 0;
		
		jtag_clk();
	end
	
	tms = 1; jtag_clk(); //update_dr
	tms = 0; jtag_clk(); //run test idle
	
end
endtask

initial begin 

	$dumpfile("jtag_tap.vcd");
	$dumpvars(0, tb_jtag);
	
	tck = 0;
	tms = 1;
	tdi = 0;
	trst = 1;
	
	debug_halted = 1;
	debug_pc = 32'h80000000;
	
	dr_data = 32'h0;
	
	#20;
	trst = 0;
	// IDCODE TEST
	
	$display(" IDCODE TEST");
	
	shift_ir(4'b0001);
	shift_dr_read32(dr_data);
	
	
	$display("Read IDCODE = %h", dr_data);
	
	if(dr_data == 32'h81262776) $display("IDCODE PASS\n");
	
	else $display("IDCODE FAIL");
	
	
	//DEBUG STATUS
	
	$display (" DEBUG STATUS");
	shift_ir (4'b0011);
	shift_dr_read32(dr_data);
	
	$display("DEBUG_STATUS = %h", dr_data);
	
	if(dr_data == 32'h00000001) $display("Debug status pass\n");
	else $display("Debug status fail");
	
	//Debug PC
	
	$display("Debug PC");
	shift_ir(4'b0100);
	shift_dr_read32(dr_data);
	
	$display("Debug PC = %h", dr_data);
	
	if(dr_data == 32'h80000000) $display ("Debug pc pass \n");
	else $display(" Debug pc fail ");
	
	
	//Debug Ctrl Halt
	
	$display("Debug control halt test");
	
	shift_ir(4'b0010);
	shift_dr_write32(32'h00000001);
	
	#20;

		
	// Debug Control Resume
	$display("Debug Control Resume test");
	
	shift_ir(4'b0010);
	shift_dr_write32(32'h00000002);
	
	#20;

	//Debug Control Reset
	
	$display("Debug Control Reset test");
	
	shift_ir(4'b0010);
	shift_dr_write32(32'h00000004);
	
		
	#100;
	$finish;

end

always @(posedge tck) begin

    if(debug_halt_req)
        $display("HALT requested generated\n");

    if(debug_resume_req)
        $display("RESUME requested generated\n");

    if(debug_reset_req)
        $display("RESET requested generated\n");

end
endmodule
