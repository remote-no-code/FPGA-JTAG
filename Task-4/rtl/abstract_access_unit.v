module abstract_access_unit(

    input  wire        clk,
    input  wire        reset,

    input  wire        start,
    input  wire [31:0] command,

    input  wire [31:0] debug_pc,

    output reg  [4:0]  debug_reg_addr,
    input  wire [31:0] debug_reg_data,

    input  wire [31:0] data0_in,
    input  wire [31:0] data1_in,

    output reg  [31:0] data0_out,
    output reg  [31:0] data1_out,
    
    //--------------------------------------------------
    // Memory Interface
    //--------------------------------------------------
    output reg         mem_valid,
    output reg         mem_write,

    output reg [31:0]  mem_addr,
    output reg [31:0]  mem_wdata,

    input  wire [31:0] mem_rdata,
    input  wire        mem_ready,
    
    output reg        debug_reg_we,
    output reg [31:0] debug_reg_wdata,

    output reg         busy,
    output reg         done
);
//--------------------------------------------------
// Command Types
//--------------------------------------------------
localparam CMD_REG_READ  = 8'h01;
localparam CMD_REG_WRITE = 8'h02;
localparam CMD_MEM_READ  = 8'h03;
localparam CMD_MEM_WRITE = 8'h04;

//--------------------------------------------------
// FSM States
//--------------------------------------------------
localparam IDLE              = 3'd0;
localparam WAIT_REG_READ     = 3'd3;
localparam WAIT_MEM_READ     = 3'd4;
localparam WAIT_MEM_WRITE    = 3'd5;
localparam DO_REG_WRITE      = 3'd1;
localparam WAIT_REG_CAPTURE  = 3'd2;

reg [2:0] state;
//wire        debug_reg_we = 1'b0;
//wire [31:0] debug_reg_wdata = 32'b0;

always @(posedge clk or posedge reset)
begin

    if(reset) begin

        state <= IDLE;

        busy <= 1'b0;
        done <= 1'b0;

        debug_reg_addr <= 5'd0;

        data0_out <= 32'd0;
        data1_out <= 32'd0;

        mem_valid <= 1'b0;
        mem_write <= 1'b0;
        mem_addr  <= 32'd0;
        mem_wdata <= 32'd0;
        debug_reg_we <= 1'b0;

    end
    else begin

        //--------------------------------------------------
        // Default Outputs
        //--------------------------------------------------
        done      <= 1'b0;
        mem_valid <= 1'b0;
        debug_reg_we <= 1'b0;

`ifdef DISPLAY
        $display("%0t AAU command = %08h", $time, command);
        if (debug_reg_we)
            $display("%0t AAU debug_reg_we=1", $time);
`endif

        case(state)

        //--------------------------------------------------
        // IDLE
        //--------------------------------------------------
        IDLE:
        begin

            busy <= 1'b0;

            if(start) begin

                busy <= 1'b1;

                case(command[7:0])

                //------------------------------------------
                // Register Read
                //------------------------------------------
                CMD_REG_READ:
                begin
                    debug_reg_addr <= command[15:8];

                    // Special cases
                    if (command[15:8] == 8'd32) begin
                        data0_out <= debug_pc;
                        busy <= 1'b0;
                        done <= 1'b1;
                    end
                    else if (command[15:8] == 8'd0) begin
                        data0_out <= 32'd0;
                        busy <= 1'b0;
                        done <= 1'b1;
                    end
                    else begin
                        state <= WAIT_REG_CAPTURE;
                    end
                end

                //------------------------------------------
                // Register Write
                //------------------------------------------
                CMD_REG_WRITE:
                begin
                    debug_reg_addr  <= command[15:8];
                    debug_reg_wdata <= data0_in;

                    state <= DO_REG_WRITE;
                end

                //------------------------------------------
                // Memory Read
                //------------------------------------------
                CMD_MEM_READ:
                begin
                    mem_addr  <= data0_in;
                    mem_write <= 1'b0;
                    mem_valid <= 1'b1;

`ifdef DISPLAY
                    $display("%0t MEM_READ", $time);
                    $display("ADDR = %08h", data0_in);
`endif

                    state <= WAIT_MEM_READ;
                end

                //------------------------------------------
                // Memory Write
                //------------------------------------------
                CMD_MEM_WRITE:
                begin
                    mem_addr  <= data0_in;
                    mem_wdata <= data1_in;

`ifdef DISPLAY
                    $display("%0t AAU MEMORY WRITE", $time);
                    $display("ADDR = %08h", data0_in);
                    $display("DATA = %08h", data1_in);
`endif

                    mem_write <= 1'b1;
                    mem_valid <= 1'b1;

                    state <= WAIT_MEM_WRITE;
                end

                endcase
            end
        end

        //--------------------------------------------------
        // Execute Register Write
        //--------------------------------------------------
        DO_REG_WRITE:
        begin
            debug_reg_we <= 1'b1;

            busy <= 1'b0;
            done <= 1'b1;

            state <= IDLE;

`ifdef DISPLAY
            $display("%0t AAU: REG WRITE addr=%0d data=%08h",
                     $time,
                     debug_reg_addr,
                     debug_reg_wdata);
`endif
        end

        //--------------------------------------------------
        // Wait one cycle for processor to capture register
        //--------------------------------------------------
        WAIT_REG_CAPTURE:
        begin
`ifdef DISPLAY
            $display("%0t ENTER WAIT_REG_CAPTURE", $time);
`endif
            state <= WAIT_REG_READ;
        end

        //--------------------------------------------------
        // Register Read
        //--------------------------------------------------
        WAIT_REG_READ:
        begin
`ifdef DISPLAY
            $display("%0t ENTER WAIT_REG_READ", $time);
`endif

            data0_out <= debug_reg_data;

`ifdef DISPLAY
            $display("%0t DEBUG READ: x%0d -> %08h",
                     $time,
                     debug_reg_addr,
                     debug_reg_data);
`endif

            busy <= 1'b0;
            done <= 1'b1;

            state <= IDLE;

        end

        //--------------------------------------------------
        // Wait for Memory Read
        //--------------------------------------------------
        WAIT_MEM_READ:
        begin
            mem_valid <= 1'b1;
            mem_write <= 1'b0;

            if(mem_ready) begin
                data0_out <= mem_rdata;

                mem_valid <= 1'b0;

                busy <= 1'b0;
                done <= 1'b1;

                state <= IDLE;
            end
        end

        //--------------------------------------------------
        // Wait for Memory Write
        //--------------------------------------------------
        WAIT_MEM_WRITE:
        begin
            mem_valid <= 1'b1;
            mem_write <= 1'b1;

            if(mem_ready) begin
                mem_valid <= 1'b0;
                mem_write <= 1'b0;

                busy <= 1'b0;
                done <= 1'b1;

                state <= IDLE;
            end
        end

        //------------------------------------------
        // Invalid Command
        //------------------------------------------
        default:
        begin

            data0_out <= 32'hDEADBEEF;

            busy <= 1'b0;
            done <= 1'b1;

        end

        endcase

    end

end
endmodule
