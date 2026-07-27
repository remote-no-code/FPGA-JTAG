//-----------------------------------------------------------------------------
// JTAG TAP Controller 
//-----------------------------------------------------------------------------
module riscv_jtag_dtm(

    input  wire tck,
    input  wire tms,
    input  wire tdi,
    input  wire n_trst,

    output wire tdo,


    // DMI Request
    output reg        dmi_valid,
    output reg [6:0]  dmi_addr,
    output reg [31:0] dmi_wdata,
    output reg [1:0]  dmi_op,

    // DMI Response
    input  wire       resp_valid,
    input  wire [31:0] resp_data,
    input  wire [1:0] resp_resp,
    input wire req_ready

);



wire [40:0] final_shift;

assign final_shift = {tdi, dr_shift[40:1]};


//-----------------------------------------------------------------------------
// TAP Controller States 
//-----------------------------------------------------------------------------
parameter TEST_LOGIC_RESET = 4'h0;
parameter RUN_TEST_IDLE    = 4'h1;

parameter SHIFT_IR         = 4'h2;
parameter UPDATE_IR        = 4'h3;
parameter SELECT_IR_SCAN   = 4'h4;
parameter CAPTURE_IR       = 4'h5;
parameter EXIT1_IR         = 4'h6;
parameter PAUSE_IR         = 4'h7;
parameter EXIT2_IR         = 4'h8;

parameter SHIFT_DR         = 4'h9;
parameter UPDATE_DR        = 4'hA;
parameter SELECT_DR_SCAN   = 4'hB;
parameter CAPTURE_DR       = 4'hC;
parameter EXIT1_DR         = 4'hD;
parameter PAUSE_DR         = 4'hE;
parameter EXIT2_DR         = 4'hF;

reg [3:0] state;


//-----------------------------------------------------------------------------
// JTAG Instructions (5-bit IR)
//-----------------------------------------------------------------------------
parameter IDCODE = 5'b00001;
parameter DTMCS  = 5'b10000;
parameter DMI    = 5'b10001;
parameter BYPASS = 5'b11111;

localparam [31:0] IDCODE_VALUE = 32'h81262776;

//-----------------------------------------------------------------------------
// Registers
//-----------------------------------------------------------------------------
reg [4:0]  ir;
reg [4:0]  ir_shift;

reg [31:0] dtmcs_reg;
// DMI register:
// [40:34] Address
// [33:2]  Data
// [1:0]   Operation

// Data Register Shift Register
reg [40:0] dr_shift;

// BYPASS Register
reg bypass_bit;
//--------------------------------------------------
// Latched DMI Response
//--------------------------------------------------
reg [31:0] dmi_rdata_reg;
reg [1:0]  dmi_resp_reg;





//-----------------------------------------------------------------------------
// Initialization
//-----------------------------------------------------------------------------
initial begin

    state      = TEST_LOGIC_RESET;

    ir         = 5'b00000;
    ir_shift   = 5'b00000;

    dtmcs_reg  = 32'h00000071;

    dr_shift   = 41'd0;

    dmi_valid  = 1'b0;
    dmi_addr   = 7'd0;
    dmi_wdata  = 32'd0;
    dmi_op     = 2'b00;

    bypass_bit = 1'b0;
    tdo_reg    = 1'b0;
    dmi_rdata_reg = 32'd0;
    dmi_resp_reg  = 2'b00;

end



//-----------------------------------------------------------------------------
// TAP State Machine (IEEE 1149.1)
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
// TAP Controller
//-----------------------------------------------------------------------------
reg [3:0] next_state;
// State register
always @(posedge tck or negedge n_trst) begin
    if (!n_trst)
        state <= TEST_LOGIC_RESET;
    else
        state <= next_state;
end

// Next-state logic
always @(*) begin
    case (state)
        TEST_LOGIC_RESET : next_state = tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
        RUN_TEST_IDLE    : next_state = tms ? SELECT_DR_SCAN  : RUN_TEST_IDLE;
        SELECT_DR_SCAN   : next_state = tms ? SELECT_IR_SCAN  : CAPTURE_DR;
        CAPTURE_DR       : next_state = tms ? EXIT1_DR        : SHIFT_DR;
        SHIFT_DR         : next_state = tms ? EXIT1_DR        : SHIFT_DR;
        EXIT1_DR         : next_state = tms ? UPDATE_DR       : PAUSE_DR;
        PAUSE_DR         : next_state = tms ? EXIT2_DR        : PAUSE_DR;
        EXIT2_DR         : next_state = tms ? UPDATE_DR       : SHIFT_DR;
        UPDATE_DR        : next_state = tms ? SELECT_DR_SCAN  : RUN_TEST_IDLE;

        SELECT_IR_SCAN   : next_state = tms ? TEST_LOGIC_RESET : CAPTURE_IR;
        CAPTURE_IR       : next_state = tms ? EXIT1_IR         : SHIFT_IR;
        SHIFT_IR         : next_state = tms ? EXIT1_IR         : SHIFT_IR;
        EXIT1_IR         : next_state = tms ? UPDATE_IR        : PAUSE_IR;
        PAUSE_IR         : next_state = tms ? EXIT2_IR         : PAUSE_IR;
        EXIT2_IR         : next_state = tms ? UPDATE_IR        : SHIFT_IR;
        UPDATE_IR        : next_state = tms ? SELECT_DR_SCAN   : RUN_TEST_IDLE;

        default          : next_state = TEST_LOGIC_RESET;
    endcase
end

always @(posedge tck or negedge n_trst) begin
    if(!n_trst) begin
        ir       <= IDCODE;
        ir_shift <= IDCODE;
    end
    else begin
        case(state)
            CAPTURE_IR:
                ir_shift <= IDCODE;

            SHIFT_IR: begin
                ir_shift <= {tdi, ir_shift[4:1]};
            end

            UPDATE_IR:
                ir <= ir_shift;

            default:;
        endcase
    end
end

always @(posedge tck or negedge n_trst) begin
    if(!n_trst) begin
        dr_shift   <= 41'd0;
        bypass_bit <= 1'b0;

        dmi_valid  <= 1'b0;
        dmi_addr   <= 7'd0;
        dmi_wdata  <= 32'd0;
        dmi_op     <= 2'b00;
    end
    else begin

        dmi_valid <= 1'b0;

        case(state)

        CAPTURE_DR:
            case(ir)
                IDCODE : dr_shift <= {9'd0, IDCODE_VALUE};
                DTMCS  : dr_shift <= {9'd0, dtmcs_reg};

                DMI: begin
`ifdef DISPLAY
                    $display("%0t CAPTURE_DR", $time);
                    $display("dmi_rdata_reg = %08h", dmi_rdata_reg);
                    $display("dmi_resp_reg  = %0d", dmi_resp_reg);
`endif

                    dr_shift <= {7'd0, dmi_rdata_reg, dmi_resp_reg};

`ifdef DISPLAY
                    $display("CAPTURE_DR dr_shift = %011h",
                             {7'd0, dmi_rdata_reg, dmi_resp_reg});
`endif
                end

                BYPASS : bypass_bit <= 1'b0;
                default: dr_shift <= 41'd0;
            endcase

        SHIFT_DR:
            case(ir)

                IDCODE,
                DTMCS:
                    dr_shift <= final_shift;

                DMI: begin
                    dr_shift <= final_shift;

                    if(tms && req_ready) begin
                        dmi_addr  <= final_shift[40:34];
                        dmi_wdata <= final_shift[33:2];
                        dmi_op    <= final_shift[1:0];
                        dmi_valid <= 1'b1;

`ifdef DISPLAY
                        $display("====================================");
                        $display("%0t DTM SEND", $time);
                        $display("ADDR = %02h", final_shift[40:34]);
                        $display("OP   = %0d", final_shift[1:0]);
                        $display("DATA = %08h", final_shift[33:2]);
`endif
                    end

                end

                BYPASS:
                    bypass_bit <= tdi;

                default:;
            endcase

        default:;
        endcase
    end
end

always @(posedge tck or negedge n_trst) begin
    if(!n_trst) begin
        dmi_rdata_reg <= 32'd0;
        dmi_resp_reg  <= 2'b00;
    end
    else if(resp_valid) begin

`ifdef DISPLAY
        $display("%0t DTM LATCH", $time);
        $display("resp_data = %08h", resp_data);
        $display("resp_resp = %0d", resp_resp);
`endif

        dmi_rdata_reg <= resp_data;
        dmi_resp_reg  <= resp_resp;
    end
end

reg tdo_next;
reg tdo_reg;
assign tdo = tdo_next;

always @(posedge tck or negedge n_trst) begin
    if (!n_trst)
        tdo_next <= 1'b0;
    else if (state == SHIFT_DR) begin
        case (ir)
            IDCODE,
            DTMCS,
            DMI:
                tdo_next <= dr_shift[0];

            BYPASS:
                tdo_next <= bypass_bit;
        endcase
    end
end

always @(negedge tck or negedge n_trst) begin
    if (!n_trst)
        tdo_reg <= 1'b0;
    else
        tdo_reg <= tdo_next;
end
endmodule
