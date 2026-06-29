`timescale 1ns/1ps

module tb_step2;

reg clk;
reg resetn;

reg debug_halt_req;
reg debug_resume_req;
reg debug_reset_req;

wire debug_halted;
wire [31:0] debug_pc;

wire [31:0] mem_addr;
wire [31:0] mem_rdata;
wire        mem_rstrb;
wire [31:0] mem_wdata;
wire [3:0]  mem_wmask;

//-----------------------------------------------------
// DUT
//-----------------------------------------------------

Processor DUT (
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
Memory RAM (
    .clk(clk),

    .mem_addr(mem_addr),
    .mem_rdata(mem_rdata),
    .mem_rstrb(mem_rstrb),

    .mem_wdata(mem_wdata),
    .mem_wmask(mem_wmask)
);

//-----------------------------------------------------
// Clock
//-----------------------------------------------------

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

//-----------------------------------------------------
// Test
//-----------------------------------------------------

reg [31:0] pc_before;
reg [31:0] pc_after;

initial begin

    $dumpfile("step2.vcd");
    $dumpvars(0,tb_step2);

    resetn = 0;

    debug_halt_req   = 0;
    debug_resume_req = 0;
    debug_reset_req  = 0;

    #50;

    resetn = 1;

    //-------------------------------------------------
    // CPU should run
    //-------------------------------------------------

    repeat(10) begin
        @(posedge clk);
        $display("RUN   PC=%h HALTED=%b",debug_pc,debug_halted);
    end

    //-------------------------------------------------
    // HALT TEST
    //-------------------------------------------------

    repeat (30)
        @(posedge clk);

    #1;
    pc_before = debug_pc;

    $display("\nHALT TEST");
    $display("PC Before Halt = %h", pc_before);

    // Request halt
	debug_halt_req = 1;
	repeat(2) @(posedge clk);
	debug_halt_req = 0;

	// Wait until processor reports halted
	wait(debug_halted);

	pc_before = debug_pc;

	// Stay halted
	repeat(10)
		@(posedge clk);

	pc_after = debug_pc;

	if(pc_before == pc_after)
		$display("[PASS] PC frozen while halted");
	else
		$display("[FAIL]");

    //-------------------------------------------------
    // RESUME TEST
    //-------------------------------------------------

    $display("\nRESUME TEST");

    #1;
    pc_before = debug_pc;

    debug_resume_req = 1;
    repeat (5)
        @(posedge clk);
    debug_resume_req = 0;

    repeat (20)
        @(posedge clk);

    #1;
    pc_after = debug_pc;

    $display("PC Before Resume = %h", pc_before);
    $display("PC After Resume  = %h", pc_after);
    $display("HALTED           = %b", debug_halted);

    if (pc_before != pc_after)
        $display("[PASS] Processor resumed.");
    else
        $display("[FAIL] PC did not advance after resume.");

    //-------------------------------------------------
    // RESET TEST
    //-------------------------------------------------

    $display("\nRESET TEST");

    debug_reset_req = 1;
	repeat(2) @(posedge clk);
	debug_reset_req = 0;

	// Check on the very next clock
	@(posedge clk);

	$display("PC After Reset = %h", debug_pc);

	if (debug_pc == 32'h00000000)
		$display("[PASS] Processor reset.");
	else
		$display("[FAIL] Reset failed.");

    #20;
    $finish;

end

always @(posedge clk)
begin
    $display("TB sees debug_pc = %h", debug_pc);
    $display("TB sees DUT.PC    = %h", DUT.PC);
end
endmodule
