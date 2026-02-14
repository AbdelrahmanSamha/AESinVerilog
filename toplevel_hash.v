// -----------------------------------------------------
// Created by Abdelrahman Samha
// The Hashemite University
// Project: [Choas-Image-Encryption]
// Date: [5/5/2025]
// -----------------------------------------------------
	module toplevel_hash(
		input clk,                // Clock
		input rst_n,                // Active-low reset
		input sys_start,
		input [31:0] length,
		input valid_data, 
		input [511:0] data,
		
		output [255:0] hash_out,  // Computed SHA-256 hash
		output reg hash_valid         // High when hash_out is valid
	);
	
	localparam IDLE 		 = 2'b00, 
				  WAIT_DATA1 = 2'b01, 
				  WAIT_HASH  = 2'b10, 
				  WAIT_DATA2 = 2'b11; 
				  
	
	
	
	reg [1:0]r_state, w_state; 
	reg [31:0] r_counter, w_counter; 
	reg start_hash, r_first_round, w_first_round;
		wire round_done;
	//registers
	
	always @(posedge clk, negedge rst_n) begin 
		if (!rst_n)begin 
			r_state <= IDLE; 
			r_counter <= 32'b0;
			r_first_round <= 1'b0;
			
		end 
		else begin 
			r_state <= w_state; 
			r_counter <= w_counter; 
			r_first_round <= w_first_round;
		end 
	end 
	
	// next state logic 
	
	always @(*) begin
		w_state = r_state; 
		case (r_state) 
			IDLE: 
				if (sys_start) w_state = WAIT_DATA1; 
				
			WAIT_DATA1: 
				if (valid_data) w_state = WAIT_HASH; 
			
			WAIT_HASH:begin 
				 
					if ((r_counter == length-32'd1) && round_done) w_state = IDLE; 
					else if ((r_counter<length-32'd1) && (round_done)) w_state =WAIT_DATA2; 
				end 
				
			WAIT_DATA2: 
				if (valid_data) w_state = WAIT_HASH; 

			
		endcase
	end
	
	
	always @(*) begin 
		w_counter = r_counter; 
		start_hash = 1'b0;
		w_first_round= r_first_round;
		hash_valid = 1'b0;
		case (r_state)
			IDLE: 
				w_counter = 32'b0;
				
			WAIT_DATA1: begin 
				if (valid_data) begin 
					start_hash = 1'b1; 
					w_first_round = 1'b1; 
					end 
				
			end 
			WAIT_HASH:begin 
				if ((r_counter == length-32'd1) && round_done) hash_valid = 1'b1;
				else if ((r_counter<length-32'd1) && (round_done)) w_counter= w_counter +32'd1; 
			end 
			WAIT_DATA2:begin 
				if (valid_data) begin 
					start_hash = 1'b1; 
					w_first_round = 1'b0; 
					
				end 
				
			end 

		endcase
	
	end 
	
	
	
	
	
	//----------------------------------------------------------
	// SHA256 Instance
	//----------------------------------------------------------
	SHA256 sha256_instance (
		.clk(clk),               // Connect to top-level clock
		.rst_n(rst_n),               // Connect to top-level reset
		.go_i(start_hash),       // Start signal from top-level
		.block(data),   			 // Concatenated 512-bit input block
		.first_round(r_first_round), 
		.prev(hash_out),
		.Digest(hash_out),       // Final hash output (256 bits)
		.sig_done(round_done)    // Indicates hash_out is valid
	);
	
	endmodule
