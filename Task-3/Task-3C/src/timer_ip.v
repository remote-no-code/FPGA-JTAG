`timescale 1ns / 1ps

module timer_ip (
    input  wire        clk,
    input  wire        resetn,

    // Bus interface
    input  wire        sel,
    input  wire        wr_en,
    input  wire        rd_en,
    input  wire [1:0]  addr,     // word offset
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,

    // Hardware output
    output wire        timeout_o
);

    // -------------------------------------------------
    // Register offsets
    // -------------------------------------------------
    localparam REG_CTRL   = 2'b00;
    localparam REG_LOAD   = 2'b01;
    localparam REG_VALUE  = 2'b10;
    localparam REG_STAT   = 2'b11;

    // -------------------------------------------------
    // Registers
    // -------------------------------------------------
    reg [31:0] ctrl_reg;
    reg [31:0] load_reg;
    reg [31:0] value_reg;
    reg        stat_timeout;   // sticky STATUS bit

    // CTRL fields
    wire en        = ctrl_reg[0];
    wire mode      = ctrl_reg[1];   // 0 = one-shot, 1 = periodic
    wire presc_en  = ctrl_reg[2];
    wire [7:0] presc_div = ctrl_reg[15:8];

    // Prescaler
    reg [15:0] presc_cnt;

    // -------------------------------------------------
    // Enable edge detect
    // -------------------------------------------------
    reg en_d;
    always @(posedge clk)
        en_d <= en;

    wire en_rise = en & ~en_d;

    // -------------------------------------------------
    // Expiry detect (1-cycle event)
    // -------------------------------------------------
    wire expire_event = en && (value_reg == 32'd1) &&
                        (!presc_en || presc_cnt == presc_div);

    // -------------------------------------------------
    // WRITE LOGIC
    // -------------------------------------------------
    always @(posedge clk) begin
		if (!resetn) begin
		    load_reg <= 32'b0;
		end
		else if (sel && wr_en) begin
		    case (addr)
		        REG_LOAD: load_reg <= wdata;

		        REG_STAT: ;
		        default: ;
		    endcase
		end
	end

    // -------------------------------------------------
    // TIMER CORE
    // -------------------------------------------------
    always @(posedge clk) begin
        if (!resetn) begin
			ctrl_reg      <= 32'b0;
			value_reg     <= 32'b0;
			presc_cnt     <= 16'b0;
			stat_timeout  <= 1'b0;
		end else begin
        	// Software writes
			if (sel && wr_en) begin
				case (addr)
					REG_CTRL:
						ctrl_reg <= wdata;

					REG_STAT:
						if (wdata[0])
						    stat_timeout <= 1'b0;

					default: ;
				endcase
			end
            // Load counter on enable rising edge
            if (en_rise) begin
                value_reg <= load_reg;
                presc_cnt <= 16'b0;
            end

            // Timer running
            else if (en) begin
                // Prescaler tick
                if (!presc_en || presc_cnt == presc_div) begin
                    presc_cnt <= 16'b0;

                    if (expire_event) begin
                        // Latch sticky timeout
                        stat_timeout <= 1'b1;

                        if (mode) begin
                            // Periodic reload
                            value_reg <= load_reg;
                        end else begin
                            // One-shot: stop timer
                            ctrl_reg[0] <= 1'b0;  // EN = 0
                            value_reg   <= 32'b0;
                        end
                    end else begin
                        value_reg <= value_reg - 1;
                    end

                end else begin
                    presc_cnt <= presc_cnt + 1;
                end
            end
        end
    end

    // -------------------------------------------------
    // READ LOGIC
    // -------------------------------------------------
    always @(posedge clk) begin
        if (!resetn) begin
            rdata <= 32'b0;
        end else if (sel && rd_en) begin
            case (addr)
                REG_CTRL:  rdata <= ctrl_reg;
                REG_LOAD:  rdata <= load_reg;
                REG_VALUE: rdata <= value_reg;
                REG_STAT:  rdata <= {31'b0, stat_timeout};
                default:   rdata <= 32'b0;
            endcase
        end
    end

    // -------------------------------------------------
    // Hardware output
    // -------------------------------------------------
    assign timeout_o = stat_timeout;

endmodule

