
`timescale 1ns/1ps
`default_nettype none

`include "clockworks.v"
`include "emitter_uart.v"

module Memory (
    input             clk,
    input      [31:0] mem_addr,   // address to be read
    output reg [31:0] mem_rdata,  // data read from memory
    input             mem_rstrb,  // goes high when processor wants to read
    input      [31:0] mem_wdata,  // data to be written
    input      [3:0]  mem_wmask   // masks for writing the 4 bytes (1 = write byte)
);

    reg [31:0] MEM [0:1535]; // 1536 4-byte words = 6 KB of RAM in total

    initial begin
        $readmemh("firmware.hex", MEM);
    end

    wire [29:0] word_addr = mem_addr[31:2];

    always @(posedge clk) begin

`ifdef DISPLAY
        if (mem_rstrb)
            $display("%0t RAM READ  addr=%08h data=%08h", $time, mem_addr, MEM[word_addr]);

        if (mem_wmask != 4'b0000)
            $display("%0t RAM WRITE addr=%08h data=%08h", $time, mem_addr, mem_wdata);
`endif

        if (mem_rstrb)
            mem_rdata <= MEM[word_addr];

        if (mem_wmask[0]) MEM[word_addr][7:0]   <= mem_wdata[7:0];
        if (mem_wmask[1]) MEM[word_addr][15:8]  <= mem_wdata[15:8];
        if (mem_wmask[2]) MEM[word_addr][23:16] <= mem_wdata[23:16];
        if (mem_wmask[3]) MEM[word_addr][31:24] <= mem_wdata[31:24];

`ifdef DISPLAY
        if (mem_rstrb)
            $display("%0t RAM READ  addr=%08h data=%08h", $time, mem_addr, MEM[word_addr]);

        if (mem_wmask != 4'b0000)
            $display("%0t RAM WRITE addr=%08h data=%08h", $time, mem_addr, mem_wdata);
`endif

    end

endmodule

module Processor (
    input         clk,
    input         resetn,
    output [31:0] mem_addr,
    input  [31:0] mem_rdata,
    output        mem_rstrb,
    output [31:0] mem_wdata,
    output [3:0]  mem_wmask,

    // JTAG
    input         debug_halt_req,
    input         debug_resume_req,
    input         debug_reset_req,

    output reg    debug_halted,
    output [31:0] debug_pc,

    input  [4:0]  debug_reg_addr,
    output [31:0] debug_reg_data,

    input         debug_reg_we,
    input  [31:0] debug_reg_wdata
);

    reg [31:0] debug_reg_data_r;
    assign debug_reg_data = debug_reg_data_r;

    always @(posedge clk) begin
        debug_reg_data_r <= RegisterBank[debug_reg_addr];
    end

`ifdef DISPLAY
    always @(posedge clk) begin
        $display("%0t PROC capture: addr=%0d reg=%08h data_r(before)=%08h",
                 $time,
                 debug_reg_addr,
                 RegisterBank[debug_reg_addr],
                 debug_reg_data_r);
    end
`endif

    reg [31:0] PC    = 0;  // program counter
    reg [31:0] instr;      // current instruction

    // JTAG
    assign debug_pc = PC;

`ifdef DISPLAY
    always @(posedge clk) begin
        $display("%0t TOP: debug_reg_we=%b addr=%0d data=%08h",
                 $time,
                 debug_reg_we,
                 debug_reg_addr,
                 debug_reg_wdata);
    end
`endif

    //--------------------------------------------------
    // ALU Output
    //--------------------------------------------------
    reg [31:0] aluOut;

    // The 10 RISC-V instructions
    wire isALUreg = (instr[6:0] == 7'b0110011); // rd <- rs1 OP rs2
    wire isALUimm = (instr[6:0] == 7'b0010011); // rd <- rs1 OP Iimm
    wire isBranch = (instr[6:0] == 7'b1100011); // if(rs1 OP rs2) PC <- PC + Bimm
    wire isJALR   = (instr[6:0] == 7'b1100111); // rd <- PC+4; PC <- rs1 + Iimm
    wire isJAL    = (instr[6:0] == 7'b1101111); // rd <- PC+4; PC <- PC + Jimm
    wire isAUIPC  = (instr[6:0] == 7'b0010111); // rd <- PC + Uimm
    wire isLUI    = (instr[6:0] == 7'b0110111); // rd <- Uimm
    wire isLoad   = (instr[6:0] == 7'b0000011); // rd <- mem[rs1 + Iimm]
    wire isStore  = (instr[6:0] == 7'b0100011); // mem[rs1 + Simm] <- rs2
    wire isSYSTEM = (instr[6:0] == 7'b1110011); // special

    // The 5 immediate formats
    wire [31:0] Uimm = {    instr[31],    instr[30:12],               {12{1'b0}}};
    wire [31:0] Iimm = {{21{instr[31]}},  instr[30:20]};
    wire [31:0] Simm = {{21{instr[31]}},  instr[30:25], instr[11:7]};
    wire [31:0] Bimm = {{20{instr[31]}},  instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] Jimm = {{12{instr[31]}},  instr[19:12], instr[20], instr[30:21], 1'b0};

    // Source and destination registers
    wire [4:0] rs1Id = instr[19:15];
    wire [4:0] rs2Id = instr[24:20];
    wire [4:0] rdId  = instr[11:7];

    // Function codes
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    // The register bank
    reg  [31:0] RegisterBank [0:31];
    reg  [31:0] rs1;             // value of source register 1
    reg  [31:0] rs2;             // value of source register 2
    wire [31:0] writeBackData;   // data to be written to rd
    wire        writeBackEn;     // asserted if data should be written to rd

    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            RegisterBank[i] = 0;
    end

   // The ALU
    wire [31:0] aluIn1 = rs1;
    wire [31:0] aluIn2 = (isALUreg || isBranch) ? rs2 : Iimm;

    wire [4:0] shamt = isALUreg ? rs2[4:0] : instr[24:20]; // shift amount

    // The adder is used by both arithmetic instructions and JALR.
    wire [31:0] aluPlus = aluIn1 + aluIn2;

    // Use a single 33-bit subtract to do subtraction and all comparisons
    // (trick borrowed from swapforth/J1)
    wire [32:0] aluMinus = {1'b1, ~aluIn2} + {1'b0, aluIn1} + 33'b1;
    wire        LT  = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32];
    wire        LTU = aluMinus[32];
    wire        EQ  = (aluMinus[31:0] == 0);

    // Flip a 32-bit word. Used by the shifter (a single shifter for
    // left and right shifts, saves silicon!)
    function [31:0] flip32;
        input [31:0] x;
        flip32 = {
            x[0],  x[1],  x[2],  x[3],  x[4],  x[5],  x[6],  x[7],
            x[8],  x[9],  x[10], x[11], x[12], x[13], x[14], x[15],
            x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
            x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]
        };
    endfunction

    wire [31:0] shifter_in = (funct3 == 3'b001) ? flip32(aluIn1) : aluIn1;

    /* verilator lint_off WIDTH */
    wire [31:0] shifter = $signed({instr[30] & aluIn1[31], shifter_in}) >>> aluIn2[4:0];
    /* verilator lint_on WIDTH */

    wire [31:0] leftshift = flip32(shifter);

    always @(*) begin
        case (funct3)
            3'b000: aluOut = (funct7[5] & instr[5]) ? aluMinus[31:0] : aluPlus;
            3'b001: aluOut = leftshift;
            3'b010: aluOut = {31'b0, LT};
            3'b011: aluOut = {31'b0, LTU};
            3'b100: aluOut = (aluIn1 ^ aluIn2);
            3'b101: aluOut = shifter;
            3'b110: aluOut = (aluIn1 | aluIn2);
            3'b111: aluOut = (aluIn1 & aluIn2);
        endcase
    end

    // The predicate for branch instructions
    reg takeBranch;

    always @(*) begin
        case (funct3)
            3'b000: takeBranch = EQ;
            3'b001: takeBranch = !EQ;
            3'b100: takeBranch = LT;
            3'b101: takeBranch = !LT;
            3'b110: takeBranch = LTU;
            3'b111: takeBranch = !LTU;
            default: takeBranch = 1'b0;
        endcase
    end

    wire [31:0] PCplusImm = PC + (instr[3] ? Jimm :
                                  instr[4] ? Uimm :
                                             Bimm);

    wire [31:0] PCplus4 = PC + 4;

    // Register write back
    assign writeBackData = (isJAL || isJALR) ? PCplus4 :
                           isLUI             ? Uimm :
                           isAUIPC           ? PCplusImm :
                           isLoad            ? LOAD_data :
                                               aluOut;

    wire [31:0] nextPC = ((isBranch && takeBranch) || isJAL) ? PCplusImm :
                         isJALR                              ? {aluPlus[31:1], 1'b0} :
                                                               PCplus4;

    wire [31:0] loadstore_addr = rs1 + (isStore ? Simm : Iimm);

    wire mem_byteAccess     = (funct3[1:0] == 2'b00);
    wire mem_halfwordAccess = (funct3[1:0] == 2'b01);

    wire [15:0] LOAD_halfword = loadstore_addr[1] ? mem_rdata[31:16] : mem_rdata[15:0];

    wire [7:0] LOAD_byte = loadstore_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

    wire LOAD_sign = !funct3[2] & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

    wire [31:0] LOAD_data =
        mem_byteAccess     ? {{24{LOAD_sign}}, LOAD_byte} :
        mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                             mem_rdata;

    // Store
    // ------------------------------------------------------------------------

    assign mem_wdata[7:0]   = rs2[7:0];
    assign mem_wdata[15:8]  = loadstore_addr[0] ? rs2[7:0] : rs2[15:8];
    assign mem_wdata[23:16] = loadstore_addr[1] ? rs2[7:0] : rs2[23:16];
    assign mem_wdata[31:24] = loadstore_addr[0] ? rs2[7:0] :
                              loadstore_addr[1] ? rs2[15:8] : rs2[31:24];

    wire [3:0] STORE_wmask =
        mem_byteAccess ?
            (loadstore_addr[1] ?
                (loadstore_addr[0] ? 4'b1000 : 4'b0100) :
                (loadstore_addr[0] ? 4'b0010 : 4'b0001)
            ) :
        mem_halfwordAccess ?
            (loadstore_addr[1] ? 4'b1100 : 4'b0011) :
            4'b1111;

    // The state machine
    localparam FETCH_INSTR = 0;
    localparam WAIT_INSTR  = 1;
    localparam FETCH_REGS  = 2;
    localparam EXECUTE     = 3;
    localparam LOAD        = 4;
    localparam WAIT_DATA   = 5;
    localparam STORE       = 6;

    reg [2:0] state = FETCH_INSTR;

    wire halted_next =
        debug_reset_req  ? 1'b0 :
        debug_resume_req ? 1'b0 :
        debug_halt_req   ? 1'b1 :
                           debug_halted;

    always @(posedge clk) begin

    `ifdef DISPLAY
            $display("%0t state=%0d halted=%b halt=%b resume=%b",
                     $time, state, debug_halted, debug_halt_req, debug_resume_req);
    `endif

            //--------------------------------------------------
            // Reset
            //--------------------------------------------------
            if (debug_reset_req) begin
    `ifdef DISPLAY
                $display("%0t CPU RESET RECEIVED", $time);
    `endif

                PC           <= 0;
                state        <= FETCH_INSTR;
                debug_halted <= 1'b0;
            end
            else if (!resetn) begin
                PC           <= 0;
                state        <= FETCH_INSTR;
                debug_halted <= 1'b0;
            end
            else begin

                //--------------------------------------------------
                // Debug halt
                //--------------------------------------------------

                if (debug_halt_req) begin
    `ifdef DISPLAY
                    $display("%0t CPU: halt request received", $time);
    `endif
                    debug_halted <= 1'b1;
                end

    `ifdef DISPLAY
                $strobe("%0t debug_halted(after NBA)=%b", $time, debug_halted);
    `endif

                //--------------------------------------------------
                // Debug resume
                //--------------------------------------------------
                if (debug_resume_req) begin
                    debug_halted <= 1'b0;
    `ifdef DISPLAY
                    $display("%0t CPU: resume request received", $time);
    `endif
                    state <= FETCH_INSTR;
                end

    `ifdef DISPLAY
                $strobe("%0t CPU debug_halted=%b", $time, debug_halted);
    `endif

                if (debug_reg_we) begin
                    if (debug_reg_addr != 5'd0) begin
                        RegisterBank[debug_reg_addr] <= debug_reg_wdata;

    `ifdef DISPLAY
                        $display("%0t DEBUG WRITE x%0d <= %08h",
                                 $time,
                                 debug_reg_addr,
                                 debug_reg_wdata);
    `endif
                    end
                end
                else if (writeBackEn && !halted_next && (rdId != 0)) begin
                    RegisterBank[rdId] <= writeBackData;
                end

                //--------------------------------------------------
                // Freeze processor while halted
                //--------------------------------------------------
                if (halted_next) begin
                    state <= state;
                    PC    <= PC;
                end
                else begin

               

                //--------------------------------------------------
                // CPU State Machine
                //--------------------------------------------------
                case (state)

                    FETCH_INSTR: begin
                        state <= WAIT_INSTR;
                    end

                    WAIT_INSTR: begin
`ifdef DISPLAY
                        $display("%0t WAIT_INSTR  mem_addr=%08h  mem_rdata=%08h",
                                 $time, mem_addr, mem_rdata);
`endif

                        instr <= mem_rdata;
                        state <= FETCH_REGS;
                    end

                    FETCH_REGS: begin
`ifdef DISPLAY
                        $display("%0t ENTER FETCH_REGS", $time);
`endif

                        rs1   <= RegisterBank[rs1Id];
                        rs2   <= RegisterBank[rs2Id];
                        state <= EXECUTE;
                    end

                    EXECUTE: begin
`ifdef DISPLAY
                        $display("%0t ENTER EXECUTE", $time);
                        $display("PC=%08h nextPC=%08h", PC, nextPC);
`endif

                        PC <= nextPC;

`ifdef DISPLAY
                        $display("Assigned PC <= %08h", nextPC);
`endif

                        state <= FETCH_INSTR;

    `ifdef BENCH
                        if (isSYSTEM)
                            $finish();
    `endif
                    end

                    LOAD: begin
                        state <= WAIT_DATA;
                    end

                    WAIT_DATA: begin
                        state <= FETCH_INSTR;
                    end

                    STORE: begin
                        state <= FETCH_INSTR;
                    end

                endcase

            end // !halted_next

        end // !resetn

    end

`ifdef DISPLAY
    always @(posedge clk) begin
        $strobe("%0t TOP1: debug_reg_we=%b addr=%0d data=%08h",
                $time,
                debug_reg_we,
                debug_reg_addr,
                debug_reg_wdata);
    end

    always @(posedge clk) begin
        if (debug_reg_we)
            $strobe("%0t 0PROC sees debug_reg_we=1 addr=%0d data=%08h",
                    $time,
                    debug_reg_addr,
                    debug_reg_wdata);
    end

    always @(posedge clk)
        if (debug_reg_we)
            #1 $display("VERIFY x%0d = %08h",
                        debug_reg_addr,
                        RegisterBank[debug_reg_addr]);

    always @(posedge clk) begin
        if (debug_resume_req)
            $display("%0t debug_resume_req pulse", $time);
    end

    always @(posedge clk) begin

        if (debug_halt_req)
            $display("%0t HALT REQUEST", $time);

        if (debug_resume_req)
            $display("%0t RESUME REQUEST", $time);

        if (debug_reset_req)
            $display("%0t RESET REQUEST", $time);

    end
`endif

    assign writeBackEn = (state == EXECUTE && !isBranch && !isStore) ||
                         (state == WAIT_DATA);

    assign mem_addr  = (state == WAIT_INSTR || state == FETCH_INSTR) ? PC : loadstore_addr;
    assign mem_rstrb = (state == FETCH_INSTR || state == LOAD);
    assign mem_wmask = {4{(state == STORE)}} & STORE_wmask;

`ifdef DISPLAY
    always @(posedge clk) begin
        $display("%m  time=%0t  PC=%08h  HALTED=%b", $time, PC, debug_halted);
    end

    always @(PC)
        $display("%0t PC CHANGED -> %08h", $time, PC);

    always @(posedge clk) begin
        $display("%0t CPU halt_req=%b halted=%b", $time, debug_halt_req, debug_halted);
    end
`endif

endmodule

module SOC (

    //--------------------------------------------------
    // Clock / Reset
    //--------------------------------------------------
    input  wire CLK,
    input  wire RESET,

    //--------------------------------------------------
    // JTAG Interface
    //--------------------------------------------------
    input  wire tck,
    input  wire tms,
    input  wire tdi,
    input  wire trst,

    output wire tdo,
    output wire LED1,
    output wire LED2,
    output wire LED3,
    output wire LED4,
    output wire LED5,
    output wire LED6,
    output wire LED7,
    

    //--------------------------------------------------
    // UART
    //--------------------------------------------------
    input  wire RXD,
    output wire TXD

);

    //--------------------------------------------------
    // External Debug LEDs
    //--------------------------------------------------


    //--------------------------------------------------
    // RISC-V Debug Specification
    //--------------------------------------------------
    wire        dmi_valid;
    wire [6:0]  dmi_addr;
    wire [31:0] dmi_wdata;
    wire [1:0]  dmi_op;

    wire        dm_valid;
    wire [6:0]  dm_addr;
    wire [31:0] dm_wdata;
    wire [1:0]  dm_op;

    wire        cdc_dmi_valid;
    wire [6:0]  cdc_dmi_addr;
    wire [31:0] cdc_dmi_wdata;
    wire [1:0]  cdc_dmi_op;

    wire        req_ready;

    wire        dm_ready;
    wire [31:0] dm_rdata;
    wire [1:0]  dm_resp;

    wire        dmi_ready;
    wire [31:0] dmi_rdata;
    wire [1:0]  dmi_resp;
     
    // CDC -> DTM response
    wire        resp_valid;
    wire [31:0] resp_data;
    wire [1:0]  resp_resp;
    
    wire [31:0] dmcontrol;

    //------------------------------
    // Debug Adapter -> CPU
    //------------------------------
    wire debug_halt_req;
    wire debug_resume_req;
    wire debug_reset_req;

    //------------------------------
    // CPU Debug Status
    //------------------------------
    wire        debug_halted;
    wire [31:0] debug_pc;

    wire [4:0]  debug_reg_addr;
    wire [31:0] debug_reg_data;

    //--------------------------------------------------
    // Debug Memory Interface
    //--------------------------------------------------
    wire        dbg_mem_valid;
    wire        dbg_mem_write;

    wire [31:0] dbg_mem_addr;
    wire [31:0] dbg_mem_wdata;

    wire [31:0] dbg_mem_rdata;
    wire        dbg_mem_ready;
    
    wire        debug_reg_we;
    wire [31:0] debug_reg_wdata;
    wire        debug_running;

    assign debug_running = ~debug_halted;

    // ============================================================
    // Clock & Reset
    // ============================================================
    wire clk;
    wire resetn;

    //============================================================
    // Heartbeat LED Counter
    //============================================================
    reg [23:0] heartbeat_counter;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            heartbeat_counter <= 24'd0;
        else
            heartbeat_counter <= heartbeat_counter + 1'b1;
    end
    reg [23:0] reset_led_counter;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            reset_led_counter <= 24'd0;
        else if (debug_reset_req)
            reset_led_counter <= 24'hFFFFFF;   // load counter
        else if (reset_led_counter != 0)
            reset_led_counter <= reset_led_counter - 1'b1;
    end

    assign LED5 = (reset_led_counter != 0);
    
    reg [23:0] resume_led_counter;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            resume_led_counter <= 24'd0;
        else if (debug_resume_req)
            resume_led_counter <= 24'hFFFFFF;   // Load counter on resume pulse
        else if (resume_led_counter != 24'd0)
            resume_led_counter <= resume_led_counter - 1'b1;
    end

    assign LED6 = (resume_led_counter != 24'd0);
    
    assign LED1 = heartbeat_counter[23]; // Heartbeat
    assign LED2 = debug_running;         // CPU Running
    assign LED3 = debug_halted;
    assign LED4 = dmi_valid;
    assign LED7 = tdo;
`ifndef SYNTHESIS

    reg clk_sim = 0;
    reg rst_sim = 1;

    always #5 clk_sim = ~clk_sim;

    initial begin
        #100 rst_sim = 0;
    end

    assign clk    = clk_sim;
    assign resetn = ~rst_sim;

    initial begin
        $dumpfile("soc.vcd");
        $dumpvars(0, SOC);
    end

`else

    Clockworks #(.SLOW(0)) CW (
        .CLK    (CLK),
        .RESET  (RESET),
        .clk    (clk),
        .resetn (resetn)
    );

`endif

    // ============================================================
    // CPU ↔ BUS
    // ============================================================
    wire [31:0] mem_addr;
    wire [31:0] mem_rdata;
    wire        mem_rstrb;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;

    Processor CPU (
        .clk              (clk),
        .resetn           (resetn),
        .mem_addr         (mem_addr),
        .mem_rdata        (mem_rdata),
        .mem_rstrb        (mem_rstrb),
        .mem_wdata        (mem_wdata),
        .mem_wmask        (mem_wmask),

        .debug_halt_req   (debug_halt_req),
        .debug_resume_req (debug_resume_req),
        .debug_reset_req  (debug_reset_req),

        .debug_halted     (debug_halted),
        .debug_pc         (debug_pc),

        .debug_reg_addr   (debug_reg_addr),
        .debug_reg_data   (debug_reg_data),
        
        .debug_reg_we(debug_reg_we),
        .debug_reg_wdata(debug_reg_wdata)
    );

    // ============================================================
    // Address Decode
    // ============================================================
    localparam UART_BASE = 32'h4000_0000;

    wire is_uart = (mem_addr[31:12] == UART_BASE[31:12]);
    wire is_ram  = ~is_uart;

    // ============================================================
    // RAM
    // ============================================================
    wire [31:0] ram_rdata;

    // RAM Arbiter
    //--------------------------------------------------
    wire [31:0] ram_addr;
    wire        ram_rstrb;
    wire [31:0] ram_wdata;
    wire [3:0]  ram_wmask;

    assign ram_addr  = (debug_halted && dbg_mem_valid) ? dbg_mem_addr : mem_addr;
    assign ram_rstrb = (debug_halted && dbg_mem_valid) ? ~dbg_mem_write : (is_ram & mem_rstrb);
    assign ram_wdata = (debug_halted && dbg_mem_valid) ? dbg_mem_wdata : mem_wdata;
    assign ram_wmask = (debug_halted && dbg_mem_valid) ?
                       (dbg_mem_write ? 4'b1111 : 4'b0000) :
                       ({4{is_ram}} & mem_wmask);

    Memory RAM (
        .clk       (clk),
        .mem_addr  (ram_addr),
        .mem_rdata (ram_rdata),
        .mem_rstrb (ram_rstrb),
        .mem_wdata (ram_wdata),
        .mem_wmask (ram_wmask)
    );

    reg dbg_mem_ready_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            dbg_mem_ready_r <= 1'b0;
        else
            dbg_mem_ready_r <= debug_halted && dbg_mem_valid;
    end

    assign dbg_mem_ready = dbg_mem_ready_r;
    assign dbg_mem_rdata = ram_rdata;
    
    wire [31:0] uart_rdata;   // if UART returns read data
   
    assign mem_rdata =
        is_ram  ? ram_rdata :
        is_uart ? uart_rdata :
                  32'h00000000;
                


    riscv_jtag_dtm dtm (
        .tck       (tck),
        .tms       (tms),
        .tdi       (tdi),
        .n_trst    (trst),

        .tdo       (tdo),

        .dmi_valid (dmi_valid),
        .dmi_addr  (dmi_addr),
        .dmi_wdata (dmi_wdata),
        .dmi_op    (dmi_op),

        .resp_valid (resp_valid),
        .resp_data  (resp_data),
        .resp_resp  (resp_resp),

        .req_ready (req_ready)
    );

    dmi_cdc dmi_cdc_inst (
        .tck       (tck),
        .trst_n    (trst),

        .req_valid (dmi_valid),
        .req_addr  (dmi_addr),
        .req_data  (dmi_wdata),
        .req_op    (dmi_op),

        .req_ready (req_ready),

        .clk       (clk),
        .resetn    (resetn),

        .dmi_valid (cdc_dmi_valid),
        .dmi_addr  (cdc_dmi_addr),
        .dmi_data  (cdc_dmi_wdata),
        .dmi_op    (cdc_dmi_op),

        // Response from DMI Interface
        .dmi_ready (dmi_ready),
        .dmi_rdata (dmi_rdata),
        .dmi_resp  (dmi_resp),

        // Response back to DTM
        .resp_valid (resp_valid),
        .resp_data  (resp_data),
        .resp_resp  (resp_resp)
        
    );

    dmi_interface dmi_if (
        .clk       (clk),
        .reset     (!resetn),

        .dmi_valid (cdc_dmi_valid),
        .dmi_addr  (cdc_dmi_addr),
        .dmi_wdata (cdc_dmi_wdata),
        .dmi_op    (cdc_dmi_op),

        .dm_valid  (dm_valid),
        .dm_addr   (dm_addr),
        .dm_wdata  (dm_wdata),
        .dm_op     (dm_op),

        .dm_ready  (dm_ready),
        .dm_rdata  (dm_rdata),
        .dm_resp   (dm_resp),

        .dmi_ready(dmi_ready),
        .dmi_rdata(dmi_rdata),
        .dmi_resp(dmi_resp)
    );

    riscv_debug_module_minimal debug_module (
        .clk            (clk),
        .reset          (!resetn),

        .dm_valid       (dm_valid),
        .dm_addr        (dm_addr),
        .dm_wdata       (dm_wdata),
        .dm_op          (dm_op),

        .dm_ready       (dm_ready),
        .dm_rdata       (dm_rdata),
        .dm_resp        (dm_resp),

        .debug_halted   (debug_halted),
        .debug_pc       (debug_pc),
        .debug_reg_data (debug_reg_data),
        .debug_reg_addr (debug_reg_addr),

        .dmcontrol      (dmcontrol),

        .mem_valid      (dbg_mem_valid),
        .mem_write      (dbg_mem_write),

        .mem_addr       (dbg_mem_addr),
        .mem_wdata      (dbg_mem_wdata),
        
        .debug_reg_we(debug_reg_we),
        .debug_reg_wdata(debug_reg_wdata),

        .mem_rdata      (dbg_mem_rdata),
        .mem_ready      (dbg_mem_ready)
    );

    core_debug_adapter adapter (
        .clk        (clk),
        .reset      (!resetn),

        .dmcontrol  (dmcontrol),

        .halt_req   (debug_halt_req),
        .resume_req (debug_resume_req),
        .reset_req  (debug_reset_req)
    );


endmodule
