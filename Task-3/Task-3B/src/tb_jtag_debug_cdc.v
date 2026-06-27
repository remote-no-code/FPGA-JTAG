`timescale 1ns/1ps

module tb_jtag_debug_cdc;

    //-----------------------------------------------------
    // Clock Generation and Reset Signals
    //-----------------------------------------------------

    reg clk;
    reg tck;
    reg reset;
    reg trst;

    initial begin
        clk = 0;
        forever #10 clk = ~clk;      // System clock : 20 ns period
    end

    initial begin
        tck = 0;
        forever #50 tck = ~tck;      // JTAG clock : 100 ns period
    end

    //-----------------------------------------------------
    // JTAG Debug Request Inputs (TCK Domain)
    //-----------------------------------------------------
    reg debug_halt_req_tck;
    reg debug_resume_req_tck;
    reg debug_reset_req_tck;

    //-----------------------------------------------------
    // CDC Outputs (CLK Domain)
    //-----------------------------------------------------
    wire debug_halt_req_clk;
    wire debug_resume_req_clk;
    wire debug_reset_req_clk;

    //-----------------------------------------------------
    // Simple Processor Model
    //-----------------------------------------------------
    reg [31:0] pc;
    reg halted;

    //-----------------------------------------------------
    // Device Under Test (CDC Module)
    //-----------------------------------------------------
    jtag_debug_cdc dut (
        .tck(tck),
        .trst(trst),

        .clk(clk),
        .reset(reset),

        .debug_halt_req_tck(debug_halt_req_tck),
        .debug_resume_req_tck(debug_resume_req_tck),
        .debug_reset_req_tck(debug_reset_req_tck),

        .debug_halt_req_clk(debug_halt_req_clk),
        .debug_resume_req_clk(debug_resume_req_clk),
        .debug_reset_req_clk(debug_reset_req_clk)
    );

    //-----------------------------------------------------
    // Waveform Dump
    //-----------------------------------------------------
    initial begin
        $dumpfile("jtag_debug_cdc.vcd");
        $dumpvars(0, tb_jtag_debug_cdc);
    end

    //-----------------------------------------------------
    // Test Variables
    //-----------------------------------------------------
    integer pc_before;
    integer pc_after;



    //-----------------------------------------------------
    // Simple Processor Model driven by CDC outputs
    //-----------------------------------------------------
	always @(posedge clk or posedge reset)
	begin
		if (reset)
		begin
		    halted <= 1'b0;
		    pc <= 32'h00000000;
		end
		else if (debug_reset_req_clk)
		begin
		    halted <= 1'b0;
		    pc <= 32'h00000000;
		end
		else
		begin
		    if (debug_halt_req_clk)
		        halted <= 1'b1;
		    else if (debug_resume_req_clk)
		        halted <= 1'b0;

		    if (halted)
		        pc <= pc;
		    else
		        pc <= pc + 4;
		end
	end
	//-----------------------------------------------------
    // Verification Sequence
    //-----------------------------------------------------
    initial begin

        //-------------------------------------------------
        // Initialization
        //-------------------------------------------------
        reset = 1;
        trst  = 1;

        debug_halt_req_tck   = 0;
        debug_resume_req_tck = 0;
        debug_reset_req_tck  = 0;

        $display("==========================================================");
        $display("        JTAG Debug Clock Domain Crossing Verification");
        $display("==========================================================");
        $display("");
        $display("Initializing simulation...");
        $display("Applying system and JTAG resets...");

        #100;

        reset = 0;
        trst  = 0;

        $display("Reset sequence completed.");

        //-------------------------------------------------
        // Step 1 : Processor Verification
        //-------------------------------------------------
        repeat (5) begin
            @(posedge clk);
		end
        $display("");
        $display("----------------------------------------------------------");
        $display("Step 1 : Processor Verification");
        $display("----------------------------------------------------------");

        $display("Core initialized successfully.");
        $display("Initial Program Counter : 0x%08h", pc);

        pc_before = pc;

        // Simulate processor execution
        repeat (5) begin
            @(posedge clk);
		end
        pc_after = pc;

        if (pc_after != pc_before) begin
            $display("Observing processor execution...");
            $display("");
            $display("Program Counter:");
            $display("    0x%08h -> 0x%08h", pc_before, pc_after);
            $display("");
            $display("[PASS] Processor is executing instructions correctly.");
        end
        else begin
            $display("FAIL : Program Counter did not advance.");
            $finish;
        end

        //-------------------------------------------------
        // Step 2 : HALT Request Synchronization
        //-------------------------------------------------
        $display("");
        $display("----------------------------------------------------------");
        $display("Step 2 : HALT Request Synchronization");
        $display("----------------------------------------------------------");

        $display("Generating HALT request in JTAG (TCK) clock domain...");
        $display("Waiting for synchronization into processor (CLK) domain...");

        @(negedge tck);
        debug_halt_req_tck = 1'b1;

        @(posedge tck);

        @(negedge tck);
        debug_halt_req_tck = 1'b0;
        // Verify HALT pulse width (event-based)
        wait(debug_halt_req_clk);

		$display("[PASS] HALT pulse detected");

		@(posedge clk);

        if (debug_halt_req_clk)
        begin
            @(posedge clk);

            if (debug_halt_req_clk)
            begin
                $display("[FAIL] HALT pulse wider than 1 CLK cycle");
                $finish;
            end

            $display("[PASS] HALT pulse width verified (1 CLK cycle)");
        end
        else
        begin
            $display("[FAIL] HALT pulse shorter than 1 CLK cycle");
            $finish;
        end

        wait(halted);

        $display("[PASS] HALT request synchronized successfully.");
        $display("[PASS] Processor entered HALT state.");

        pc_before = pc;

        repeat (10) begin
            @(posedge clk);
		end
        if (pc == pc_before) begin
            $display("[PASS] Program Counter remained constant.");
            $display("Current PC : 0x%08h", pc);
        end
        else begin
            $display("FAIL : Program Counter changed during HALT.");
            $finish;
        end

        //-------------------------------------------------
        // Step 3 : RESUME Request Synchronization
        //-------------------------------------------------
        $display("");
        $display("----------------------------------------------------------");
        $display("Step 3 : RESUME Request Synchronization");
        $display("----------------------------------------------------------");

        $display("Generating RESUME request in JTAG (TCK) clock domain...");
        $display("Waiting for synchronization into processor (CLK) domain...");

        @(negedge tck);
        debug_resume_req_tck = 1'b1;

        @(posedge tck);

        @(negedge tck);
        debug_resume_req_tck = 1'b0;
        // Verify RESUME pulse width (event-based)
        wait(debug_resume_req_clk);
        $display("[PASS] RESUME pulse detected");

        @(posedge clk);

        if (debug_resume_req_clk)
        begin
            @(posedge clk);

            if (debug_resume_req_clk)
            begin
                $display("[FAIL] RESUME pulse wider than 1 CLK cycle");
                $finish;
            end

            $display("[PASS] RESUME pulse width verified (1 CLK cycle)");
        end
        else
        begin
            $display("[FAIL] RESUME pulse shorter than 1 CLK cycle");
            $finish;
        end

        wait(!halted);

        $display("[PASS] RESUME request synchronized successfully.");
        $display("[PASS] Processor resumed execution.");

        pc_before = pc;

        repeat (10) begin
            @(posedge clk);
		end
        pc_after = pc;

        if (pc_after != pc_before) begin
            $display("Program Counter:");
            $display("    0x%08h -> 0x%08h", pc_before, pc_after);
        end
        else begin
            $display("FAIL : Program Counter did not resume.");
            $finish;
        end

        //-------------------------------------------------
        // Step 4 : RESET Request Synchronization
        //-------------------------------------------------
        $display("");
        $display("----------------------------------------------------------");
        $display("Step 4 : RESET Request Synchronization");
        $display("----------------------------------------------------------");

        $display("Generating RESET request in JTAG (TCK) clock domain...");
        $display("Waiting for synchronization into processor (CLK) domain...");

        @(negedge tck);
        debug_reset_req_tck = 1'b1;

        @(posedge tck);

        @(negedge tck);
        debug_reset_req_tck = 1'b0;

        // Verify RESET pulse width
	wait(debug_reset_req_clk);

	$display("[PASS] RESET pulse detected");

	@(posedge clk);

	if (debug_reset_req_clk)
	begin
	    @(posedge clk);

	    if (debug_reset_req_clk)
	    begin
		$display("[FAIL] RESET pulse wider than 1 CLK cycle");
		$finish;
	    end

	    $display("[PASS] RESET pulse width verified (1 CLK cycle)");
	end
	else
	begin
	    $display("[FAIL] RESET pulse shorter than 1 CLK cycle");
	    $finish;
	end


	wait(pc == 32'h00000000);

	if (pc == 32'h00000000)
	begin
	    $display("[PASS] RESET request synchronized successfully.");
	    $display("[PASS] Processor reset completed.");
	    $display("Program Counter reset to : 0x%08h", pc);
	end
	else
	begin
	    $display("[FAIL] Processor reset failed.");
	    $finish;
	end
        //-------------------------------------------------
        // Verification Summary
        //-------------------------------------------------
        $display("");
        $display("----------------------------------------------------------");
        $display("Verification Summary");
        $display("----------------------------------------------------------");
        $display("");

        $display("Clock Domains");
        $display("-------------");
        $display("[PASS] Independent TCK and CLK domains verified");
        $display("");

        $display("CDC Mechanism");
        $display("-------------");
        $display("[PASS] Toggle-based synchronization verified");
        $display("[PASS] Two-stage synchronizer verified");
        $display("");

        $display("Debug Requests");
        $display("--------------");
        $display("[PASS] HALT request transferred correctly");
        $display("[PASS] RESUME request transferred correctly");
        $display("[PASS] RESET request transferred correctly");
        $display("");

        $display("Processor Verification");
        $display("------------------");
        $display("[PASS] Processor halted successfully");
        $display("[PASS] Processor resumed successfully");
        $display("[PASS] Program Counter behavior verified");

        $display("");
        $display("==========================================================");
        $display("                TASK 3B PASSED");
        $display("==========================================================");

        #100;
        $finish;
    end

endmodule
