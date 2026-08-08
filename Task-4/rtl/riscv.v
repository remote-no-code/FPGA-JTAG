`timescale 1ns/1ps
`default_nettype none

`include "clockworks.v"
`include "emitter_uart.v"

module Memory (
    input             clk,
    input      [31:0] mem_addr,
    output reg [31:0] mem_rdata,
    input             mem_rstrb,
    input      [31:0] mem_wdata,
    input      [3:0]  mem_wmask
);

reg [31:0] MEM [0:1535];

initial begin
    $readmemh("firmware.hex", MEM);
end

wire [29:0] word_addr = mem_addr[31:2];

always @(posedge clk) begin
    if (mem_rstrb)
        mem_rdata <= MEM[word_addr];

    if (mem_wmask[0]) MEM[word_addr][7:0]   <= mem_wdata[7:0];
    if (mem_wmask[1]) MEM[word_addr][15:8]  <= mem_wdata[15:8];
    if (mem_wmask[2]) MEM[word_addr][23:16] <= mem_wdata[23:16];
    if (mem_wmask[3]) MEM[word_addr][31:24] <= mem_wdata[31:24];
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

    input         debug_halt_req,
    input         debug_resume_req,
    input         debug_reset_req,

    output reg    debug_halted,
    output [31:0] debug_pc,

    input  [4:0]  debug_reg_addr,
    output [31:0] debug_reg_data,

    input         debug_reg_we,
    input  [31:0] debug_reg_wdata,

    input         debug_dcsr_we,
    input         debug_dpc_we,
    input  [31:0] debug_dcsr_wdata,
    input  [31:0] debug_dpc_wdata,

    output [31:0] debug_dcsr,
    output [31:0] debug_dpc
);

reg [31:0] PC = 32'd0;
reg [31:0] instr;
reg [31:0] dcsr;
reg [31:0] dpc;

assign debug_pc   = PC;
assign debug_dcsr = dcsr;
assign debug_dpc  = dpc;

// Instruction decode
wire [6:0] opcode = instr[6:0];
wire opcode_00 = (opcode[1:0] == 2'b11);

wire isALUreg = opcode_00 && (opcode[6:2] == 5'b01100);
wire isALUimm = opcode_00 && (opcode[6:2] == 5'b00100);
wire isLoad   = opcode_00 && (opcode[6:2] == 5'b00000);
wire isStore  = opcode_00 && (opcode[6:2] == 5'b01000);
wire isBranch = opcode_00 && (opcode[6:2] == 5'b11000);
wire isJALR   = opcode_00 && (opcode[6:2] == 5'b11001);
wire isJAL    = opcode_00 && (opcode[6:2] == 5'b11011);
wire isAUIPC  = opcode_00 && (opcode[6:2] == 5'b00101);
wire isLUI    = opcode_00 && (opcode[6:2] == 5'b01101);
wire isSYSTEM = opcode_00 && (opcode[6:2] == 5'b11100);

// Instruction fields and immediates
wire [31:0] Uimm = {instr[31], instr[30:12], 12'b0};
wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
wire [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25],
                    instr[11:8], 1'b0};
wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12], instr[20],
                    instr[30:21], 1'b0};

wire [4:0] rs1Id  = instr[19:15];
wire [4:0] rs2Id  = instr[24:20];
wire [4:0] rdId   = instr[11:7];
wire [2:0] funct3 = instr[14:12];
wire [6:0] funct7 = instr[31:25];

// Register file
reg [31:0] RegisterBank [1:31];
reg [31:0] rs1;
reg [31:0] rs2;

wire [31:0] rs1_read =
    (rs1Id == 5'd0) ? 32'd0 : RegisterBank[rs1Id];

wire [31:0] rs2_read =
    (rs2Id == 5'd0) ? 32'd0 : RegisterBank[rs2Id];

wire [31:0] debug_reg_read =
    (debug_reg_addr == 5'd0) ? 32'd0 : RegisterBank[debug_reg_addr];

reg [31:0] debug_reg_data_r;
assign debug_reg_data = debug_reg_data_r;

always @(posedge clk) begin
    debug_reg_data_r <= debug_reg_read;
end

integer i;

initial begin
    for (i = 1; i < 32; i = i + 1)
        RegisterBank[i] = 32'd0;
end

// ALU
reg [31:0] aluOut;

wire [31:0] aluIn1 = rs1;
wire [31:0] aluIn2 = (isALUreg || isBranch) ? rs2 : Iimm;
wire [31:0] aluPlus = aluIn1 + aluIn2;

wire [32:0] aluMinus =
    {1'b1, ~aluIn2} + {1'b0, aluIn1} + 33'b1;

wire LT  = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32];
wire LTU = aluMinus[32];
wire EQ  = (aluMinus[31:0] == 32'd0);

function [31:0] flip32;
    input [31:0] x;
    begin
        flip32 = {
            x[0],  x[1],  x[2],  x[3],  x[4],  x[5],  x[6],  x[7],
            x[8],  x[9],  x[10], x[11], x[12], x[13], x[14], x[15],
            x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
            x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]
        };
    end
endfunction

wire [31:0] shifter_in =
    (funct3 == 3'b001) ? flip32(aluIn1) : aluIn1;

wire [31:0] shifter =
    $signed({instr[30] & aluIn1[31], shifter_in}) >>> aluIn2[4:0];

wire [31:0] leftshift = flip32(shifter);

always @(*) begin
    case (funct3)
        3'b000:  aluOut = (funct7[5] & instr[5]) ?
                          aluMinus[31:0] : aluPlus;
        3'b001:  aluOut = leftshift;
        3'b010:  aluOut = {31'd0, LT};
        3'b011:  aluOut = {31'd0, LTU};
        3'b100:  aluOut = aluIn1 ^ aluIn2;
        3'b101:  aluOut = shifter;
        3'b110:  aluOut = aluIn1 | aluIn2;
        3'b111:  aluOut = aluIn1 & aluIn2;
        default: aluOut = 32'd0;
    endcase
end

// Branch condition
reg takeBranch;

always @(*) begin
    case (funct3)
        3'b000:  takeBranch = EQ;
        3'b001:  takeBranch = !EQ;
        3'b100:  takeBranch = LT;
        3'b101:  takeBranch = !LT;
        3'b110:  takeBranch = LTU;
        3'b111:  takeBranch = !LTU;
        default: takeBranch = 1'b0;
    endcase
end

// PC, memory, and writeback
wire [31:0] PCplusImm =
    PC + (instr[3] ? Jimm :
          instr[4] ? Uimm :
                     Bimm);

wire [31:0] PCplus4 = PC + 32'd4;

wire [31:0] loadstore_addr =
    rs1 + (isStore ? Simm : Iimm);

wire mem_byteAccess     = (funct3[1:0] == 2'b00);
wire mem_halfwordAccess = (funct3[1:0] == 2'b01);

wire [15:0] LOAD_halfword =
    loadstore_addr[1] ? mem_rdata[31:16] : mem_rdata[15:0];

wire [7:0] LOAD_byte =
    loadstore_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

wire LOAD_sign =
    !funct3[2] &
    (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

wire [31:0] LOAD_data =
    mem_byteAccess     ? {{24{LOAD_sign}}, LOAD_byte} :
    mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                         mem_rdata;

wire [31:0] writeBackData =
    (isJAL || isJALR) ? PCplus4 :
    isLUI             ? Uimm :
    isAUIPC           ? PCplusImm :
    isLoad            ? LOAD_data :
                        aluOut;

wire [31:0] nextPC =
    ((isBranch && takeBranch) || isJAL) ? PCplusImm :
    isJALR ? {aluPlus[31:1], 1'b0} :
             PCplus4;

assign mem_wdata[7:0] = rs2[7:0];

assign mem_wdata[15:8] =
    loadstore_addr[0] ? rs2[7:0] : rs2[15:8];

assign mem_wdata[23:16] =
    loadstore_addr[1] ? rs2[7:0] : rs2[23:16];

assign mem_wdata[31:24] =
    loadstore_addr[0] ? rs2[7:0] :
    loadstore_addr[1] ? rs2[15:8] :
                        rs2[31:24];

wire [3:0] STORE_wmask =
    mem_byteAccess ?
        (loadstore_addr[1] ?
            (loadstore_addr[0] ? 4'b1000 : 4'b0100) :
            (loadstore_addr[0] ? 4'b0010 : 4'b0001)
        ) :
    mem_halfwordAccess ?
        (loadstore_addr[1] ? 4'b1100 : 4'b0011) :
        4'b1111;

// Processor state machine
localparam FETCH_INSTR = 3'd0;
localparam WAIT_INSTR  = 3'd1;
localparam FETCH_REGS  = 3'd2;
localparam EXECUTE     = 3'd3;
localparam LOAD        = 3'd4;
localparam WAIT_DATA   = 3'd5;
localparam STORE       = 3'd6;

reg [2:0] state = FETCH_INSTR;

wire halted_next =
    debug_reset_req  ? 1'b0 :
    debug_resume_req ? 1'b0 :
    debug_halt_req   ? 1'b1 :
                       debug_halted;

wire writeBackEn =
    (state == EXECUTE && !isBranch && !isStore) ||
    (state == WAIT_DATA);

assign mem_addr =
    (state == WAIT_INSTR || state == FETCH_INSTR) ?
    PC : loadstore_addr;

assign mem_rstrb =
    (state == FETCH_INSTR || state == LOAD);

assign mem_wmask =
    {4{state == STORE}} & STORE_wmask;

// Sequential control
always @(posedge clk) begin
    if (debug_reset_req || !resetn) begin
        PC           <= 32'd0;
        dpc          <= 32'd0;
        dcsr         <= 32'd0;
        state        <= FETCH_INSTR;
        debug_halted <= 1'b0;
    end
    else begin
        if (debug_halt_req) begin
            debug_halted <= 1'b1;
            dpc          <= PC;
            dcsr         <= 32'd0;
        end

        if (debug_resume_req) begin
            debug_halted <= 1'b0;
            state        <= FETCH_INSTR;
        end

        // Debug write has priority over normal CPU writeback
        if (debug_reg_we) begin
            if (debug_reg_addr != 5'd0)
                RegisterBank[debug_reg_addr] <= debug_reg_wdata;
        end
        else if (writeBackEn && !halted_next && (rdId != 5'd0)) begin
            RegisterBank[rdId] <= writeBackData;
        end

        if (debug_dcsr_we)
            dcsr <= debug_dcsr_wdata;

        if (debug_dpc_we) begin
            dpc <= debug_dpc_wdata;
            PC  <= debug_dpc_wdata;
        end

        if (!halted_next) begin
            case (state)
                FETCH_INSTR: begin
                    state <= WAIT_INSTR;
                end

                WAIT_INSTR: begin
                    instr <= mem_rdata;
                    state <= FETCH_REGS;
                end

                FETCH_REGS: begin
                    rs1   <= rs1_read;
                    rs2   <= rs2_read;
                    state <= EXECUTE;
                end

                EXECUTE: begin
                    PC    <= nextPC;
                    state <= FETCH_INSTR;

`ifdef BENCH
                    if (isSYSTEM)
                        $finish;
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

                default: begin
                    state <= FETCH_INSTR;
                end
            endcase
        end
    end
end

endmodule


module SOC (
    input  wire CLK,
    input  wire RESET,

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

    input  wire RXD,
    output wire TXD
);

// RISC-V Debug Specification
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

// Debug Adapter -> CPU
wire debug_halt_req;
wire debug_resume_req;
wire debug_reset_req;

// CPU Debug Status
wire        debug_halted;
wire [31:0] debug_pc;
wire [4:0]  debug_reg_addr;
wire [31:0] debug_reg_data;

// Debug Memory Interface
wire        dbg_mem_valid;
wire        dbg_mem_write;
wire [31:0] dbg_mem_addr;
wire [31:0] dbg_mem_wdata;
wire [31:0] dbg_mem_rdata;
wire        dbg_mem_ready;

wire        debug_reg_we;
wire [31:0] debug_reg_wdata;
wire        debug_running;

wire [31:0] debug_dcsr;
wire [31:0] debug_dpc;
wire        debug_dcsr_we;
wire        debug_dpc_we;
wire [31:0] debug_dcsr_wdata;
wire [31:0] debug_dpc_wdata;

assign debug_running = ~debug_halted;

// Clock and reset
wire clk;
wire resetn;

// Heartbeat LED counter
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
        reset_led_counter <= 24'hFFFFFF;
    else if (reset_led_counter != 0)
        reset_led_counter <= reset_led_counter - 1'b1;
end

assign LED5 = (reset_led_counter != 0);

reg [23:0] resume_led_counter;

always @(posedge clk or negedge resetn) begin
    if (!resetn)
        resume_led_counter <= 24'd0;
    else if (debug_resume_req)
        resume_led_counter <= 24'hFFFFFF;
    else if (resume_led_counter != 24'd0)
        resume_led_counter <= resume_led_counter - 1'b1;
end

assign LED6 = (resume_led_counter != 0);

assign LED1 = heartbeat_counter[23];
assign LED2 = debug_running;
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

// CPU bus
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

    .debug_reg_we     (debug_reg_we),
    .debug_reg_wdata  (debug_reg_wdata),

    .debug_dcsr       (debug_dcsr),
    .debug_dpc        (debug_dpc),

    .debug_dcsr_we    (debug_dcsr_we),
    .debug_dpc_we     (debug_dpc_we),

    .debug_dcsr_wdata (debug_dcsr_wdata),
    .debug_dpc_wdata  (debug_dpc_wdata)
);

// Address decode
localparam UART_BASE = 32'h4000_0000;

wire is_uart = (mem_addr[31:12] == UART_BASE[31:12]);
wire is_ram  = ~is_uart;

// RAM
wire [31:0] ram_rdata;

// RAM arbiter
wire [31:0] ram_addr;
wire        ram_rstrb;
wire [31:0] ram_wdata;
wire [3:0]  ram_wmask;

assign ram_addr =
    (debug_halted && dbg_mem_valid) ? dbg_mem_addr : mem_addr;

assign ram_rstrb =
    (debug_halted && dbg_mem_valid) ? ~dbg_mem_write :
    (is_ram & mem_rstrb);

assign ram_wdata =
    (debug_halted && dbg_mem_valid) ? dbg_mem_wdata : mem_wdata;

assign ram_wmask =
    (debug_halted && dbg_mem_valid) ?
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

wire [31:0] uart_rdata;

assign mem_rdata =
    is_ram  ? ram_rdata :
    is_uart ? uart_rdata :
              32'h00000000;

riscv_jtag_dtm dtm (
    .tck        (tck),
    .tms        (tms),
    .tdi        (tdi),
    .n_trst     (trst),
    .tdo        (tdo),

    .dmi_valid  (dmi_valid),
    .dmi_addr   (dmi_addr),
    .dmi_wdata  (dmi_wdata),
    .dmi_op     (dmi_op),

    .resp_valid (resp_valid),
    .resp_data  (resp_data),
    .resp_resp  (resp_resp),

    .req_ready  (req_ready)
);

dmi_cdc dmi_cdc_inst (
    .tck        (tck),
    .trst_n     (trst),

    .req_valid  (dmi_valid),
    .req_addr   (dmi_addr),
    .req_data   (dmi_wdata),
    .req_op     (dmi_op),

    .req_ready  (req_ready),

    .clk        (clk),
    .resetn     (resetn),

    .dmi_valid  (cdc_dmi_valid),
    .dmi_addr   (cdc_dmi_addr),
    .dmi_data   (cdc_dmi_wdata),
    .dmi_op     (cdc_dmi_op),

    // Response from DMI Interface
    .dmi_ready  (dmi_ready),
    .dmi_rdata  (dmi_rdata),
    .dmi_resp   (dmi_resp),

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

    .dmi_ready (dmi_ready),
    .dmi_rdata (dmi_rdata),
    .dmi_resp  (dmi_resp)
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

    .debug_reg_we   (debug_reg_we),
    .debug_reg_wdata(debug_reg_wdata),

    .mem_rdata      (dbg_mem_rdata),
    .mem_ready      (dbg_mem_ready),

    .debug_dcsr     (debug_dcsr),
    .debug_dpc      (debug_dpc),

    .debug_dcsr_we  (debug_dcsr_we),
    .debug_dpc_we   (debug_dpc_we),

    .debug_dcsr_wdata(debug_dcsr_wdata),
    .debug_dpc_wdata (debug_dpc_wdata)
);

core_debug_adapter adapter (
    .clk            (clk),
    .reset          (!resetn),

    .dmcontrol      (dmcontrol),

    .halt_req       (debug_halt_req),
    .resume_req     (debug_resume_req),
    .reset_req      (debug_reset_req),

    .debug_dcsr     (debug_dcsr),
    .debug_dpc      (debug_dpc),

    .debug_dcsr_we  (debug_dcsr_we),
    .debug_dpc_we   (debug_dpc_we),

    .debug_dcsr_wdata(debug_dcsr_wdata),
    .debug_dpc_wdata (debug_dpc_wdata)
);

endmodule
