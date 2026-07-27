module dmi_cdc(

    //=========================================================
    // TCK DOMAIN
    //=========================================================
    input  wire        tck,
    input  wire        trst_n,

    input  wire        req_valid,
    input  wire [6:0]  req_addr,
    input  wire [31:0] req_data,
    input  wire [1:0]  req_op,

    output wire        req_ready,

    output reg         resp_valid,
    output reg [31:0]  resp_data,
    output reg [1:0]   resp_resp,

    //=========================================================
    // CLK DOMAIN
    //=========================================================
    input  wire        clk,
    input  wire        resetn,

    output reg         dmi_valid,
    output reg [6:0]   dmi_addr,
    output reg [31:0]  dmi_data,
    output reg [1:0]   dmi_op,

    input  wire        dmi_ready,
    input  wire [31:0] dmi_rdata,
    input  wire [1:0]  dmi_resp

);

//////////////////////////////////////////////////////////////
// REQUEST BUFFERS
//////////////////////////////////////////////////////////////

reg [6:0]  req_addr_buf;
reg [31:0] req_data_buf;
reg [1:0]  req_op_buf;

//////////////////////////////////////////////////////////////
// RESPONSE BUFFERS
//////////////////////////////////////////////////////////////

reg [31:0] resp_data_buf;
reg [1:0]  resp_resp_buf;

//////////////////////////////////////////////////////////////
// TOGGLES
//////////////////////////////////////////////////////////////

reg req_toggle_tck;
reg req_sync1;
reg req_sync2;
reg req_sync_prev;

reg rsp_toggle_clk;
reg rsp_sync1;
reg rsp_sync2;
reg rsp_sync_prev;
reg response_pending;

//////////////////////////////////////////////////////////////
// REQUEST READY
//////////////////////////////////////////////////////////////

reg busy;

assign req_ready = !busy;

//////////////////////////////////////////////////////////////
// TCK DOMAIN
//////////////////////////////////////////////////////////////

always @(posedge tck or negedge trst_n)
begin

    if(!trst_n)
    begin

        req_toggle_tck <= 0;

        rsp_sync1 <= 0;
        rsp_sync2 <= 0;
        rsp_sync_prev <= 0;

        busy <= 0;

        resp_valid <= 0;
        resp_data <= 0;
        resp_resp <= 0;

    end
    else
    begin

        resp_valid <= 0;

        //--------------------------------------------------
        // Send request
        //--------------------------------------------------

        if(req_valid && !busy)
        begin

            req_addr_buf <= req_addr;
            req_data_buf <= req_data;
            req_op_buf   <= req_op;

            req_toggle_tck <= ~req_toggle_tck;

            busy <= 1;

        end

        //--------------------------------------------------
        // Synchronize response toggle
        //--------------------------------------------------

        rsp_sync1 <= rsp_toggle_clk;
        rsp_sync2 <= rsp_sync1;

        if(rsp_sync2 != rsp_sync_prev)
        begin

            rsp_sync_prev <= rsp_sync2;

            resp_data  <= resp_data_buf;
            resp_resp  <= resp_resp_buf;

            resp_valid <= 1;

            busy <= 0;

        end

    end

end

//////////////////////////////////////////////////////////////
// CLK DOMAIN
//////////////////////////////////////////////////////////////

always @(posedge clk or negedge resetn)
begin

    if(!resetn)
    begin

        req_sync1 <= 0;
        req_sync2 <= 0;
        req_sync_prev <= 0;

        rsp_toggle_clk <= 0;

        dmi_valid <= 0;

        dmi_addr <= 0;
        dmi_data <= 0;
        dmi_op <= 0;
        response_pending <= 1'b0;

    end
    else
    begin

        dmi_valid <= 0;

        //--------------------------------------------------
        // Synchronize request toggle
        //--------------------------------------------------

        req_sync1 <= req_toggle_tck;
        req_sync2 <= req_sync1;

        if(req_sync2 != req_sync_prev)
        begin

            req_sync_prev <= req_sync2;

            dmi_addr <= req_addr_buf;
            dmi_data <= req_data_buf;
            dmi_op   <= req_op_buf;

            dmi_valid <= 1;

        end


        //--------------------------------------------------
        // Capture response
        //--------------------------------------------------
        if (dmi_ready)
        begin
            resp_data_buf     <= dmi_rdata;
            resp_resp_buf     <= dmi_resp;
            response_pending  <= 1'b1;
        end
        else if (response_pending)
        begin
            rsp_toggle_clk    <= ~rsp_toggle_clk;
            response_pending  <= 1'b0;
        end

    end

end

endmodule
