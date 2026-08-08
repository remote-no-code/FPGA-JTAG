`timescale 1ns/1ps

module tb_soc_debug;

    // Testbench Signals
    reg clk;
    reg reset;

    reg tck;
    reg tms;
    reg tdi;
    reg n_trst;

    wire tdo;

    integer timeout;
    integer i;

    reg [31:0] idcode_read;

    // JTAG Instructions
    parameter IDCODE = 5'b00001;
    parameter DTMCS  = 5'b10000;
    parameter DMI    = 5'b10001;
    parameter BYPASS = 5'b11111;

    // Device Under Test
    SOC dut (
        .CLK   (clk),
        .RESET (reset),

        .tck   (tck),
        .tms   (tms),
        .tdi   (tdi),
        .trst  (n_trst),

        .RXD   (1'b1),
        .TXD   (),

        .tdo   (tdo)
    );

    // System Clock (100 MHz)
    initial begin
        clk = 1'b0;

        forever
            #5 clk = ~clk;
    end

    // JTAG Clock
    task jtag_clock;
    begin
        #5;
        tck = 1'b0;

        #5;
        tck = 1'b1;

        #5;
        tck = 1'b0;
    end
    endtask

    // Reset JTAG TAP
    task jtag_reset;

        integer i;

    begin
        n_trst = 1'b0;
        tms    = 1'b1;

        for (i = 0; i < 6; i = i + 1)
            jtag_clock();

        n_trst = 1'b1;
    end
    endtask

    // Move TAP to Run-Test/Idle
    task goto_idle;
    begin
        tms = 1'b0;
        jtag_clock();
    end
    endtask

    // Move TAP to Shift-IR
    task goto_shift_ir;
    begin
        tms = 1'b1;
        jtag_clock();

        tms = 1'b1;
        jtag_clock();

        tms = 1'b0;
        jtag_clock();

        tms = 1'b0;
        jtag_clock();
    end
    endtask

    // Move TAP to Shift-DR
    task goto_shift_dr;
    begin
        tms = 1'b1;
        jtag_clock();

        tms = 1'b0;
        jtag_clock();

        tms = 1'b0;
        jtag_clock();
    end
    endtask

    // Shift Instruction Register
    task shift_ir;

        input [4:0] instruction;
        integer i;

    begin
        for (i = 0; i < 5; i = i + 1) begin
            tdi = instruction[i];

            if (i == 4)
                tms = 1'b1;
            else
                tms = 1'b0;

            jtag_clock();
        end

        // Exit Shift-IR -> Update-IR
        tms = 1'b1;
        jtag_clock();

        // Update-IR -> Run-Test/Idle
        tms = 1'b0;
        jtag_clock();
    end
    endtask

    // Shift DMI Packet
    task shift_dmi;

        input [6:0]  addr;
        input [31:0] data;
        input [1:0]  op;

        reg [40:0] packet;
        reg [40:0] response;

        integer i;

    begin
        $display("%0t TB: shift_dmi(addr=%02h, data=%08h, op=%0d)",
                 $time, addr, data, op);

        packet = {addr, data, op};

        goto_shift_dr();

        for (i = 0; i < 41; i = i + 1) begin
            tdi = packet[i];

            if (i == 40)
                tms = 1'b1;
            else
                tms = 1'b0;

            jtag_clock();

            response[i] = tdo;

            $display("Returned packet = %011h", response);
        end

        $display("Returned DMI packet = %011h", response);
        $display("Returned DATA       = %08h", response[33:2]);
        $display("Returned RESP       = %0d", response[1:0]);

        // Exit Shift-DR -> Update-DR
        tms = 1'b1;
        jtag_clock();

        // Update-DR -> Run-Test/Idle
        tms = 1'b0;
        jtag_clock();

        $display("%0t TB: shift_dmi DONE", $time);
        $display("%0t TB: shift_dmi DONE", $time);

        repeat (1)
            @(posedge clk);

        $display("%0t TB: after 1 CPU clk", $time);

        repeat (5)
            @(posedge clk);

        $display("%0t TB: after 6 CPU clk", $time);
    end
    endtask

    // DMI Operations
    localparam DMI_NOP   = 2'b00;
    localparam DMI_READ  = 2'b01;
    localparam DMI_WRITE = 2'b10;

    // Debug Module Registers
    localparam DATA0      = 7'h04;
    localparam DATA1      = 7'h05;
    localparam DMCONTROL  = 7'h10;
    localparam DMSTATUS   = 7'h11;
    localparam HARTINFO   = 7'h12;
    localparam ABSTRACTCS = 7'h16;
    localparam COMMAND    = 7'h17;

    // JTAG Instruction Register Values
    localparam IDCODE_IR = 5'b00001;
    localparam DTMCS_IR  = 5'b10000;
    localparam DMI_IR    = 5'b10001;
    localparam BYPASS_IR = 5'b11111;

    // Standard Abstract Commands
    function [31:0] access_reg_read;
        input [15:0] regno;
    begin
        access_reg_read =
            (8'h00 << 24) |     // cmdtype = Access Register
            (1'b1 << 22) |      // transfer
            (1'b0 << 21) |      // read
            (2'b10 << 17) |     // aarsize = 32-bit
            regno;
    end
    endfunction

    function [31:0] access_reg_write;
        input [15:0] regno;
    begin
        access_reg_write =
            (8'h00 << 24) |     // cmdtype
            (1'b1 << 22) |      // transfer
            (1'b1 << 21) |      // write
            (2'b10 << 17) |     // 32-bit
            regno;
    end
    endfunction

    // Test Sequence
    initial begin

        // Initialize VCD Dump
        $dumpfile("tb_soc_debug.vcd");
        $dumpvars(0, tb_soc_debug);

        // Initialize Signals
        clk    = 1'b0;
        tck    = 1'b0;
        tms    = 1'b1;
        tdi    = 1'b0;

        reset  = 1'b1;
        n_trst = 1'b1;

        #100;
        reset = 1'b0;

        // n_TRST Verification
        $display("================================");
        $display("n_TRST VERIFICATION");
        $display("================================");

        // Hold TAP in reset
        n_trst = 1'b0;

        repeat (10)
            jtag_clock();

        // Verify TAP State
        if (dut.dtm.state == dut.dtm.TEST_LOGIC_RESET)
            $display("PASS : n_trst LOW keeps TAP in TEST_LOGIC_RESET");
        else
            $display("FAIL : TAP escaped reset");

        // Release TAP
        n_trst = 1'b1;

        repeat (5)
            jtag_clock();

        $display("PASS : n_trst released");

        // TAP Reset
        jtag_reset();
        goto_idle();

        // Load DMI Instruction
        $display("================================");
        $display("Load DMI Instruction");
        $display("================================");

        goto_shift_ir();
        shift_ir(DMI_IR);

        // Read IDCODE
        $display("================================");
        $display("READ IDCODE");
        $display("================================");

        $display("LOAD IDCODE IR");

        goto_shift_ir();
        shift_ir(IDCODE_IR);

        $display("Current IR = %02h", dut.dtm.ir);

        goto_shift_dr();

        for (i = 0; i < 32; i = i + 1) begin
            tdi = 1'b0;

            if (i == 31)
                tms = 1'b1;
            else
                tms = 1'b0;

            jtag_clock();
            #2;

            idcode_read[i] = tdo;
        end

        tms = 1'b1;
        jtag_clock();

        tms = 1'b0;
        jtag_clock();

        $display("IDCODE = %08h", idcode_read);

        goto_shift_ir();
        shift_ir(DMI_IR);

        // Allow CPU to Execute
        repeat (20)
            @(posedge clk);

        // HALT TEST
        $display("================================");
        $display("HALT TEST");
        $display("================================");

        $display("CPU PC before halt = %08h", dut.debug_pc);

        shift_dmi(DMCONTROL, 32'h80000001, DMI_WRITE);

        // Wait Until CPU Reports Halted
        timeout = 0;

        while (!dut.debug_halted && timeout < 500) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        $display("%0t TB sees CPU.debug_halted = %b",
                 $time, dut.debug_halted);

        if (dut.debug_halted)
            $display("HALT REQUEST PASS");
        else
            $display("HALT REQUEST FAILED");

        // Read DMSTATUS
        $display("================================");
        $display("READ DMSTATUS");
        $display("================================");

        shift_dmi(DMSTATUS, 32'h00000000, DMI_READ);

        repeat (10)
            @(posedge clk);

        $display("DMSTATUS = %08h", dut.dm_rdata);

        if (dut.dm_rdata[9]  &&      // allhalted
            dut.dm_rdata[8]  &&      // anyhalted
           !dut.dm_rdata[11] &&      // allrunning
           !dut.dm_rdata[10] &&      // anyrunning
            dut.dm_rdata[7]  &&      // authenticated
            dut.dm_rdata[3:0] == 4'h2) begin

            $display("DMSTATUS TEST PASS");
        end
        else begin
            $display("DMSTATUS TEST FAIL");
        end

        // HARTINFO TEST
        $display("================================");
        $display("HARTINFO TEST");
        $display("================================");

        shift_dmi(HARTINFO, 32'h00000000, DMI_READ);

        repeat (10)
            @(posedge clk);

        $display("HARTINFO = %08h", dut.dm_rdata);

        if (dut.dm_rdata == dut.debug_module.hartinfo) begin
            $display("HARTINFO TEST PASS");
        end
        else begin
            $display("HARTINFO TEST FAIL");
        end

        // Read DATA0 (Program Counter)
        $display("================================");
        $display("READ DATA0");
        $display("================================");

        shift_dmi(DATA0, 32'h00000000, DMI_READ);

        repeat (10)
            @(posedge clk);

        // Abstract Access Unit Test
        $display("================================");
        $display("ABSTRACT ACCESS UNIT TEST");
        $display("================================");

        // Read DPC (Program Counter)
        $display("\nExecuting Abstract Command : READ DPC");

        shift_dmi(COMMAND, access_reg_read(16'h07B1), DMI_WRITE);

        repeat (10)
            @(posedge clk);

        shift_dmi(DATA0, 32'h00000000, DMI_READ);

        repeat (10)
            @(posedge clk);

        if (dut.debug_module.data0_reg == dut.debug_dpc) begin
            $display("READ DPC TEST PASS");
        end
        else begin
            $display("READ DPC TEST FAIL");
            $display("Expected = %08h", dut.debug_dpc);
            $display("Received = %08h", dut.debug_module.data0_reg);
        end

        // Write x1
        $display("\n================================");
        $display("Executing Abstract Command : WRITE x1");
        $display("================================");

        shift_dmi(DATA0, 32'h12345678, DMI_WRITE);

        repeat (10)
            @(posedge clk);

        shift_dmi(COMMAND, access_reg_write(16'h1001), DMI_WRITE);

        repeat (10)
            @(posedge clk);

        // Read x1
        $display("\nExecuting Abstract Command : READ x1");

        shift_dmi(COMMAND, access_reg_read(16'h1001), DMI_WRITE);

        repeat (10)
            @(posedge clk);

        shift_dmi(DATA0, 32'h00000000, DMI_READ);

        repeat (10)
            @(posedge clk);

        if (dut.debug_module.data0_reg == 32'h12345678)
            $display("READ x1 TEST PASS");
        else
            $display("READ x1 TEST FAIL");

        // Read x2
        $display("\nExecuting Abstract Command : READ x2");

        shift_dmi(COMMAND, access_reg_read(16'h1002), DMI_WRITE);

        repeat (10)
            @(posedge clk);

        shift_dmi(DATA0, 32'h00000000, DMI_READ);

        repeat (10)
            @(posedge clk);

        // Read x3
        $display("\nExecuting Abstract Command : READ x3");

        shift_dmi(COMMAND, access_reg_read(16'h1003), DMI_WRITE);

        repeat (10)
            @(posedge clk);

        shift_dmi(DATA0, 32'h00000000, DMI_READ);

        repeat (10)
            @(posedge clk);

        // Abstract Memory Write Test
        $display("");
        $display("================================");
        $display("ABSTRACT MEMORY WRITE TEST");
        $display("================================");

        shift_dmi(DATA0, 32'h00000080, DMI_WRITE);
        repeat (5) @(posedge clk);

        shift_dmi(DATA1, 32'h12345678, DMI_WRITE);
        repeat (5) @(posedge clk);

        shift_dmi(COMMAND, 32'h02640000, DMI_WRITE);

        timeout = 0;

        while (timeout < 100) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        /*
        if (dut.memory.mem[32'h80 >> 2] == 32'h12345678)
            $display("MEMORY WRITE TEST PASS");
        else
            $display("MEMORY WRITE TEST FAIL");
        */

        // Abstract Memory Read Test
        $display("");
        $display("================================");
        $display("ABSTRACT MEMORY READ TEST");
        $display("================================");

        shift_dmi(DATA0, 32'h00000080, DMI_WRITE);
        repeat (5) @(posedge clk);

        shift_dmi(COMMAND, 32'h02440000, DMI_WRITE);

        timeout = 0;

        while (timeout < 100) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        shift_dmi(DATA0, 32'h00000000, DMI_READ);

        repeat (10)
            @(posedge clk);

        if (dut.debug_module.data0_reg == 32'h12345678)
            $display("ABSTRACT MEMORY TEST PASS");
        else begin
            $display("ABSTRACT MEMORY TEST FAIL");
            $display("Expected = 12345678");
            $display("Received = %08h", dut.debug_module.data0_reg);
        end

        // RESUME TEST
        $display("================================");
        $display("RESUME TEST");
        $display("================================");

        $display("CPU PC before resume = %08h", dut.debug_pc);

        shift_dmi(DMCONTROL, 32'h40000001, DMI_WRITE);

        $display("DMCONTROL      = %08h", dut.debug_module.dmcontrol);
        $display("DMCONTROL_REG  = %08h", dut.debug_module.dmcontrol_reg);

        repeat (5) @(posedge clk);

        $display("debug_resume_req = %b", dut.debug_resume_req);
        $display("debug_halted     = %b", dut.debug_halted);

        timeout = 0;

        while (dut.debug_halted && timeout < 500) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (!dut.debug_halted)
            $display("RESUME PASS");
        else
            $display("RESUME FAIL");

        repeat (10)
            @(posedge clk);

        $display("CPU PC after resume = %08h", dut.debug_pc);

        // RESET TEST
        $display("================================");
        $display("RESET TEST");
        $display("================================");

        $display("CPU PC before reset = %08h", dut.debug_pc);

        shift_dmi(DMCONTROL, 32'h20000001, DMI_WRITE);

        $display("DMCONTROL_REG = %08h", dut.debug_module.dmcontrol_reg);

        repeat (2) @(posedge clk);

        $display("debug_reset_req = %b", dut.debug_reset_req);

        timeout = 0;

        while (dut.debug_reset_req && timeout < 500) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        timeout = 0;

        while ((dut.debug_pc != 32'h00000000) && timeout < 500) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        $display("CPU PC after reset = %08h", dut.debug_pc);

        if (dut.debug_pc == 32'h00000000)
            $display("RESET PASS");
        else
            $display("RESET FAIL");

        // ABSTRACTCS ERROR REPORTING TEST
        $display("");
        $display("================================");
        $display("ABSTRACTCS ERROR REPORTING TEST");
        $display("================================");

        // Send an Unsupported Command
        $display("Sending Unsupported Abstract Command");

        shift_dmi(COMMAND, 32'hFF000000, DMI_WRITE);

        repeat (10)
            @(posedge clk);

        // Read ABSTRACTCS
        shift_dmi(ABSTRACTCS, 32'h00000000, DMI_READ);

        repeat (10)
            @(posedge clk);

        $display("ABSTRACTCS = %08h", dut.dm_rdata);

        // cmderr occupies bits [10:8]
        if (dut.dm_rdata[10:8] == 3'd2)
            $display("ABSTRACTCS CMDERR TEST PASS");
        else begin
            $display("ABSTRACTCS CMDERR TEST FAIL");
            $display("Expected cmderr = 2");
            $display("Received cmderr = %0d", dut.dm_rdata[10:8]);
        end

        // Clear CMDERR (Write 1 to cmderr bits)
        $display("");
        $display("Clearing CMDERR");

        shift_dmi(ABSTRACTCS, 32'h00000200, DMI_WRITE);

        repeat (10)
            @(posedge clk);

        // Read ABSTRACTCS Again
        shift_dmi(ABSTRACTCS, 32'h00000000, DMI_READ);

        repeat (10)
            @(posedge clk);

        $display("ABSTRACTCS = %08h", dut.dm_rdata);

        if (dut.dm_rdata[10:8] == 3'd0)
            $display("ABSTRACTCS CLEAR TEST PASS");
        else begin
            $display("ABSTRACTCS CLEAR TEST FAIL");
            $display("cmderr still = %0d", dut.dm_rdata[10:8]);
        end

        // ACCESS MEMORY - UNSUPPORTED SIZE TEST
        $display("");
        $display("================================");
        $display("ACCESS MEMORY UNSUPPORTED SIZE TEST");
        $display("================================");

        // DATA0 = Address
        shift_dmi(DATA0, 32'h20000000, DMI_WRITE);

        // aamsize = 00 (8-bit)
        // transfer = 1
        // write = 0
        // cmdtype = 2 (Access Memory)

        // Access Memory Read, 8-bit
        shift_dmi(COMMAND, 32'h02400000, DMI_WRITE);

        repeat (10)
            @(posedge clk);

        // Read ABSTRACTCS
        shift_dmi(ABSTRACTCS, 32'h00000000, DMI_READ);

        repeat (10)
            @(posedge clk);

        if (dut.dm_rdata[10:8] == 3'd2)
            $display("UNSUPPORTED MEMORY SIZE TEST PASS");
        else begin
            $display("UNSUPPORTED MEMORY SIZE TEST FAIL");
            $display("cmderr = %0d", dut.dm_rdata[10:8]);
        end

        // Clear cmderr
        shift_dmi(ABSTRACTCS, 32'h00000700, DMI_WRITE);

        repeat (5)
            @(posedge clk);

        // ACCESS MEMORY - MISALIGNED ADDRESS TEST
        $display("");
        $display("================================");
        $display("MISALIGNED MEMORY ACCESS TEST");
        $display("================================");

        // Address = 0x20000002
        shift_dmi(DATA0, 32'h20000002, DMI_WRITE);

        // Access Memory
        // aamsize = 10 (32-bit)
        // transfer = 1
        // write = 0

        // Access Memory Read, 32-bit
        shift_dmi(COMMAND, 32'h02440000, DMI_WRITE);

        repeat (10)
            @(posedge clk);

        // Read ABSTRACTCS
        shift_dmi(ABSTRACTCS, 32'h00000000, DMI_READ);

        repeat (10)
            @(posedge clk);

        if (dut.dm_rdata[10:8] == 3'd2)
            $display("MISALIGNED MEMORY TEST PASS");
        else begin
            $display("MISALIGNED MEMORY TEST FAIL");
            $display("cmderr = %0d", dut.dm_rdata[10:8]);
        end

        // Clear cmderr
        shift_dmi(ABSTRACTCS, 32'h00000700, DMI_WRITE);

        repeat (5)
            @(posedge clk);

        // Finish Simulation
        $display("================================");
        $display("TASK 4 COMPLETED");
        $display("================================");

        #100;
        $finish;
    end

    // CPU Monitor
    always @(posedge clk) begin
        $display("%0t  PC=%08h  halted=%b",
                 $time,
                 dut.debug_pc,
                 dut.debug_halted);
    end

endmodule
