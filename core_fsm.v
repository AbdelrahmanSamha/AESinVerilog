module core_fsm #(
    parameter integer MODE    = 0,     // 0=ECB,1=CBC,2=CTR,3=OFB,4=CFB
    parameter integer FIXED_VARKEY_MODE    = 0     // 0=ECB,1=CBC,2=CTR,3=OFB,4=CFB
)(
    input  wire        clk,
    input  wire        rst_n,

    // -------- from BUFFER (header pulses + stored regs) --------
    input  wire        cmd_ready,      // 1-cycle pulse
    input  wire        flags_ready,    // 1-cycle pulse
    input  wire        length_ready,   // 1-cycle pulse
    input  wire        tx_done,   // 1-cycle pulse
    
	 input  wire [2:0]  mode_sel, 
	 

    input  wire [7:0]  cmd_reg,
    input  wire [7:0]  flags_reg,
    input  wire [31:0] length_reg,

    // -------- from BUFFER (sticky payload ready) --------
    input  wire        key_ready,
    input  wire        iv_ready,
    input  wire        block_ready,
    input  wire        sha_ready,  
	 input  wire        sha_hash_valid,
	 
    // -------- from AES --------
    input  wire        key_expand_ready,  // high when key expansion finished
    input  wire        aes_done,          // indicates block finished

    // -------- to AES --------
    output reg         aes_start,         // 1-cycle pulse
    output reg         dec,               // stable dec bit
    output reg         valid_in_key_aes,   // 1-cycle pulse
    output reg         valid_in_block_aes,  // 1-cycle pulse (blk_sent protected)
	 
	 output reg			  finish_cmd_rst,// rst after finish frame and operation 
	 
	 output reg  sha_sys_start,
	 output reg  sha_valid_data,
	 
	 output reg  trng_start,   
	 input  wire trng_done,
	 output wire cmd_is_trng,
	 
	 input  wire echo_req,
	 output reg echo_tx_start
	
);

    // ============================================================
    // locals
    // ============================================================
    localparam integer ECB_MODE = 0;
	 localparam [7:0] CMD_AES = 8'h01;
    localparam BLOCK_LAB = 8'h02;
    localparam integer VAR_MODES = 5;
    localparam integer VAR_KEYS = 6;
    localparam integer FULL = 7;
		 
	 localparam [7:0] CMD_SHA = 8'h03;
	 wire cmd_is_sha = (cmd_reg == CMD_SHA);
	 
	 localparam [7:0] CMD_TRNG = 8'h04;
	 assign cmd_is_trng = (cmd_reg == CMD_TRNG);

    wire iv_needed ;
	 assign iv_needed = !((MODE == ECB_MODE) || (MODE == VAR_MODES && mode_sel == 3'b000)
							 || (MODE == VAR_KEYS && FIXED_VARKEY_MODE == 0) || (MODE == FULL && mode_sel == 3'b000));
    wire have_key = key_ready && (iv_needed ? iv_ready : 1'b1);

    // ============================================================
    // state encoding
    // ============================================================
    localparam [3:0]
        S_WAIT_HDR     = 4'b0000,
        S_KEYEXP       = 4'b0001,
        S_BLOCKS       = 4'b0010,
        S_WAIT_TX      = 4'b0011,
		  S_SHA_WAIT     = 4'b0100,
        S_DONE         = 4'b0101,
		  S_TRNG_START   = 4'b0110,
		  S_TRNG_WAIT    = 4'b0111,
		  S_TRNG_WAIT_TX = 4'b1000,
		  S_ECHO_START   = 4'b1001,
        S_ECHO_WAIT_TX = 4'b1010;
		  
    reg [3:0] state, next_state;

    // ============================================================
    // header latch flags (because pulses are 1 cycle)
    // ============================================================
    reg got_cmd,   got_cmd_n;
    reg got_flags, got_flags_n;
    reg got_len,   got_len_n;
	 reg trng_round, trng_round_n;  


    wire hdr_done_aes_sha  = got_cmd & got_flags & got_len;
	 wire hdr_done_trng    =  got_cmd;               
	 wire hdr_done         =  cmd_is_trng ? hdr_done_trng : hdr_done_aes_sha;
	 
    wire cmd_is_aes = (cmd_reg == CMD_AES) || (cmd_reg == BLOCK_LAB);

    // ============================================================
    // block guard + key guard
    // ============================================================
    reg blk_sent, blk_sent_n;
    reg key_sent, key_sent_n;
    reg got_tx_done, got_tx_done_n;
	 reg sha_sent, sha_sent_n;

    // ============================================================
    // block counting (based on length_reg bytes)
    // blocks_total = length_reg / 16 = length_reg[31:4]
    // ============================================================
    reg [31:0] blocks_total, blocks_total_n;
    reg [31:0] block_index,  block_index_n;

    wire [31:0] blocks_total_m1 =
        (blocks_total == 32'd0) ? 32'd0 : (blocks_total - 32'd1);
		 

    wire last_block = (block_index == blocks_total_m1);

    // ============================================================
    // 1) State register + sequential regs
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_WAIT_HDR;

            got_cmd      <= 1'b0;
            got_flags    <= 1'b0;
            got_len      <= 1'b0;

            dec          <= 1'b0;

            blk_sent     <= 1'b0;
            key_sent     <= 1'b0;
			   sha_sent     <= 1'b0; 

            blocks_total <= 32'd0;
            block_index  <= 32'd0;
            got_tx_done  <= 1'b0;
				trng_round <= 1'b0;
				
        end else begin
            state        <= next_state;

            got_cmd      <= got_cmd_n;
            got_flags    <= got_flags_n;
            got_len      <= got_len_n;

            blk_sent     <= blk_sent_n;
            key_sent     <= key_sent_n;
				sha_sent     <= sha_sent_n;
				trng_round   <= trng_round_n;


            blocks_total <= blocks_total_n;
            block_index  <= block_index_n;
            
				got_tx_done <= got_tx_done_n;

            // latch dec bit when flags arrive
            if (flags_ready) begin
                dec <= flags_reg[3];
            end
        end
    end

    // ============================================================
    // 2) Next-state logic
    // ============================================================
    always @(*) begin
        next_state = state;

        case (state)
            S_WAIT_HDR: begin
				    if (echo_req)
						  next_state = S_ECHO_START;
                else if (hdr_done && cmd_is_aes)
                    next_state = S_KEYEXP;
					 else if (hdr_done && cmd_is_sha)
						 next_state = S_SHA_WAIT;
					 else if (hdr_done && cmd_is_trng)
					    next_state = S_TRNG_START;
				end

				S_ECHO_START:   next_state = S_ECHO_WAIT_TX;
				
				S_ECHO_WAIT_TX: begin
					if (got_tx_done)
						next_state = S_DONE;
				end
				
				S_TRNG_START:   next_state = S_TRNG_WAIT;
				
				S_TRNG_WAIT: begin
					if (trng_done) next_state = S_TRNG_WAIT_TX;
					else           next_state = S_TRNG_WAIT;
				end
				
				S_TRNG_WAIT_TX: begin
					if (got_tx_done) begin
						if (trng_round == 1'b0)
								next_state = S_TRNG_START; // second run
						else
								next_state = S_DONE;
					end
				end
				
			   S_SHA_WAIT: begin
					if (sha_hash_valid)
						next_state = S_WAIT_TX;  
					else
						next_state = S_SHA_WAIT;
			   end
				
            S_KEYEXP: begin
                if (key_expand_ready)
                    next_state = S_BLOCKS;
            end

            S_BLOCKS: begin
                if (aes_done && last_block)
                    next_state = S_WAIT_TX;
                else
                    next_state = S_BLOCKS;
            end
				
            S_WAIT_TX: begin
                if (got_tx_done)              
                    next_state = S_DONE;
                else
                    next_state = S_WAIT_TX;
            end

            S_DONE: begin
                next_state = S_WAIT_HDR;
            end

            default: begin
                next_state = S_WAIT_HDR;
            end
        endcase
    end

    // ============================================================
    // 3) Output logic + latch updates
    // ============================================================
    always @(*) begin
        // defaults
        aes_start          = 1'b0;
        valid_in_key_aes   = 1'b0;
        valid_in_block_aes = 1'b0;
        finish_cmd_rst     = 1'b1;  
		  sha_sys_start      = 1'b0;
		  sha_valid_data     = 1'b0;
		  trng_start         = 1'b0;
		  echo_tx_start      = 1'b0;


        // hold regs by default
        got_cmd_n      = got_cmd;
        got_flags_n    = got_flags;
        got_len_n      = got_len;

        blk_sent_n     = blk_sent;
        key_sent_n     = key_sent;
		  sha_sent_n     = sha_sent;
		  trng_round_n   = trng_round;

        blocks_total_n = blocks_total;
        block_index_n  = block_index;
        got_tx_done_n  = got_tx_done;


        // -------------------------
        // header latch updates
        // -------------------------
        if (cmd_ready)
            got_cmd_n = 1'b1;

        if (flags_ready)
            got_flags_n = 1'b1;

        if (length_ready) begin
            got_len_n = 1'b1;

            // blocks_total = length_reg / 16
            blocks_total_n = length_reg;
            block_index_n  = 32'd0;
        end

        // -------------------------
        // blk_sent clear when next block starts arriving
        // (buffer makes block_ready drop to 0 at start of new block)
        // -------------------------
        if (!block_ready)
            blk_sent_n = 1'b0;
				
		  if (!sha_ready)
			   sha_sent_n = 1'b0;
		
        if (tx_done)
            got_tx_done_n = 1'b1;

        case (state)
            S_WAIT_HDR: begin
                // When header is complete and cmd is AES:
                // pulse init once and clear per-message guards.
                if (hdr_done && cmd_is_aes) begin
                    aes_start  = 1'b1;  // 1-cycle pulse (we leave this state next cycle)

                    // new message/session => clear guards
                    key_sent_n = 1'b0;
                    blk_sent_n = 1'b0;

                    // Also clear header latches on session start
                    // so next message must provide new header pulses
                    got_cmd_n   = 1'b0;
                    got_flags_n = 1'b0;
                    got_len_n   = 1'b0;
                    got_tx_done_n = 1'b0;
						  block_index_n = 32'd0;
                end
					 
					 if (hdr_done && cmd_is_sha) begin
					 	sha_sys_start     = 1'b1;          // 1-cycle pulse
					 
					 	sha_sent_n  = 1'b0;
					 
					 	got_cmd_n   = 1'b0;
					 	got_flags_n = 1'b0;
					 	got_len_n   = 1'b0;
                  got_tx_done_n = 1'b0;
						
					 end
			
					 if (hdr_done && !(cmd_is_aes || cmd_is_sha || cmd_is_trng)) begin
						 got_cmd_n   = 1'b0;
						 got_flags_n = 1'b0;
						 got_len_n   = 1'b0;
					 end
					 
					 if (hdr_done && cmd_is_trng) begin
						 trng_round_n   = 1'b0;   // first run
						 got_tx_done_n  = 1'b0;
						 got_cmd_n     = 1'b0;  
						 got_flags_n   = 1'b0;   
						 got_len_n     = 1'b0;   
					 end
					 
					 if (echo_req) begin
						 got_cmd_n      = 1'b0;
						 got_flags_n    = 1'b0;
						 got_len_n      = 1'b0;
						 got_tx_done_n  = 1'b0;
						 blk_sent_n     = 1'b0;
						 key_sent_n     = 1'b0;
						 sha_sent_n     = 1'b0;
					 end
            end

				S_ECHO_START: begin
					echo_tx_start  = 1'b1;   // tell TX to send 0x05
					got_tx_done_n  = 1'b0;   // clear the old tx_done latch
				end
				
				S_TRNG_START: begin
					trng_start = 1'b1;       // 1-cycle pulse
					got_tx_done_n = 1'b0; 
				end
				
				S_TRNG_WAIT_TX: begin
					if (got_tx_done && (trng_round == 1'b0)) begin
						trng_round_n  = 1'b1;  // move to second run
						got_tx_done_n = 1'b0;
					end
				end
				
				S_SHA_WAIT: begin
				
					if (sha_ready && !sha_sent) begin
						sha_valid_data = 1'b1;  // 1-cycle pulse to SHA top
						sha_sent_n     = 1'b1;
					end
				end

            S_KEYEXP: begin
                // Pulse look: only once when key material becomes available.
                if (have_key && !key_sent) begin
                    valid_in_key_aes = 1'b1;
                    key_sent_n        = 1'b1;
                end
            end

            S_BLOCKS: begin
                // Start a block only once per received block (blk_sent protected).
                if (block_ready && !blk_sent) begin
                    valid_in_block_aes = 1'b1;
                    blk_sent_n         = 1'b1;
                end

                // advance block counter when aes_done
                if (aes_done) begin
                    if (!last_block) begin
                        block_index_n = block_index + 32'd1;
                    end
                    // if last_block, next_state goes to DONE
                end
            end
				
				S_WAIT_TX: begin
                // nothing;
            end

            S_DONE: begin
						finish_cmd_rst = 1'b0;

            end
        endcase
    end

endmodule
