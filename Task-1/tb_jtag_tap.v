module tb_jtag;

reg tck;
reg tms;
reg tdi;
reg trst;

wire tdo;

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

	tms = 0; jtag_clk(); 
	tms = 1; jtag_clk(); 
	
	
	for( i = 0; i < 4; i = i + 1) begin   //JTAG is serial send bit one by one
		
		tdi = instruction[i];
		
		if(i == 3)       //after final bit change state
			tms = 1;     // moves to update_ir
		else
			tms = 0;
			
		jtag_clk();
	end

	
	tms =1;
	jtag_clk();
	
end 
endtask


task shift_dr;  //instructions loaded now data reading
integer i;

begin

	tms = 1; jtag_clk();
	
	for(i = 0; i < 32; i = i + 1) begin
		
		tdi = 0;
		
		if( i == 31)
			tms = 1;
		else 
			tms = 0;
			
		jtag_clk();
		
		$display("Bit %d : TDO = %b", i, tdo);
	end
	
	
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
	
	#20;
	trst = 0;
	
	$display(" Shift IDCODE Ins");
	
	shift_ir(4'b0001);
	
	$display(" Read Data Message ");
	
	shift_dr();
	
	#50;
	$finish;

end
endmodule
