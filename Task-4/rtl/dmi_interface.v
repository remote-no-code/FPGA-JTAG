
//-----------------------------------------------------------------------------
// DMI Interface (Task 4 - Step 3)
//-----------------------------------------------------------------------------
module dmi_interface(

    input  wire        clk,
    input  wire        reset,

    // From DTM
    input  wire        dmi_valid,
    input  wire [6:0]  dmi_addr,
    input  wire [31:0] dmi_wdata,
    input  wire [1:0]  dmi_op,

    // To Debug Module
    output reg         dm_valid,
    output reg [6:0]   dm_addr,
    output reg [31:0]  dm_wdata,
    output reg [1:0]   dm_op,

    // From Debug Module
    input  wire        dm_ready,
    input  wire [31:0] dm_rdata,
    input  wire [1:0]  dm_resp,

    // Back to DTM
    output reg         dmi_ready,
    output reg [31:0]  dmi_rdata,
    output reg [1:0]   dmi_resp

);

//--------------------------------------------------
// DMI Operations
//--------------------------------------------------
localparam DMI_NOP   = 2'b00;
localparam DMI_READ  = 2'b01;
localparam DMI_WRITE = 2'b10;

//--------------------------------------------------
// DMI Response
//--------------------------------------------------
localparam RESP_SUCCESS  = 2'b00;
localparam RESP_RESERVED = 2'b01;
localparam RESP_BUSY     = 2'b10;
localparam RESP_ERROR    = 2'b11;

//--------------------------------------------------
// State Machine
//--------------------------------------------------
localparam IDLE          = 2'd0;
localparam WAIT_RESPONSE = 2'd1;
localparam LATCH_RESP = 2'd2;

reg state;

//--------------------------------------------------
// DMI Transport
//--------------------------------------------------
always @(posedge clk or posedge reset) begin


    if (reset) begin

        state <= IDLE;

        dm_valid  <= 1'b0;
        dm_addr   <= 7'd0;
        dm_wdata  <= 32'd0;
        dm_op     <= DMI_NOP;

        dmi_ready <= 1'b0;
        dmi_rdata <= 32'd0;
        dmi_resp  <= RESP_SUCCESS;

    end
    else begin

        //--------------------------------------------------
        // Default Outputs
        //--------------------------------------------------
        dm_valid  <= 1'b0;
        dmi_ready <= 1'b0;

        case(state)

        //--------------------------------------------------
        // Wait for DMI Request
        //--------------------------------------------------
        IDLE:
        begin

            if(dmi_valid)
            begin

                dm_addr  <= dmi_addr;
                dm_wdata <= dmi_wdata;
                dm_op    <= dmi_op;

                dm_valid <= 1'b1;

                // immediately acknowledge request
                // dmi_ready <= 1'b1;

                state <= WAIT_RESPONSE;

            end

        end

        //--------------------------------------------------
        // Wait for Debug Module Response
        //--------------------------------------------------
        WAIT_RESPONSE:
        begin

            if(dm_ready) begin

                dmi_rdata <= dm_rdata;
                dmi_resp  <= dm_resp;
                dmi_ready <= 1'b1;

                state <= IDLE;

            end

        end

        default:
            state <= IDLE;

        endcase

    end

end


endmodule


