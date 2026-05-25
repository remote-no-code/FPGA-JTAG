//Tap is finite state machine
module jtag_tap(  
	input tck,
	input tms,
	input tdi,
	input trst,
	
	output reg tdo
);

parameter TEST_LOGIC_RESET = 4'h0;
parameter RUN_TEST_IDLE = 4'h1;

parameter SHIFT_IR = 4'h2;
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

parameter IDCODE = 4'b0001;
parameter BYPASS = 4'b1111;

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
	tdo = 1'b0;
	
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
					
			SHIFT_IR:
				if(tms)
					state <= EXIT1_IR;
				else
					state <= SHIFT_IR;
					
			UPDATE_IR:
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
					
					
			SHIFT_DR:
				if(tms)
					state <= EXIT1_DR;
				else 
					state <= SHIFT_DR;
					
			UPDATE_DR:
				if(tms)
					state <= TEST_LOGIC_RESET;
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
					
			default:
				state <= TEST_LOGIC_RESET;
		endcase
	end
end

always @(posedge tck) begin
	
	if(state == CAPTURE_IR)
		ir_shift = 4'b0001;
end

always @(posedge tck) begin

	if(state == SHIFT_IR)
		ir_shift <= {tdi, ir_shift[3:1]};
	
end

always @(posedge tck) begin
	
	if(state == UPDATE_IR) begin
		ir <= ir_shift;
		
		if (ir_shift == IDCODE)
			dr_shift <= idcode;
	end
		
end

always @(posedge tck) begin
	if( state == CAPTURE_DR) begin
		case(ir)
			IDCODE:
				dr_shift <= idcode;
			
			BYPASS:
				bypass_bit <= 1'b0;
		endcase
	end
end

always @(posedge tck) begin

	if( state == SHIFT_DR) begin
		case (ir)
			
			IDCODE:
			begin 
				dr_shift <= {tdi, dr_shift[31:1]};
				
			end
			
			BYPASS:
			begin
				tdo <= bypass_bit;
				bypass_bit <= tdi;
			end
			
		endcase
	end
end



always @(*) begin
	case(ir) 
		IDCODE:
			tdo = dr_shift[0];
			
		BYPASS:
			tdo = bypass_bit;
			
		default:
			tdo = 0;
		
	endcase
end

endmodule

