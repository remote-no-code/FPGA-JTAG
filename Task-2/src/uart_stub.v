`default_nettype wire

module corescore_emitter_uart (
    input        i_clk,
    input        i_rst,
    input  [7:0] i_data,
    input        i_valid,
    output       o_ready,
    output       o_uart_tx
);

    assign o_ready   = 1'b1;
    assign o_uart_tx = 1'b1;

    // ------------------------------------------------------------
    // BENCH UART: print to terminal
    // ------------------------------------------------------------
    always @(posedge i_clk) begin
        if (!i_rst && i_valid) begin
            $write("%c", i_data);
            $fflush(32'h8000_0001);
        end
    end

endmodule

`default_nettype none

