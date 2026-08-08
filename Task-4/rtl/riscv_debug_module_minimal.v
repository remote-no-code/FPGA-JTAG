// Minimal RISC-V Debug Module
module riscv_debug_module_minimal(
    input wire        clk,
    input wire        reset,

    // DMI request
    input wire        dm_valid,
    input wire [6:0]  dm_addr,
    input wire [31:0] dm_wdata,
    input wire [1:0]  dm_op,

    // DMI response
    output reg        dm_ready,
    output reg [31:0] dm_rdata,
    output reg [1:0]  dm_resp,

    // CPU status
    input wire        debug_halted,

    // Debug register interface
    input wire [31:0] debug_pc,
    input wire [31:0] debug_dcsr,
    input wire [31:0] debug_dpc,
    output reg [4:0]  debug_reg_addr,
    input wire [31:0] debug_reg_data,
    output reg        debug_dcsr_we,
    output reg        debug_dpc_we,
    output reg [31:0] debug_dcsr_wdata,
    output reg [31:0] debug_dpc_wdata,

    // Debug control
    output wire [31:0] dmcontrol,

    // Abstract memory interface
    output wire        mem_valid,
    output wire        mem_write,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output        debug_reg_we,
    output [31:0] debug_reg_wdata,
    input wire [31:0] mem_rdata,
    input wire        mem_ready
);

// DMI operations
localparam DMI_NOP   = 2'b00;
localparam DMI_READ  = 2'b01;
localparam DMI_WRITE = 2'b10;

// DMI responses
localparam RESP_SUCCESS  = 2'b00;
localparam RESP_RESERVED = 2'b01;
localparam RESP_BUSY     = 2'b10;
localparam RESP_ERROR    = 2'b11;

// Debug module register map
localparam DATA0_ADDR     = 7'h04;
localparam DMCONTROL_ADDR = 7'h10;
localparam DMSTATUS_ADDR  = 7'h11;
localparam HARTINFO_ADDR  = 7'h12;
localparam ABSTRACTCS_ADDR = 7'h16;
localparam COMMAND_ADDR   = 7'h17;
localparam DATA1_ADDR     = 7'h05;

reg [31:0] dmcontrol_reg;
reg [31:0] command_reg;
reg [2:0]  cmderr;
reg        start_abstract;
reg [31:0] data0_reg;
reg [31:0] data1_reg;
reg        pending_start;
reg        aau_start;

wire [31:0] abstractcs;
wire [31:0] abstract_data0;
wire        abstract_busy;
wire        abstract_done;
wire [31:0] aau_data0;
wire [31:0] aau_data1;

wire        aau_mem_valid;
wire        aau_mem_write;
wire [31:0] aau_mem_addr;
wire [31:0] aau_mem_wdata;
wire [31:0] aau_mem_rdata;
wire        aau_mem_ready;
wire [2:0]  cmd_error;
wire        aau_busy;
wire        aau_done;

assign dmcontrol = dmcontrol_reg;

// AAU memory interface
assign mem_valid     = aau_mem_valid;
assign mem_write     = aau_mem_write;
assign mem_addr      = aau_mem_addr;
assign mem_wdata     = aau_mem_wdata;
assign aau_mem_rdata = mem_rdata;
assign aau_mem_ready = mem_ready;

// DMSTATUS
wire [31:0] dmstatus;

assign dmstatus = {
    9'd0,
    1'b0,
    2'd0,
    1'b0,
    1'b0,
    ~debug_halted,
    ~debug_halted,
    1'b0,
    1'b0,
    1'b0,
    1'b0,
    ~debug_halted,
    ~debug_halted,
    debug_halted,
    debug_halted,
    1'b1,
    1'b0,
    1'b0,
    1'b0,
    4'h2
};

// HARTINFO
wire [31:0] hartinfo;

assign hartinfo = {
    8'd0,
    4'd0,
    3'd0,
    1'b0,
    4'd2,
    DATA0_ADDR
};

assign abstractcs = {
    4'd0,
    5'd0,
    11'd0,
    aau_busy,
    cmderr,
    3'd0,
    1'b0,
    4'd2
};

// Abstract Access Unit
abstract_access_unit aau(
    .clk              (clk),
    .reset            (reset),
    .start            (aau_start),
    .command          (command_reg),

    .debug_pc         (debug_pc),
    .debug_reg_addr   (debug_reg_addr),
    .debug_reg_data   (debug_reg_data),

    .data0_in         (data0_reg),
    .data1_in         (data1_reg),
    .data0_out        (aau_data0),
    .data1_out        (aau_data1),

    .mem_valid        (aau_mem_valid),
    .mem_write        (aau_mem_write),
    .mem_addr         (aau_mem_addr),
    .mem_wdata        (aau_mem_wdata),
    .mem_rdata        (aau_mem_rdata),
    .mem_ready        (aau_mem_ready),

    .debug_reg_we     (debug_reg_we),
    .debug_reg_wdata  (debug_reg_wdata),

    .debug_dcsr       (debug_dcsr),
    .debug_dpc        (debug_dpc),
    .debug_dcsr_we    (debug_dcsr_we),
    .debug_dpc_we     (debug_dpc_we),
    .debug_dcsr_wdata (debug_dcsr_wdata),
    .debug_dpc_wdata  (debug_dpc_wdata),

    .busy             (aau_busy),
    .done             (aau_done),
    .cmd_error        (cmd_error)
);

// Debug Module
always @(posedge clk or posedge reset) begin
    if (reset) begin
        aau_start     <= 1'b0;
        pending_start <= 1'b0;

        dmcontrol_reg <= 32'h00000001;
        data0_reg     <= 32'h00000000;
        data1_reg     <= 32'h00000000;
        command_reg   <= 32'h00000000;

        dm_ready      <= 1'b0;
        dm_rdata      <= 32'h00000000;
        dm_resp       <= RESP_SUCCESS;
        cmderr        <= 3'd0;
    end
    else begin
        aau_start <= 1'b0;
        dm_ready  <= 1'b0;
        dm_resp   <= RESP_SUCCESS;

        // Launch AAU one cycle after COMMAND write
        if (pending_start) begin
            aau_start     <= 1'b1;
            pending_start <= 1'b0;
        end

        // Auto-clear one-shot request bits
        if (debug_halted)
            dmcontrol_reg[31] <= 1'b0;

        if (!debug_halted)
            dmcontrol_reg[30] <= 1'b0;

        if (dmcontrol_reg[29])
            dmcontrol_reg[29] <= 1'b0;

        // Capture completed abstract command
        if (aau_done) begin
            data0_reg <= aau_data0;
            data1_reg <= aau_data1;

            if (cmd_error != 3'd0)
                cmderr <= cmd_error;
        end

        // Handle DMI transaction
        if (dm_valid) begin
            case (dm_op)
                DMI_NOP: begin
                    dm_ready <= 1'b1;
                end

                DMI_WRITE: begin
                    case (dm_addr)
                        DATA0_ADDR: begin
                            data0_reg <= dm_wdata;
                        end

                        DATA1_ADDR: begin
                            data1_reg <= dm_wdata;
                        end

                        DMCONTROL_ADDR: begin
                            dmcontrol_reg    <= 32'd0;
                            dmcontrol_reg[31] <= dm_wdata[31];
                            dmcontrol_reg[30] <= dm_wdata[30];
                            dmcontrol_reg[29] <= dm_wdata[29];
                            dmcontrol_reg[0]  <= dm_wdata[0];
                        end

                        COMMAND_ADDR: begin
                            command_reg   <= dm_wdata;
                            pending_start <= 1'b1;
                        end

                        ABSTRACTCS_ADDR: begin
                            cmderr <= cmderr & ~dm_wdata[10:8];
                        end

                        default: begin
                            dm_resp <= RESP_ERROR;
                        end
                    endcase

                    dm_ready <= 1'b1;
                end

                DMI_READ: begin
                    case (dm_addr)
                        DATA0_ADDR: begin
                            dm_rdata <= data0_reg;
                        end

                        DATA1_ADDR: begin
                            dm_rdata <= data1_reg;
                        end

                        DMCONTROL_ADDR: begin
                            dm_rdata <= dmcontrol_reg;
                        end

                        DMSTATUS_ADDR: begin
                            dm_rdata <= dmstatus;
                        end

                        HARTINFO_ADDR: begin
                            dm_rdata <= hartinfo;
                        end

                        COMMAND_ADDR: begin
                            dm_rdata <= command_reg;
                        end

                        ABSTRACTCS_ADDR: begin
                            dm_rdata <= abstractcs;
                        end

                        default: begin
                            dm_rdata <= 32'h00000000;
                            dm_resp  <= RESP_ERROR;
                        end
                    endcase

                    dm_ready <= 1'b1;
                end

                default: begin
                    dm_ready <= 1'b1;
                    dm_resp  <= RESP_ERROR;
                end
            endcase
        end
    end
end

endmodule
