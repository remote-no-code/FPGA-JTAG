//-----------------------------------------------------------------------------
// Minimal RISC-V Debug Module
//-----------------------------------------------------------------------------
module riscv_debug_module_minimal (


    input  wire        clk,
    input  wire        reset,

    // DMI request
    input  wire        dm_valid,
    input  wire [6:0]  dm_addr,
    input  wire [31:0] dm_wdata,
    input  wire [1:0]  dm_op,

    // DMI response
    output reg         dm_ready,
    output reg [31:0]  dm_rdata,
    output reg [1:0]   dm_resp,

    // CPU status
    input  wire        debug_halted,
    input  wire [31:0] debug_pc,
    
    output reg  [4:0]  debug_reg_addr,
    input  wire [31:0] debug_reg_data,

   // Debug control
    output wire [31:0] dmcontrol,

    //--------------------------------------------------
    // Abstract Memory Interface
    //--------------------------------------------------
    output wire        mem_valid,
    output wire        mem_write,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    
    output        debug_reg_we,
    output [31:0] debug_reg_wdata,

    input  wire [31:0] mem_rdata,
    input  wire        mem_ready

);

//--------------------------------------------------
// DMI Operations
//--------------------------------------------------
localparam DMI_NOP   = 2'b00;
localparam DMI_READ  = 2'b01;
localparam DMI_WRITE = 2'b10;

//--------------------------------------------------
// DMI Responses
//--------------------------------------------------
localparam RESP_SUCCESS = 2'b00;
localparam RESP_RESERVED = 2'b01;
localparam RESP_BUSY = 2'b10;
localparam RESP_ERROR = 2'b11;

//--------------------------------------------------
// Debug Module Register Map
//--------------------------------------------------
localparam DATA0_ADDR      = 7'h04;
localparam DMCONTROL_ADDR  = 7'h10;
localparam DMSTATUS_ADDR   = 7'h11;
localparam ABSTRACTCS_ADDR = 7'h16;
localparam COMMAND_ADDR    = 7'h17;
localparam DATA1_ADDR = 7'h05;

//--------------------------------------------------
// Debug Registers
//--------------------------------------------------
reg [31:0] dmcontrol_reg;

reg [31:0] command_reg;
reg [31:0] abstractcs_reg;
reg start_abstract;

wire [31:0] abstract_data0;
wire abstract_busy;
wire abstract_done;
//--------------------------------------------------
// AAU Signals
//--------------------------------------------------
wire [31:0] aau_data0;
wire [31:0] aau_data1;



reg [31:0] data0_reg;
reg [31:0] data1_reg;

assign dmcontrol = dmcontrol_reg;

//--------------------------------------------------
// AAU Memory Interface
//--------------------------------------------------
wire        aau_mem_valid;
wire        aau_mem_write;

wire [31:0] aau_mem_addr;
wire [31:0] aau_mem_wdata;

wire [31:0] aau_mem_rdata;
wire        aau_mem_ready;

//--------------------------------------------------
// AAU Memory Connections
//--------------------------------------------------
assign mem_valid = aau_mem_valid;
assign mem_write = aau_mem_write;

assign mem_addr  = aau_mem_addr;
assign mem_wdata = aau_mem_wdata;

assign aau_mem_rdata = mem_rdata;
assign aau_mem_ready = mem_ready;

//--------------------------------------------------
// Abstract Access Unit
//--------------------------------------------------
reg        aau_start;

wire       aau_busy;
wire       aau_done;

//--------------------------------------------------
// DMSTATUS
//--------------------------------------------------
wire [31:0] dmstatus;

assign dmstatus = {
    30'd0,
    ~debug_halted,
    debug_halted
};

abstract_access_unit aau (

    .clk            (clk),
    .reset          (reset),

    //--------------------------------------------------
    // Command Interface
    //--------------------------------------------------
    .start          (aau_start),
    .command        (command_reg),

    //--------------------------------------------------
    // CPU Debug Interface
    //--------------------------------------------------
    .debug_pc       (debug_pc),

    .debug_reg_addr (debug_reg_addr),
    .debug_reg_data (debug_reg_data),

    //--------------------------------------------------
    // DATA Registers
    //--------------------------------------------------
    .data0_in       (data0_reg),
    .data1_in       (data1_reg),

    .data0_out      (aau_data0),
    .data1_out      (aau_data1),
    
    //--------------------------------------------------
    // Memory Interface
    //--------------------------------------------------
    .mem_valid (aau_mem_valid),
    .mem_write (aau_mem_write),
    .mem_addr  (aau_mem_addr),
    .mem_wdata (aau_mem_wdata),

    .mem_rdata (aau_mem_rdata),
    .mem_ready (aau_mem_ready),

    .debug_reg_we(debug_reg_we),
    .debug_reg_wdata(debug_reg_wdata),

    //--------------------------------------------------
    .busy           (aau_busy),
    .done           (aau_done)

);
//--------------------------------------------------
// Debug Module
//--------------------------------------------------
always @(posedge clk or posedge reset) begin

    if (reset) begin

        aau_start <= 1'b0;

        dmcontrol_reg  <= 32'h00000000;
        data0_reg      <= 32'h00000000;
        command_reg    <= 32'h00000000;
        abstractcs_reg <= 32'h00000000;

        dm_ready <= 1'b0;
        dm_rdata <= 32'h00000000;
        dm_resp  <= RESP_SUCCESS;

    end
    else begin

        //--------------------------------------------------
        // Default outputs
        //--------------------------------------------------
        aau_start <= 1'b0;
        dm_ready  <= 1'b0;
        dm_resp   <= RESP_SUCCESS;

        //--------------------------------------------------
        // Clear request bits after acknowledgement
        //--------------------------------------------------
        if (debug_halted)
            dmcontrol_reg[0] <= 1'b0;   // clear halt request

        if (!debug_halted)
            dmcontrol_reg[1] <= 1'b0;   // clear resume request

        if (dmcontrol_reg[2])
            dmcontrol_reg[2] <= 1'b0;   // clear reset request after one cycle

        //--------------------------------------------------
        // Abstract Command Completed
        //--------------------------------------------------
        if (aau_done) begin
            data0_reg      <= aau_data0;
            data1_reg      <= aau_data1;
            abstractcs_reg <= 32'h00000000;

`ifdef DISPLAY
            $display("%0t ABSTRACT COMMAND COMPLETE", $time);
            $display("%0t DATA0 <= %08h", $time, aau_data0);
            $display("%0t DATA1 <= %08h", $time, aau_data1);
`endif
        end

        //--------------------------------------------------
        // DMI Transaction
        //--------------------------------------------------
`ifdef DISPLAY
        $display("%0t DM: dm_valid=%b dm_ready=%b addr=%02h op=%0d",
                 $time,
                 dm_valid,
                 dm_ready,
                 dm_addr,
                 dm_op);
`endif

        if (dm_valid) begin

            case (dm_op)

                //--------------------------------------
                // NOP
                //--------------------------------------
                DMI_NOP:
                    dm_ready <= 1'b1;

                //--------------------------------------
                // WRITE
                //--------------------------------------
                DMI_WRITE:
                begin

                    case (dm_addr)

                        DATA0_ADDR:
                        begin
                            data0_reg <= dm_wdata;

`ifdef DISPLAY
                            $display("%0t DATA0 WRITE = %08h",
                                     $time, dm_wdata);
                            $display("%0t DMCONTROL WRITE = %08h  dm_valid=%b",
                                     $time, dm_wdata, dm_valid);
`endif
                        end

                        DATA1_ADDR:
                        begin
                            data1_reg <= dm_wdata;

`ifdef DISPLAY
                            $display("%0t DATA1 WRITE = %08h",
                                     $time,
                                     dm_wdata);
`endif
                        end

                        DMCONTROL_ADDR:
                        begin
                            dmcontrol_reg <= dm_wdata;

`ifdef DISPLAY
                            $display("%0t DMCONTROL WRITE = %08h",
                                     $time, dm_wdata);
`endif
                        end

                        COMMAND_ADDR:
                        begin
                            command_reg <= dm_wdata;
                            aau_start   <= 1'b1;

                            // Busy while command executes
                            abstractcs_reg[12] <= 1'b1;

`ifdef DISPLAY
                            $display("%0t COMMAND WRITE = %08h",
                                     $time, dm_wdata);
`endif
                        end

                        ABSTRACTCS_ADDR:
                        begin
                            abstractcs_reg <= dm_wdata;

`ifdef DISPLAY
                            $display("%0t ABSTRACTCS WRITE = %08h",
                                     $time, dm_wdata);
`endif
                        end

                        default:
                            dm_resp <= RESP_ERROR;

                    endcase

                    dm_ready <= 1'b1;

                end

                //--------------------------------------
                // READ
                //--------------------------------------
                DMI_READ:
                begin

                    case (dm_addr)

                        DATA0_ADDR:
                        begin
                            dm_rdata <= data0_reg;

`ifdef DISPLAY
                            $display("%0t DATA0 READ = %08h",
                                     $time, data0_reg);
`endif
                        end

                        DATA1_ADDR:
                        begin
                            dm_rdata <= data1_reg;

`ifdef DISPLAY
                            $display("%0t DATA1 READ = %08h",
                                     $time,
                                     data1_reg);
`endif
                        end

                        DMCONTROL_ADDR:
                        begin
                            dm_rdata <= dmcontrol_reg;

`ifdef DISPLAY
                            $display("%0t DMCONTROL READ = %08h",
                                     $time, dmcontrol_reg);
`endif
                        end

                        DMSTATUS_ADDR:
                        begin
                            dm_rdata <= dmstatus;

`ifdef DISPLAY
                            $display("%0t DMSTATUS READ = %08h",
                                     $time, dmstatus);
                            $display("DMSTATUS READ");
                            $display("debug_halted = %b", debug_halted);
                            $display("dmstatus      = %08h", dmstatus);
`endif
                        end

                        COMMAND_ADDR:
                        begin
                            dm_rdata <= command_reg;

`ifdef DISPLAY
                            $display("%0t COMMAND READ = %08h",
                                     $time, command_reg);
`endif
                        end

                        ABSTRACTCS_ADDR:
                        begin
                            dm_rdata <= abstractcs_reg;

`ifdef DISPLAY
                            $display("%0t ABSTRACTCS READ = %08h",
                                     $time, abstractcs_reg);
`endif
                        end

                        default:
                        begin
                            dm_rdata <= 32'h00000000;
                            dm_resp  <= RESP_ERROR;
                        end

                    endcase

                    dm_ready <= 1'b1;

                end

                //--------------------------------------
                // Invalid Operation
                //--------------------------------------
                default:
                begin
                    dm_ready <= 1'b1;
                    dm_resp  <= RESP_ERROR;
                end

            endcase

        end

    end

end


endmodule
