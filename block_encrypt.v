module block_encrypt (
		input 	clk, rst_n, 
		input 	start,
		input 	[127:0] plaintext, 
		input 	[127:0] cipherkey, 
		output	[127:0] ciphertext,
		output 	reg done
		);

	parameter IDLE  		 = 2'b00,
             INIT_ROUND  = 2'b01,
             ITERATE		 = 2'b10,
             FINAL 		 = 2'b11;
 
 
	reg [1:0] state, next_state; 
	reg [3:0] round_counter, next_round_counter; 
	reg [127:0] encstate, next_encstate;
	wire [127:0] round_encstate;
	reg final_round_signal;
	wire [127:0] roundkey;
	reg init_keyexpand, rkey_latched; 
	wire key_ready_from_keyexpand; 
   //------------------------------------
   // 1. State register (sequential logic)
   //------------------------------------	
	always @(posedge clk) begin 
		if (!rst_n) begin 
			state <= IDLE; 
			round_counter <= 4'b0; 
			done <= 1'b0;
			encstate	<= 128'b0;
		end 
		else begin 
		state <= next_state; 
		encstate <= next_encstate; 
		round_counter <= next_round_counter;
		if (final_round_signal) begin 
				done <= 1'b1;
		end 	
		end 
	end 

   //------------------------------------
   // 2. Next-state logic (combinational)
   //------------------------------------	
	always @(*) begin 
		next_state = state; 
		case (state)  
			IDLE : begin 
				if (start) next_state = INIT_ROUND; 
			end
			INIT_ROUND : begin 
				next_state = ITERATE; 
			end
			ITERATE : begin 
				if (round_counter < 4'd9) begin 
					next_state = ITERATE; 
				end 
				else begin 
					next_state = FINAL; 
				end 
			end
			FINAL :begin
				if (key_ready_from_keyexpand) begin 
				next_state = IDLE;
				end 
				else begin 
					next_state = FINAL; 
				end 
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
		rkey_latched = 1'b0;
		init_keyexpand = 1'b0; 
		 
		case (state) 
			IDLE: begin 
				next_round_counter = 4'd0;
				next_encstate      = 128'd0;
				rkey_latched       = 1'b0;
				init_keyexpand     = 1'b0;
				
			end 
			INIT_ROUND: begin 
				next_encstate = plaintext ^ cipherkey;
				init_keyexpand = 1'b1;
			end	
			ITERATE:begin
				if (key_ready_from_keyexpand) begin 
					next_round_counter = round_counter + 1; 
					next_encstate = round_encstate;
					rkey_latched = 1'b1; 
				end 
			end	
			FINAL: begin
				if (key_ready_from_keyexpand) begin 
					final_round_signal = 1'b1;
					next_encstate = round_encstate;
					rkey_latched = 1'b1;	
				end 
				
			end	
		endcase
	end 
	
	
	
	aes_round round_trans(.state_in(encstate), .round_key(roundkey), .final_round(final_round_signal), .state_out(round_encstate));
	
	aes_keyexpand keyexp (.clk(clk), .rst_n(rst_n), .init(init_keyexpand), .rkey_latched(rkey_latched), .og_key(cipherkey), .key_ready_reg(key_ready_from_keyexpand), .round_key(roundkey));
	
	assign ciphertext = encstate;
	
endmodule 