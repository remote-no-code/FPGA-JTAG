// Core Debug Adapter
module core_debug_adapter (
    input  wire        clk,
    input  wire        reset,

    input  wire [31:0] dmcontrol,

    output reg         halt_req,
    output reg         resume_req,
    output reg         reset_req,

    input  [31:0]      debug_dcsr,
    input  [31:0]      debug_dpc,

    output             debug_dcsr_we,
    output             debug_dpc_we,

    output [31:0]      debug_dcsr_wdata,
    output [31:0]      debug_dpc_wdata
);

// Generate one-cycle request pulses
always @(posedge clk or posedge reset) begin
    if (reset) begin
        halt_req   <= 1'b0;
        resume_req <= 1'b0;
        reset_req  <= 1'b0;
    end
    else begin
        halt_req   <= dmcontrol[31];
        resume_req <= dmcontrol[30];
        reset_req  <= dmcontrol[29];
    end
end

endmodule
