module top_jtag_idcode(
    input  wire CLK,
    input  wire RESET,

    input  wire tck,
    input  wire tms,
    input  wire tdi,
    input  wire trst,

    input  wire RXD,

    output wire TXD,
    output wire tdo,
    output wire LEDS,
    output wire LED_EXT
);

SOC soc(
    .CLK(CLK),
    .RESET(RESET),

    .tck(tck),
    .tms(tms),
    .tdi(tdi),
    .trst(trst),

    .RXD(RXD),
    .TXD(TXD),

    .tdo(tdo),

    .LEDS(LEDS),
    .LED_EXT(LED_EXT)
);

endmodule
