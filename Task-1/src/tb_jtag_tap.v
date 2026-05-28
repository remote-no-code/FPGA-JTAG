module tb_jtag;

reg tck;
reg tms;
reg tdi;
reg trst;

wire tdo;

reg [31:0] read_idcode;

integer i; 

jtag_tap dut(
	.tck(tck),
	.tms(tms),
	.tdi(tdi),
	.trst(trst),
	.tdo(tdo)
);

always #5 tck = ~tck;

task jtag_clk;  // perform ONE JTAG clock operation
begin
	@(posedge tck);
	#1;             // signals samples too early
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


task shift_dr;  //instructions loaded now data reading
integer i;

begin

	tms = 0; jtag_clk(); //run-test idle
	tms = 1; jtag_clk(); //select dr scan
	tms = 0; jtag_clk(); //capture dr
	tms = 0; jtag_clk(); //shift dr
	
	read_idcode = 32'h00000000;
	
	for(i = 0; i < 32; i = i + 1) begin
		
		if( i == 31)
			tms = 1;
		else 
			tms = 0;
		
		tdi=0;
		jtag_clk();
		
		read_idcode[i] = tdo;
		$display("Bit %d : TDO = %b", i, tdo);
	end
	
	tms = 1; jtag_clk(); //update dr
	tms = 0; jtag_clk();
	
end
endtask

initial begin 

	$dumpfile("jtag_tap.vcd");
	$dumpvars(0, tb_jtag);
	
	tck = 0;
	tms = 1;
	tdi = 0;
	trst = 1;
	
	read_idcode = 32'h0;
	
	#20;
	trst = 0;
	
	$display(" Shift IDCODE Ins");
	
	shift_ir(4'b0001);
	
	$display(" Read Data Message ");
	
	shift_dr();
	
	$display("Read IDCODE = %h", read_idcode);
	
	if(read_idcode == 32'h81262776) $display("pass");
	
	else $display("fail");
	
	#50;
	$finish;

end
endmodule
