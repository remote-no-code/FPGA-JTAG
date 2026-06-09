`timescale 1ns/1ps

module tb_processor_debug;

reg clk;
reg resetn;

reg debug_halt_req;
reg debug_resume_req;
reg debug_reset_req;

wire debug_halted;
wire [31:0] debug_pc;

wire [31:0] mem_addr;
wire [31:0] mem_rdata;
wire mem_rstrb;
wire [31:0] mem_wdata;
wire [3:0] mem_wmask;

Processor dut(
    .clk(clk),
    .resetn(resetn),

    .mem_addr(mem_addr),
    .mem_rdata(mem_rdata),
    .mem_rstrb(mem_rstrb),
    .mem_wdata(mem_wdata),
    .mem_wmask(mem_wmask),

    .debug_halt_req(debug_halt_req),
    .debug_resume_req(debug_resume_req),
    .debug_reset_req(debug_reset_req),

    .debug_halted(debug_halted),
    .debug_pc(debug_pc)
);

Memory RAM(
    .clk(clk),
    .mem_addr(mem_addr),
    .mem_rdata(mem_rdata),
    .mem_rstrb(mem_rstrb),
    .mem_wdata(mem_wdata),
    .mem_wmask(mem_wmask)
);

always #5 clk = ~clk;

reg [31:0] pc1;
reg [31:0] pc2;

initial begin

    $dumpfile("processor_debug.vcd");
    $dumpvars(0,tb_processor_debug);

    clk = 0;
    resetn = 0;

    debug_halt_req   = 0;
    debug_resume_req = 0;
    debug_reset_req  = 0;

    #100;
    resetn = 1;

    // CPU should run

    #100;
    pc1 = debug_pc;

    #100;
    pc2 = debug_pc;

    if(pc1 != pc2)
        $display("PASS : CPU running");
    else
        $display("FAIL : CPU not running");

    // HALT

    debug_halt_req = 1;
    #10;
    debug_halt_req = 0;

    #100;

    if(debug_halted)
        $display("PASS : HALT accepted");
    else
        $display("FAIL : HALT failed");

    pc1 = debug_pc;

    #100;

    pc2 = debug_pc;

    if(pc1 == pc2)
        $display("PASS : PC frozen");
    else
        $display("FAIL : PC still changing");

    // RESUME

    debug_resume_req = 1;
    #10;
    debug_resume_req = 0;

    #100;

    if(!debug_halted)
        $display("PASS : RESUME accepted");
    else
        $display("FAIL : RESUME failed");

    pc1 = debug_pc;

    #100;

    pc2 = debug_pc;

    if(pc1 != pc2)
        $display("PASS : PC running again");
    else
        $display("FAIL : PC still frozen");

    $display("TASK-2 PROCESSOR DEBUG TEST COMPLETE");
    
    // Capture PC before reset
	pc1 = debug_pc;

	// Send RESET request
	debug_reset_req = 1;
	#10;
	debug_reset_req = 0;

	// Wait for reset processing
	#100;

	// Verify reset was accepted
	if (!debug_halted)
		$display("PASS : RESET accepted");
	else
		$display("FAIL : RESET failed");

	// Verify PC returned to reset vector
	if (debug_pc == 32'h00000008)
		$display("PASS : PC reset correctly");
	else
		$display("FAIL : PC reset failed, PC = %h", debug_pc);

	// Verify processor runs again after reset
	pc1 = debug_pc;
	#100;
	pc2 = debug_pc;

	if (pc1 != pc2)
		$display("PASS : CPU running after reset");
	else
		$display("FAIL : CPU not running after reset");

	$display("TASK-2 PROCESSOR DEBUG TEST COMPLETE");

    #100;
    $finish;

end
always @(posedge clk) $display("PC=%h halted=%b", debug_pc, debug_halted);
always @(posedge clk) begin
    if(^debug_pc === 1'bx)
        $display("PC became X at time %0t", $time);
end
always @(posedge clk) begin
    if(^dut.instr === 1'bx)
        $display("INSTR became X at time %0t", $time);

    if(^dut.nextPC === 1'bx)
        $display("nextPC became X at time %0t", $time);
end

endmodule
