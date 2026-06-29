`timescale 1ns/1ps

module jtag_debug_cdc(
    input  wire tck,
    input  wire trst,

    input  wire clk,
    input  wire reset,

    input  wire debug_halt_req_tck,
    input  wire debug_resume_req_tck,
    input  wire debug_reset_req_tck,

    output wire debug_halt_req_clk,
    output wire debug_resume_req_clk,
    output wire debug_reset_req_clk
);

//
// Toggle generation (TCK domain)
//

reg halt_toggle;
reg resume_toggle;
reg reset_toggle;

always @(posedge tck or posedge trst) begin
    if (trst)
        halt_toggle <= 1'b0;
    else if (debug_halt_req_tck) begin
        halt_toggle <= ~halt_toggle;
        $display("%0t : HALT toggle", $time);
    end
end

always @(posedge tck or posedge trst) begin
    if (trst)
        resume_toggle <= 1'b0;
    else if (debug_resume_req_tck) begin
        resume_toggle <= ~resume_toggle;
        $display("%0t : RESUME toggle", $time);
    end
end

always @(posedge tck or posedge trst) begin
    if (trst)
        reset_toggle <= 1'b0;
    else if (debug_reset_req_tck) begin
        reset_toggle <= ~reset_toggle;
        $display("%0t : RESET toggle", $time);
    end
end

//
// Synchronizers (CLK domain)
//

reg halt_sync1, halt_sync2, halt_sync2_d;
reg resume_sync1, resume_sync2, resume_sync2_d;
reg reset_sync1, reset_sync2, reset_sync2_d;

// debug register
reg resume_toggle_d;

always @(posedge clk or posedge reset) begin

    if (reset) begin

        halt_sync1   <= 0;
        halt_sync2   <= 0;
        halt_sync2_d <= 0;

        resume_sync1   <= 0;
        resume_sync2   <= 0;
        resume_sync2_d <= 0;

        reset_sync1   <= 0;
        reset_sync2   <= 0;
        reset_sync2_d <= 0;

        resume_toggle_d <= 0;

    end
    else begin

        //
        // Synchronizers
        //
        halt_sync1   <= halt_toggle;
        halt_sync2   <= halt_sync1;
        halt_sync2_d <= halt_sync2;

        resume_sync1   <= resume_toggle;
        resume_sync2   <= resume_sync1;
        resume_sync2_d <= resume_sync2;

        reset_sync1   <= reset_toggle;
        reset_sync2   <= reset_sync1;
        reset_sync2_d <= reset_sync2;

        //
        // Debug
        //
        resume_toggle_d <= resume_toggle;

        if (resume_toggle != resume_toggle_d)
            $display("%0t CDC: resume_toggle changed -> %b",
                     $time, resume_toggle);

        if (halt_sync2 ^ halt_sync2_d) begin
            $display("%0t CDC: HALT pulse", $time);
        end

        if (resume_sync2 ^ resume_sync2_d) begin
            $display("%0t CDC: RESUME pulse", $time);
        end

        if (reset_sync2 ^ reset_sync2_d) begin
            $display("%0t CDC: RESET pulse", $time);
        end
    end

end

//
// One-clock output pulses
//

assign debug_halt_req_clk   = halt_sync2   ^ halt_sync2_d;
assign debug_resume_req_clk = resume_sync2 ^ resume_sync2_d;
assign debug_reset_req_clk  = reset_sync2  ^ reset_sync2_d;

endmodule
