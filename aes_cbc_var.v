module aes_cbc_var
(
		 input  wire                  clk,
		 input  wire                  rst_n,

		 input  wire                  init,
		 input  wire                  dec,                 // 0=ENC, 1=DEC
		 input  wire [127:0]          iv,

		 input  wire [127:0]          text_in,
		 input  wire                  terminate_session,

		 input  wire                  valid_in_key_aes,
		 input  wire                  valid_in_block_aes,

		 output reg  [127:0]          text_out,
		 output wire                  done,

		 output reg                   key_expand_ready,

 
		 
		 // var 
		 
		 // BE
		 output reg cipher_start,
		 output wire [127:0] aes_in_block,
		 input wire [127:0] aes_raw_out, // cipehrtext from BE
		 input        block_done,

		// key
		output reg key_exp_start, // input to keyexp

		input wire        key_expand_finish,
		


		 output reg mem_key_rw



		
	);

		 // ------------------------------------------------
		 // FSM states
		 // ------------------------------------------------
		 localparam IDLE        = 3'b000,
						KEYEXP_INIT = 3'b001,
						KEYEXP_WAIT = 3'b010,
						CIPHER_HOLD = 3'b011,
						CIPHER_WAIT = 3'b100;

		 reg [2:0] state, next_state;
	
		 reg mem_key_rw_next;


		 reg done_reg, done_reg_next;
		 assign done = done_reg;


		 // chaining
		 reg  [127:0] chain_reg;
		 wire  [127:0] text_out_internal;
		 reg          first_block;

		 // ------------------------------------------------
		 // Wires
		 // ------------------------------------------------





		 wire [127:0] chain_val    = first_block ? iv : chain_reg;

		 assign aes_in_block = (dec) ? text_in : (text_in ^ chain_val);

		 // final CBC output
		 assign text_out_internal = (dec) ? (aes_raw_out ^ chain_val) : aes_raw_out;


		 // ------------------------------------------------
		 // Sequential: state + regs
		 // ------------------------------------------------
		 always @(posedge clk) begin
			  if (!rst_n) begin
					state            <= IDLE;
					mem_key_rw       <= 1'b0;
					done_reg         <= 1'b0;
					key_expand_ready <= 1'b0;

					chain_reg        <= 128'd0;
					text_out        <= 128'd0;
					first_block      <= 1'b1;
			  end else begin
					state    <= next_state;
					done_reg <= done_reg_next;

					// mem mux control
					if (key_expand_finish)
						 mem_key_rw <= 1'b0;
					else
						 mem_key_rw <= mem_key_rw_next;

					// key_expand_ready
					if (key_exp_start)
						 key_expand_ready <= 1'b0;

					if (key_expand_finish)
						 key_expand_ready <= 1'b1;

					if (terminate_session)
						 key_expand_ready <= 1'b0;

					if (next_state == IDLE)
						 key_expand_ready <= 1'b0;

					// CBC chain update ONLY when block finishes
					if (block_done) 
					text_out <= text_out_internal;
					
					if (block_done) begin
						 if (dec)
							  chain_reg <= text_in;      // DEC: next chain = current ciphertext input
						 else
							  chain_reg <= aes_raw_out;  // ENC: next chain = produced ciphertext

						 first_block <= 1'b0;
					end

					// reset chaining at new session start
					if (state == IDLE && next_state == KEYEXP_INIT) begin
						 chain_reg   <= 128'd0;
						 first_block <= 1'b1;
					end

					if (terminate_session) begin
						 chain_reg   <= 128'd0;
						 first_block <= 1'b1;
					end
			  end
		 end

		 // ------------------------------------------------
		 // Next-state logic
		 // ------------------------------------------------
		 always @(*) begin
			  next_state = state;

			  case (state)
					IDLE:
						 if (init) next_state = KEYEXP_INIT;

					KEYEXP_INIT:
						 if (valid_in_key_aes) next_state = KEYEXP_WAIT;

					KEYEXP_WAIT:
						 if (key_expand_finish) next_state = CIPHER_HOLD;

					CIPHER_HOLD:
						 if (valid_in_block_aes) next_state = CIPHER_WAIT;
						 else if (terminate_session) next_state = IDLE;

					CIPHER_WAIT:
						 if (block_done) next_state = CIPHER_HOLD;

					default:
						 next_state = IDLE;
			  endcase
		 end

		 // ------------------------------------------------
		 // Output logic
		 // ------------------------------------------------
		 always @(*) begin
			  key_exp_start   = 1'b0;
			  cipher_start    = 1'b0;
			  mem_key_rw_next = mem_key_rw;
			  done_reg_next   = 1'b0; // 1-cycle pulse

			  case (state)
					IDLE: begin
						 mem_key_rw_next = 1'b0;
					end

					KEYEXP_INIT: begin
						 if (valid_in_key_aes) begin
							  key_exp_start   = 1'b1;
							  mem_key_rw_next = 1'b1; // write keys
						 end
					end

					KEYEXP_WAIT: begin
						 // wait
					end

					CIPHER_HOLD: begin
						 if (valid_in_block_aes) begin
							  cipher_start    = 1'b1;
							  mem_key_rw_next = 1'b0; // read keys
						 end
					end

					CIPHER_WAIT: begin
						 if (block_done) begin
							  done_reg_next = 1'b1;
						 end
					end
			  endcase
		 end

	endmodule
	