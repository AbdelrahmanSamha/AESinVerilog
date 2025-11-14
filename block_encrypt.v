module block_encrypt (
		input 	clk, rst_n, 
		input 	start,
		input 	[127:0] plaintext, 
		input 	[127:0] cipherkey, 
		output	[127:0] ciphertext,
		output 	done
		);

	parameter IDLE  		 = 2'b00,
             INIT_ROUND  = 2'b01,
             ITERATE		 = 2'b10,
             FINAL 		 = 2'b11,
 
 
	reg [1:0] state, next_state; 
	reg [3:0] round_counter, next_round_counter; 

	
   //------------------------------------
   // 1. State register (sequential logic)
   //------------------------------------	
	always @(posedge clk ) begin 
		if (!rst_n) begin 
			state <= IDLE; 
			round_counter <= 4'b0; 
		
		end 
		else begin 
		state <= next_state; 
		round_counter <= next_round_counter; 
		end 
	end 

   //------------------------------------
   // 2. Next-state logic (combinational)
   //------------------------------------	
	always @(*) begin 
		next_state = state; 
		case (state)  
			IDLE : 
				if (start) next_state = INIT_ROUND; 
			INIT_ROUND :
				next_state = ITERATE; 
			ITERATE : 
				if (round_counter < 4'd9) begin 
					next_state = ITERATE; 
				end 
				else begin 
					next_state = FINAL; 
				end 
			FINAL :
				next_state = IDLE; 
		endcase 
	end 
		
   //------------------------------------
   // 3. Output logic (combinational)
   //------------------------------------
   always @(*) begin	
	
	
	
	end 
	
endmodule 