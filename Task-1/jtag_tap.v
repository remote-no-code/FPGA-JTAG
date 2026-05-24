//Tap is finite state machine
module jtag_tap(  
	input tck,
	input tms,
	input tdi,
	input trst,
	
	output reg tdo
);

parameter TEST_LOGIC_RESET = 0;
parameter RUN_TEST_IDLE = 1;
parameter SHIFT_IR = 2;
parameter UPDATE_IR = 3;
parameter SHIFT_DR = 4;
parameter UPDATE_DR = 5;

reg[2:0] state;

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
	dr_shift = 32'h81262776;
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
					state <= SHIFT_IR;
				else 
					state <= RUN_TEST_IDLE;
					
			SHIFT_IR:
				if(tms)
					state <= UPDATE_IR;
				else
					state <= SHIFT_IR;
					
			UPDATE_IR:
				if(tms)
					state <= SHIFT_DR;
				else 
					state <= RUN_TEST_IDLE;
				
			SHIFT_DR:
				if(tms)
					state <= UPDATE_DR;
				else 
					state <= SHIFT_DR;
					
			UPDATE_DR:
				if(tms)
					state <= TEST_LOGIC_RESET;
				else
					state <= RUN_TEST_IDLE;
		endcase
	end
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
			
			default:
				tdo <= 0;
			
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


