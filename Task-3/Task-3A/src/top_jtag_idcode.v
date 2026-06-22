module top_jtag_idcode(
input  wire tck,
input  wire tms,
input  wire tdi,
input  wire trst,

output wire tdo,
output wire led

);

// Optional LED activity indicator
reg led_reg;

always @(posedge tck or posedge trst)
begin
    if(trst)
        led_reg <= 1'b0;
    else
        led_reg <= ~led_reg;
end

assign led = led_reg;

jtag_tap tap (
    .tck(tck),
    .tms(tms),
    .tdi(tdi),
    .trst(trst),

    .tdo(tdo),

    .debug_halt_req(),
    .debug_resume_req(),
    .debug_reset_req(),

    .debug_halted(1'b0),
    .debug_pc(32'h00000000)
);


endmodule

