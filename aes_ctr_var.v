module aes_ctr_var
(
	input clk, 
	input rst_n, 
	input init_m, 

	

	input terminate_session_m,
	
	input dec, 
	
	input [127:0] text_in,

		
	output [127:0] text_out,
	
   input [127:0] counter_m,
	
	output reg         key_expand_ready,

	input              valid_in_key_aes,
	input              valid_in_block_aes,
	
 // Shared datapath interface
    output reg          cipher_start,
    output wire [127:0] aes_in_block,
    input  wire [127:0] aes_raw_out,         // keystream
    input  wire         block_done,

    output reg          key_exp_start,
    input  wire         key_expand_finish,

    output reg          mem_key_rw,
	 output done_m
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
	reg mem_key_rw_next;
		
	reg done_reg, done_reg_next;

	
   reg  [127:0] ctr_in;
   reg  [31:0] i;


	
	assign done_m = done_reg;

	assign aes_in_block = ctr_in;
	assign text_out   = text_in ^ aes_raw_out;

		
			// -----------------------------
			// FSM: State register
			// -----------------------------
			always @(posedge clk) begin
				if (!rst_n) begin 
					state_m <= IDLE_m;
					mem_key_rw <= 1'b0;
					done_reg <= 1'b0;
					key_expand_ready <= 1'b0;
					i <= 32'b0;

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
					
					// clear when starting NEW key expansion
					if (key_exp_start) begin
						key_expand_ready <= 1'b0;
					end
		
					// set when key expansion finishes
					if (key_expand_finish) begin
						key_expand_ready <= 1'b1;
					end
		
					if (terminate_session_m) begin
						key_expand_ready <= 1'b0;
					end
		
					if (next_state_m == IDLE_m) begin
						key_expand_ready <= 1'b0;
					end
					if (block_done)
						i <= i + 1;
						
				if (state_m == IDLE_m && next_state_m == KEYEXP_INIT_m)// if u add the reset from the core no need for this
					i <= 32'd0;

				if (terminate_session_m)
					i <= 32'd0;
					
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
						if (valid_in_key_aes) next_state_m = KEYEXP_WAIT_m;
		
					KEYEXP_WAIT_m:
						if (key_expand_finish)
							next_state_m = CIPHER_HOLD_m;
		
					CIPHER_HOLD_m:
						if(valid_in_block_aes) next_state_m = CIPHER_WAIT_m;
						else if (terminate_session_m) next_state_m = IDLE_m; 
		
					CIPHER_WAIT_m:
						if (block_done)
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
				cipher_start  = 1'b0 ;
				mem_key_rw_next   = mem_key_rw;
				done_reg_next     = done_reg;
				
				ctr_in = counter_m + i;
				
				case (state_m)
					IDLE_m: begin
						mem_key_rw_next = 1'b0;
						cipher_start = 1'b0;
						done_reg_next = 1'b0;
					end
		
					KEYEXP_INIT_m: begin
						if (valid_in_key_aes) begin 
							key_exp_start = 1'b1;
							mem_key_rw_next = 1'b1;
						end 
					end
		
					KEYEXP_WAIT_m: begin
						//just wait
					end
		
					CIPHER_HOLD_m: begin
						done_reg_next = 1'b0;
						if (valid_in_block_aes)begin 
							cipher_start = 1'b1;
							mem_key_rw_next = 1'b0;
						end 
					end
		
					CIPHER_WAIT_m: begin
						
							if (block_done)begin 
								done_reg_next = 1'b1;
							end 
						end
				endcase
			end

	
	
endmodule
