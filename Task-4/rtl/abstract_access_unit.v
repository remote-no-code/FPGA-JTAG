// RISC-V Abstract Access Unit
module abstract_access_unit(
    input wire        clk,
    input wire        reset,
    input wire        start,
    input wire [31:0] command,
    input wire [31:0] debug_pc,

    output reg [4:0]  debug_reg_addr,
    input wire [31:0] debug_reg_data,

    input wire [31:0] data0_in,
    input wire [31:0] data1_in,
    output reg [31:0] data0_out,
    output reg [31:0] data1_out,

    // Memory interface
    output reg        mem_valid,
    output reg        mem_write,
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    input wire [31:0] mem_rdata,
    input wire        mem_ready,

    output reg        debug_reg_we,
    output reg [31:0] debug_reg_wdata,

    output reg        busy,
    output reg        done,

    input wire [31:0] debug_dcsr,
    input wire [31:0] debug_dpc,
    output reg        debug_dcsr_we,
    output reg        debug_dpc_we,
    output reg [31:0] debug_dcsr_wdata,
    output reg [31:0] debug_dpc_wdata,

    output reg [2:0]   cmd_error
);

localparam CMD_ACCESS_REGISTER = 8'h00;
localparam CMD_ACCESS_MEMORY   = 8'h02;

// Decode command fields
wire [7:0]  cmdtype           = command[31:24];
wire       cmd_transfer      = command[22];
wire       cmd_write         = command[21];
wire       cmd_postexec      = command[20];
wire       cmd_postincrement = command[19];
wire [1:0]  cmd_size         = command[18:17];
wire [15:0] cmd_regno        = command[15:0];

// Decode register number
wire       reg_is_gpr  = (cmd_regno[15:5] == 11'h80);
wire       reg_is_dcsr = (cmd_regno == 16'h7B0);
wire       reg_is_dpc  = (cmd_regno == 16'h7B1);
wire [4:0] reg_index   = cmd_regno[4:0];

wire access_reg  = (cmdtype == CMD_ACCESS_REGISTER);
wire access_mem  = (cmdtype == CMD_ACCESS_MEMORY);
wire valid_size  = (cmd_size == 2'b10);
wire mem_aligned = (data0_in[1:0] == 2'b00);

localparam IDLE             = 3'd0;
localparam DO_REG_WRITE     = 3'd1;
localparam WAIT_REG_READ    = 3'd2;
localparam WAIT_MEM_READ    = 3'd3;
localparam WAIT_MEM_WRITE   = 3'd4;
localparam WAIT_REG_CAPTURE = 3'd5;
localparam FINISH           = 3'd6;

reg [2:0] state;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state           <= IDLE;
        busy            <= 1'b0;
        done            <= 1'b0;
        debug_reg_addr  <= 5'd0;
        data0_out       <= 32'd0;
        data1_out       <= 32'd0;
        mem_valid       <= 1'b0;
        mem_write       <= 1'b0;
        mem_addr        <= 32'd0;
        mem_wdata       <= 32'd0;
        debug_reg_we    <= 1'b0;
        debug_dcsr_we   <= 1'b0;
        debug_dpc_we    <= 1'b0;
        debug_dcsr_wdata <= 32'd0;
        debug_dpc_wdata  <= 32'd0;
        cmd_error       <= 3'd0;
    end
    else begin
        done          <= 1'b0;
        mem_valid     <= 1'b0;
        mem_write     <= 1'b0;
        debug_reg_we  <= 1'b0;
        debug_dcsr_we <= 1'b0;
        debug_dpc_we  <= 1'b0;

        case (state)
            IDLE: begin
                busy <= 1'b0;

                if (start) begin
                    busy      <= 1'b1;
                    cmd_error <= 3'd0;

                    // Access register
                    if (access_reg && cmd_transfer && valid_size) begin
                        if (reg_is_gpr) begin
                            debug_reg_addr <= reg_index;

                            if (cmd_write) begin
                                debug_reg_wdata <= data0_in;
                                state <= DO_REG_WRITE;
                            end
                            else if (reg_index == 5'd0) begin
                                data0_out <= 32'd0;
                                state <= FINISH;
                            end
                            else begin
                                state <= WAIT_REG_CAPTURE;
                            end
                        end
                        else if (reg_is_dcsr || reg_is_dpc) begin
                            if (cmd_write) begin
                                if (reg_is_dcsr) begin
                                    debug_dcsr_wdata <= data0_in;
                                    debug_dcsr_we    <= 1'b1;
                                end
                                else begin
                                    debug_dpc_wdata <= data0_in;
                                    debug_dpc_we    <= 1'b1;
                                end
                            end
                            else begin
                                data0_out <= reg_is_dcsr ? debug_dcsr : debug_dpc;
                            end

                            state <= FINISH;
                        end
                        else begin
                            cmd_error <= 3'd2;
                            state <= FINISH;
                        end
                    end

                    // Access memory
                    else if (access_mem && cmd_transfer) begin
                        if (!valid_size || !mem_aligned) begin
                            busy      <= 1'b0;
                            done      <= 1'b1;
                            cmd_error <= 3'd2;
                        end
                        else begin
                            mem_addr  <= data0_in;
                            mem_valid <= 1'b1;
                            mem_write <= cmd_write;

                            if (cmd_write)
                                mem_wdata <= data1_in;

                            state <= cmd_write ? WAIT_MEM_WRITE : WAIT_MEM_READ;
                        end
                    end

                    // Unsupported command
                    else begin
                        busy      <= 1'b0;
                        done      <= 1'b1;
                        cmd_error <= 3'd2;
                    end
                end
            end

            // Execute register write
            DO_REG_WRITE: begin
                debug_reg_we <= 1'b1;
                state <= FINISH;
            end

            // Wait for processor register capture
            WAIT_REG_CAPTURE: begin
                state <= WAIT_REG_READ;
            end

            // Read register data
            WAIT_REG_READ: begin
                data0_out <= debug_reg_data;
                state <= FINISH;
            end

            // Memory read
            WAIT_MEM_READ: begin
                mem_valid <= 1'b1;

                if (mem_ready) begin
                    data0_out <= mem_rdata;
                    busy      <= 1'b0;
                    done      <= 1'b1;
                    mem_valid <= 1'b0;
                    state     <= IDLE;
                end
            end

            // Memory write
            WAIT_MEM_WRITE: begin
                mem_valid <= 1'b1;
                mem_write <= 1'b1;

                if (mem_ready) begin
                    mem_valid <= 1'b0;
                    mem_write <= 1'b0;
                    state     <= FINISH;
                end
            end

            // Complete command
            FINISH: begin
                busy          <= 1'b0;
                done          <= 1'b1;
                cmd_error     <= 3'd0;
                mem_valid     <= 1'b0;
                mem_write     <= 1'b0;
                debug_reg_we  <= 1'b0;
                debug_dcsr_we <= 1'b0;
                debug_dpc_we  <= 1'b0;
                state         <= IDLE;
            end

            default: begin
                state <= FINISH;
            end
        endcase
    end
end

endmodule
