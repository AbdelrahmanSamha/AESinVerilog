module aes_ctr #(
    parameter integer KEY_SIZE  = 128,   // 128, 192, 256
	parameter  IS_MAIN   = 0
)(
	input clk, 
	input rst_n, 
	//these ports are for the main AES_ECB
	input init_m, 
	input dec_m, 
	
	input [KEY_SIZE-1 : 0] og_key_m, 
	input [127:0]	text_in_m,
	input 			valid_in_m,
	input terminate_session_m,
	
	input [127:0] counter_m,
	
	output [127:0]  text_out_m,
	output done_m,
	output reg cipher_start_all,
	output [127:0]roundkey_m_out,
	
	// these ports are for non-main instances
	
	input start_cipher, 
	input dec, 
	
	input [127:0] text_in,
	input [127:0] read_roundkey_in, 
		
	output [127:0] text_out,
	

   input [127:0] counter_in
);


// ------------------------------------------------
// Internal declarations for MAIN
// ------------------------------------------------
	localparam  IDLE_m        = 3'b000,
				KEYEXP_INIT_m = 3'b001,
				KEYEXP_WAIT_m = 3'b010,
				CIPHER_HOLD_m    = 3'b011,
				CIPHER_WAIT_m   = 3'b100;
				
	reg [2:0]state_m, next_state_m;
	reg mem_key_rw, mem_key_rw_next;
		
	reg done_reg, done_reg_next;
	reg key_exp_start ;
		
	wire key_expand_finish, block_encryption_finish_m;
	wire [3:0] read_key_address, write_key_address;
	wire [4:0] key_address;
	wire mem_round_key_en; 
	wire [127:0] gen_roundkey;
	wire [127:0] keystream;
	
	assign done_m = done_reg;
//END OF MAIN WIRES AND REGISTERS...

	generate 
		if (IS_MAIN == 1)begin 
			// -----------------------------
			// Block Encrypt
			// -----------------------------
				
			
			block_encrypt #(KEY_SIZE) BE (
				.clk(clk),
				.rst_n(rst_n),
				.start(cipher_start_all),
				.dec(dec_m),
				.plaintext(counter_m),
				.roundkey(roundkey_m_out),
				.ciphertext(keystream),
				.key_address(read_key_address),
				.done(block_encryption_finish_m)
				);
			// -----------------------------
			// Key Expansion
			// -----------------------------
			aes_keyexpand #(KEY_SIZE) keyexp (
				.clk(clk),
				.rst_n(rst_n),
				.init(key_exp_start),
				.og_key(og_key_m),
				.store_key_mem(mem_round_key_en),
				.address(write_key_address),
				.round_key(gen_roundkey),
				.finish(key_expand_finish)
			);
		
			// -----------------------------
			// Round-key memory
			// -----------------------------
			mem_round_keys keymem (
				.clock(clk),
				.address(key_address),
				.data(gen_roundkey),
				.wren(mem_round_key_en),
				.q(roundkey_m_out)
			);
		
			mux2to1 #(4) addr_mux (
				.in0(read_key_address),
				.in1(write_key_address),
				.sel(mem_key_rw),
				.out(key_address[3:0])
			);
			assign key_address[4] = 1'b0;
			
         assign text_out_m = keystream ^ text_in_m;

			end
	endgenerate



	generate 
		if (IS_MAIN == 1)begin  
		
			// -----------------------------
			// FSM: State register
			// -----------------------------
			always @(posedge clk) begin
				if (!rst_n) begin 
					state_m <= IDLE_m;
					mem_key_rw <= 1'b0;
					done_reg <= 1'b0;
				end
				else begin 
					state_m <= next_state_m;
					done_reg <= done_reg_next;
					if(key_expand_finish) begin 
						mem_key_rw <= 1'b0;
					end 
					else begin 
						mem_key_rw <= mem_key_rw_next;
					end 
				end
			end
		
			// -----------------------------
			// FSM: Next-state logic
			// -----------------------------
			always @(*) begin
				next_state_m = state_m;
		
				case (state_m)
					IDLE_m:
						if (init_m) next_state_m = KEYEXP_INIT_m;
		
					KEYEXP_INIT_m:
						if (valid_in_m) next_state_m = KEYEXP_WAIT_m;
		
					KEYEXP_WAIT_m:
						if (key_expand_finish)
							next_state_m = CIPHER_HOLD_m;
		
					CIPHER_HOLD_m:
						if(valid_in_m) next_state_m = CIPHER_WAIT_m;
						else if (terminate_session_m) next_state_m = IDLE_m; 
		
					CIPHER_WAIT_m:
						if (block_encryption_finish_m)
							next_state_m = CIPHER_HOLD_m;
							
					default:
						next_state_m = IDLE_m;
				endcase
			end
		
			// -----------------------------
			// FSM: Output logic
			// -----------------------------
			always @(*) begin
				key_exp_start = 1'b0;
				cipher_start_all  = 1'b0 ;
				mem_key_rw_next   = mem_key_rw;
				done_reg_next     = done_reg;
		
				case (state_m)
					IDLE_m: begin
						mem_key_rw_next = 1'b0;
						cipher_start_all = 1'b0;
						done_reg_next = 1'b0;
					end
		
					KEYEXP_INIT_m: begin
						if (valid_in_m) begin 
							key_exp_start = 1'b1;
							mem_key_rw_next = 1'b1;
						end 
					end
		
					KEYEXP_WAIT_m: begin
						//just wait
					end
		
					CIPHER_HOLD_m: begin
						done_reg_next = 1'b0;
						if (valid_in_m)begin 
							cipher_start_all = 1'b1;
							mem_key_rw_next = 1'b0;
						end 
					end
		
					CIPHER_WAIT_m: begin
						
							if (block_encryption_finish_m)begin 
								done_reg_next = 1'b1;
							end 
						end
				endcase
			end
		end
	endgenerate
	
	
// ------------------------------------------------
// Internal declarations for non-MAIN instances
// ------------------------------------------------

	generate 
		if (IS_MAIN == 0) begin 
			wire [127:0] slave_keystream;

			block_encrypt #(KEY_SIZE) BE (
				.clk(clk),
				.rst_n(rst_n),
				.start(start_cipher),
				.dec(dec),
				.plaintext(counter_in),
				.roundkey(read_roundkey_in),
				.ciphertext(slave_keystream),
				.key_address(),
				.done()
				);
				
				assign text_out = slave_keystream ^ text_in;
		end	

	endgenerate
	
endmodule
