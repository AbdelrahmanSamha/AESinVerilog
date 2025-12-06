module block_encrypt (
		input 	clk, rst_n, 
		input 	start,
		input 	dec,
		input 	[127:0] plaintext, 
		input 	[127:0] roundkey, 
		output	[127:0] ciphertext,
		output 	reg [3:0] key_address,
		output 	reg done
		);

	parameter IDLE  		 = 3'b000,
				 SETUP 		 = 3'b001,
             INIT_ROUND  = 3'b010,
				 GET_KEY		 = 3'b011,
             ITERATE		 = 3'b100,
             FINAL 		 = 3'b101;
 
 
	reg [2:0] state, next_state; 
	reg [3:0] round_counter, next_round_counter; 
	reg [127:0] encstate, next_encstate;
	wire [127:0] round_encstate;
	reg final_round_signal;
	reg next_done;
 
   //------------------------------------
   // 1. State register (sequential logic)
   //------------------------------------	
	always @(posedge clk) begin 
		if (!rst_n) begin 
			state <= IDLE; 
			done <= 1'b0;
			encstate	<= 128'b0;
			if (!dec) round_counter <= 4'd0;
			else if (dec) round_counter <= 4'd10;
		end 
		else begin 
		state <= next_state; 
		encstate <= next_encstate; 
		round_counter <= next_round_counter;
		done <= next_done;	
		end 
	end 

   //------------------------------------
   // 2. Next-state logic (combinational)
   //------------------------------------	
	always @(*) begin 
		next_state = state; 
		case (state)  
			IDLE : begin 
				if (start) next_state = SETUP; 
			end
			
			SETUP : begin 
			next_state = INIT_ROUND;
			end 
			
			INIT_ROUND : begin 
				next_state = GET_KEY; 
			end
			
			GET_KEY : begin 
			next_state = ITERATE;
			end
			
			ITERATE : begin 
				if ((!dec) && round_counter < 4'd9) begin 
					next_state = GET_KEY; 
				end 
				else if ((dec) && round_counter > 4'd1) begin 
					next_state = GET_KEY;
				end 
				else begin 
					next_state = FINAL; 
				end 
			end
			
			FINAL : begin
				next_state = IDLE; 
			end
		endcase 
	end 
		
   //------------------------------------
   // 3. Output logic (combinational)
   //------------------------------------
   always @(*) begin	
		next_round_counter = round_counter;
		next_encstate = encstate;
		final_round_signal = 1'b0;
		key_address = 4'b0;
		next_done	= done;
		case (state) 
			IDLE: begin
				next_encstate      = 128'd0;
				next_done 			 =1'b0;
			end
			
			SETUP : begin 
				if (!dec) begin 
					key_address = 4'd0;
				end 
				else if (dec) begin 
					key_address = 4'd10; 
				end
			end 	
			
			INIT_ROUND: begin 
				next_encstate = plaintext ^ roundkey;
				if (!dec) begin 
					next_round_counter = round_counter + 1; 
				end 
				else if(dec) begin 
					next_round_counter = round_counter - 1;
				end 
			end
			
			GET_KEY : begin 
				key_address = round_counter;
			end			
			
			ITERATE:begin
			 
				next_encstate = round_encstate;
				if (!dec)begin 
					next_round_counter = round_counter + 1;
					if (round_counter == 4'd9) begin 
						key_address = 4'd10;
						
					end
				end
				else if (dec) begin
					next_round_counter = round_counter - 1;
					if (round_counter == 4'd0)begin 
						key_address = 4'd0; 
					end 
				end	
			end	
			FINAL: begin
				final_round_signal = 1'b1;
				next_encstate = round_encstate;
				next_done =1'b1;
			end	
		endcase
	end 
	
	
	
	aes_round round_trans(.state_in(encstate), .round_key(roundkey), .final_round(final_round_signal), .state_out(round_encstate),.dec(dec));
	
	
	
	assign ciphertext = encstate;
	
endmodule 