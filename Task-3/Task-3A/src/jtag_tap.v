//Tap is finite state machine
module jtag_tap(  
	input tck, //JTAG test clock
	input tms, //test mode select from tap state
	input tdi, // test data in serial input for ins and data 
	input trst, // active reset
	
	output tdo, //data data out seriol out for shifted ins/data
	
	output reg debug_halt_req, //req to halt processor
	output reg debug_resume_req, // request to resume processor
	output reg debug_reset_req, //request to reset the processor
	
	input debug_halted, // indicator that processor is halted
	input [31:0] debug_pc // processor current 32bit program counter value
);

reg tdo_reg;

assign tdo = tdo_reg;

parameter TEST_LOGIC_RESET = 4'h0; //reset state
parameter RUN_TEST_IDLE = 4'h1; // idle state nothing happens

parameter SHIFT_IR = 4'h2; //shift instruction bits into/out of IR
parameter UPDATE_IR = 4'h3;
parameter SELECT_IR_SCAN = 4'h4; 
parameter CAPTURE_IR = 4'h5;
parameter EXIT1_IR = 4'h6;
parameter PAUSE_IR = 4'h7;
parameter EXIT2_IR = 4'h8;

parameter SHIFT_DR = 4'h9;
parameter UPDATE_DR = 4'hA;
parameter SELECT_DR_SCAN = 4'hB; 
parameter CAPTURE_DR = 4'hC;
parameter EXIT1_DR = 4'hD;
parameter PAUSE_DR = 4'hE;
parameter EXIT2_DR = 4'hF;

reg[3:0] state;


// JTAG INSTRUCTIONS
parameter IDCODE = 4'b0001; //read device identification code
parameter DEBUG_CTRL = 4'b0010; // Access a debug control register
parameter DEBUG_STATUS = 4'b0011; // Acess status debug status register
parameter DEBUG_PC = 4'b0100; //Read or write processor program counter
parameter BYPASS = 4'b1111; // select the 1 bit bypass register to min scan chain length


reg[3:0] ir;
reg[3:0] ir_shift;

reg[31:0] idcode;
reg[31:0] dr_shift;
reg bypass_bit;


initial begin 
	state = TEST_LOGIC_RESET;
	ir = 4'b0000;
	ir_shift = 4'b0000;
	idcode = 32'h81262776;
	dr_shift = 32'h00000000;
	bypass_bit = 1'b0;
	tdo_reg = 1'b0;
	
end

always @(posedge tck or posedge trst) begin
	
	if(trst)
		state <= TEST_LOGIC_RESET;
		
	else begin
		case (state)
		// TMS CONTROLS NAVIGATION
			TEST_LOGIC_RESET:
				if(tms)    
					state <= TEST_LOGIC_RESET;
				else 
					state <= RUN_TEST_IDLE;
			
			RUN_TEST_IDLE:
				if(tms) 
					state <= SELECT_DR_SCAN;
				else 
					state <= RUN_TEST_IDLE;
			
			SELECT_DR_SCAN: 
				if(tms)
					state <= SELECT_IR_SCAN;
				else
					state <= CAPTURE_DR;		
								
			CAPTURE_DR: 
				if(tms)
					state <= EXIT1_DR;
				else
					state <= SHIFT_DR;
					
			SHIFT_DR:
				if(tms)
					state <= EXIT1_DR;
				else 
					state <= SHIFT_DR;
					
			EXIT1_DR: 
				if(tms)
					state <= UPDATE_DR;
				else
					state <= PAUSE_DR;
					
			PAUSE_DR: 
				if(tms)
					state <= EXIT2_DR;
				else
					state <= PAUSE_DR;
					
			EXIT2_DR: 
				if(tms)
					state <= UPDATE_DR;
				else
					state <= SHIFT_DR;
							
			UPDATE_DR:
				if(tms)
					state <= SELECT_DR_SCAN;
				else
					state <= RUN_TEST_IDLE;
					
			
			SELECT_IR_SCAN:
				if(tms) 
					state <= TEST_LOGIC_RESET;
				else
					state <= CAPTURE_IR;
					
			CAPTURE_IR: 
				if(tms)
					state <= EXIT1_IR;
				else
					state <= SHIFT_IR;
			
			SHIFT_IR:
				if(tms)
					state <= EXIT1_IR;
				else
					state <= SHIFT_IR;
					
			EXIT1_IR: 
				if(tms)
					state <= UPDATE_IR;
				else
					state <= PAUSE_IR;
					
			PAUSE_IR: 
				if(tms)
					state <= EXIT2_IR;
				else
					state <= PAUSE_IR;
			
			EXIT2_IR: 
				if(tms)
					state <= UPDATE_IR;
				else
					state <= SHIFT_IR;
					
			
			UPDATE_IR:
				if(tms)
					state <= SELECT_DR_SCAN;
				else 
					state <= RUN_TEST_IDLE;

					
			default:
				state <= TEST_LOGIC_RESET;
		endcase
	end
end

always @(posedge tck) begin
	
	if(state == CAPTURE_IR)
		ir_shift <= 4'b0001;
	
	else if(state == SHIFT_IR)
		ir_shift <= {tdi, ir_shift[3:1]};
		
	else if(state == UPDATE_IR) begin
		ir <= ir_shift;

	end
		
end


always @(posedge tck) begin
	if( state == CAPTURE_DR) begin
		case(ir)
			IDCODE:
				dr_shift <= idcode;
			
			DEBUG_STATUS:
    				dr_shift <= {31'b0, debug_halted};
    				
    			DEBUG_PC:
    				dr_shift <= debug_pc;
    
			BYPASS:
				bypass_bit <= 1'b0;
		endcase
	end
	
	else if( state == SHIFT_DR) begin
		case (ir)
			
			IDCODE,
			DEBUG_STATUS,
			DEBUG_PC,
			DEBUG_CTRL:
			begin 
				tdo_reg <= dr_shift[0];
				dr_shift <= {tdi, dr_shift[31:1]};
				
			end
			
			BYPASS:
			begin
				tdo_reg <= bypass_bit;
				bypass_bit <= tdi;
			end
			
		endcase
	end
end

always @(posedge tck) begin
	debug_halt_req <=0;
	debug_resume_req <=0;
	debug_reset_req <=0;
	
	if(state == UPDATE_DR && ir == DEBUG_CTRL) begin
		debug_halt_req <= dr_shift[0];
		debug_resume_req <= dr_shift[1];
		debug_reset_req <= dr_shift[2];
	end	
end

endmodule


