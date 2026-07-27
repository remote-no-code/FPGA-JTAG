//-----------------------------------------------------------------------------
// Core Debug Adapter
//-----------------------------------------------------------------------------
module core_debug_adapter(

    input  wire        clk,
    input  wire        reset,

    input  wire [31:0] dmcontrol,

    output reg         halt_req,
    output reg         resume_req,
    output reg         reset_req

);

//--------------------------------------------------
// Generate one-cycle request pulses
//--------------------------------------------------
always @(posedge clk or posedge reset)
begin

    if (reset) begin

        halt_req   <= 1'b0;
        resume_req <= 1'b0;
        reset_req  <= 1'b0;

    end
    else begin

        // default = pulse outputs
        halt_req   <= dmcontrol[0];
        resume_req <= dmcontrol[1];
        reset_req  <= dmcontrol[2];

    end

end

`ifdef DISPLAY
always @(posedge clk) begin
    if (dmcontrol != 32'h0)
        $display("%0t ADAPTER dmcontrol=%08h halt=%b resume=%b reset=%b",
                 $time,
                 dmcontrol,
                 halt_req,
                 resume_req,
                 reset_req);
end
`endif

endmodule
