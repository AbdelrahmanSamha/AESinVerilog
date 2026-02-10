module aes_top #(
    parameter integer KEY_SIZE  = 128,
    parameter integer DOP       = 1,
    parameter integer MODE      = 5
)(
    input                     clk,
    input                     rst_n,

    input                     init,
    input                     dec,
  
	
	 input [2:0] mode_sel,
	
	
	 input valid_in_key_aes,
    input valid_in_block_aes,

    input [127:0] iv, // iv or ctr
	
    input  [KEY_SIZE-1:0]     og_key,
    input  [DOP*128-1:0]      text_in,
    input                     terminate_session,

    output [DOP*128-1:0]      text_out,
    output                    valid_dout,
	
	 
    output                    key_expand_ready,
	 
	 output [127:0] next_encstate_out,
	 output  [3:0]   round_counter_out,
	 output round_mem_we,
	 
	 input [31:0]         length_reg
	 
	 
);

    localparam integer ECB_MODE = 0;
    localparam integer CTR_MODE = 1;
    localparam integer CBC_MODE = 2;
    localparam integer CFB_MODE = 3;
    localparam integer OFB_MODE = 4;
    localparam integer VAR_MODES_MODE = 5;

    genvar i;

    // ------------------------------------------------
    // ECB-specific internal signals
    // ------------------------------------------------
    wire        cipher_start_all;
    wire [127:0] roundkey_bus;
    wire         done_m;

    // ------------------------------------------------
    // ECB generation
    // ------------------------------------------------
    generate
	 
        if (MODE == ECB_MODE) begin : GEN_ECB

            // -----------------------------
            // MAIN ECB instance (index 0)
            // -----------------------------
            aes_ecb #(
                .KEY_SIZE(KEY_SIZE),
                .IS_MAIN (1)
            ) ecb_main (
                .clk                   (clk),
                .rst_n                 (rst_n),

                .init_m                (init),
                .dec_m                 (dec),
                .og_key_m              (og_key),
                .text_in_m             (text_in[127:0]),
               //.valid_in_m            (valid_din),
                .terminate_session_m   (terminate_session),

                .text_out_m            (text_out[127:0]),
                .done_m                (done_m),
                .cipher_start_all      (cipher_start_all),
                .roundkey_m_out        (roundkey_bus),

                // unused slave ports
                .start_cipher          (1'b0),
                .dec                   (1'b0),
                .text_in               (128'b0),
                .read_roundkey_in      (128'b0),
                .text_out              (),
					 
					 //
					 
					 .key_expand_ready(key_expand_ready),
					 
					 .valid_in_key_aes(valid_in_key_aes),
					 .valid_in_block_aes(valid_in_block_aes),
					 
					 .next_encstate_out(next_encstate_out),
					 .round_counter_out(round_counter_out),
					 .round_mem_we(round_mem_we)
            );

            // -----------------------------
            // SLAVE ECB instances
            // -----------------------------
            if (DOP > 1) begin : GEN_ECB_SLAVES
                for (i = 1; i < DOP; i = i + 1) begin : ECB_SLAVE

                    aes_ecb #(
                        .KEY_SIZE(KEY_SIZE),
                        .IS_MAIN (0)
                    ) ecb_slave (
                        .clk              (clk),
                        .rst_n            (rst_n),

                        // unused main ports
                        .init_m           (1'b0),
                        .dec_m            (1'b0),
                        .og_key_m         ({KEY_SIZE{1'b0}}),
                        .text_in_m        (128'b0),
                        //.valid_in_m       (1'b0),
                        .terminate_session_m (1'b0),
								.text_out_m(),
								.done_m(),
								.cipher_start_all(),
								.roundkey_m_out(),

                        // slave ports
                        .start_cipher     (cipher_start_all),
                        .dec              (dec),
                        .text_in          (text_in[i*128 +: 128]),
                        .read_roundkey_in (roundkey_bus),

                        .text_out         (text_out[i*128 +: 128]),
								
								// 
								
								.key_expand_ready(),
								
								.valid_in_key_aes(),
								.valid_in_block_aes(),
								.next_encstate_out(),
								.round_counter_out(),
								.round_mem_we()
                    );

                end
            end

            assign valid_dout = done_m;

        end		  
		  
				else if (MODE == CTR_MODE) begin : GEN_CTR

            // -----------------------------
            // MAIN CTR instance (index 0)
            // -----------------------------
            aes_ctr #(
                .KEY_SIZE(KEY_SIZE),
                .IS_MAIN (1)
            ) ctr_main (
                .clk                   (clk),
                .rst_n                 (rst_n),

                .init_m                (init),
                .dec_m                 (dec),
                .og_key_m              (og_key),
					 
					 .counter_m             (iv),
					 
                .text_in_m             (text_in[127:0]),
                .terminate_session_m   (terminate_session),

                .text_out_m            (text_out[127:0]),
                .done_m                (done_m),
                .cipher_start_all      (cipher_start_all),
                .roundkey_m_out        (roundkey_bus),

                // unused slave ports
                .start_cipher          (1'b0),
                .dec                   (1'b0),
                .text_in               (128'b0),
                .read_roundkey_in      (128'b0),
					 
					 .counter_in    (128'b0),
					 
                .text_out              (),
					 
					 .key_expand_ready(key_expand_ready),
					 
					 .valid_in_key_aes(valid_in_key_aes),
					 .valid_in_block_aes(valid_in_block_aes),
					 
					 .next_encstate_out(next_encstate_out),
					 .round_counter_out(round_counter_out),
					 .round_mem_we(round_mem_we)
            );

            // -----------------------------
            // SLAVE ECB instances
            // -----------------------------
            if (DOP > 1) begin : GEN_CTR_SLAVES
                for (i = 1; i < DOP; i = i + 1) begin : CTR_SLAVE

                    aes_ctr #(
                        .KEY_SIZE(KEY_SIZE),
                        .IS_MAIN (0)
                    ) ctr_slave (
                        .clk              (clk),
                        .rst_n            (rst_n),

                        // unused main ports
                        .init_m           (1'b0),
                        .dec_m            (1'b0),
                        .og_key_m         ({KEY_SIZE{1'b0}}),
                        .text_in_m        (128'b0),
                        .terminate_session_m (1'b0),
								
								.counter_m  (128'b0),
								
								.text_out_m(),
								.done_m(),
								.cipher_start_all(),
								.roundkey_m_out(),

                        // slave ports
                        .start_cipher     (cipher_start_all),
                        .dec              (dec),
                        .text_in          (text_in[i*128 +: 128]),
                        .read_roundkey_in (roundkey_bus),
				
								.counter_in    (128'b0),   // will be modified later for now its ok cuz the dop always  1 
      
								.text_out         (text_out[i*128 +: 128]),

								.key_expand_ready(),
					 
								.valid_in_key_aes(),
								.valid_in_block_aes(),
					 
								.next_encstate_out(),
								.round_counter_out(),
								.round_mem_we()
		
                    );

                end
            end

            assign valid_dout = done_m;

        end
		  
		  		else if (MODE == CBC_MODE) begin : GEN_CBC 
	  
            // -----------------------------
            // MAIN CBC instance (index 0)
            // -----------------------------
            aes_cbc #(
                .KEY_SIZE(KEY_SIZE)
            ) cbc_main (
                .clk                   (clk),
                .rst_n                 (rst_n),

                .init                  (init),
                .dec                   (dec),
                .og_key                (og_key),
                .text_in               (text_in[127:0]),
                .terminate_session     (terminate_session),
					 
					 .iv							(iv),

                .text_out              (text_out[127:0]),
                .done            		(done_m),
					 
					 .valid_in_key_aes   (valid_in_key_aes),
					 .valid_in_block_aes (valid_in_block_aes),
					 
					 .key_expand_ready   (key_expand_ready),
       
					 .next_encstate_out  (next_encstate_out),
					 .round_counter_out  (round_counter_out),
					 .round_mem_we       (round_mem_we)
					 
            );

            assign valid_dout = done_m;

        end
		  
		  
			else if (MODE == CFB_MODE) begin : GEN_CFB
			
				// -----------------------------
				// MAIN CFB instance (index 0)
				// -----------------------------
				aes_cfb #(
					.KEY_SIZE(KEY_SIZE)
				) cfb_main (
					.clk               (clk),
					.rst_n              (rst_n),
			
					.init              (init),
					.dec               (dec),              // used only for chaining rule inside aes_cfb
					.og_key            (og_key),
					.iv                (iv),
			
					.text_in           (text_in),
					.terminate_session (terminate_session),
			
					.valid_in_key_aes   (valid_in_key_aes),
					.valid_in_block_aes (valid_in_block_aes),
			
					.text_out          (text_out),
					.done              (done_m),
			
					.key_expand_ready  (key_expand_ready),
			
					.next_encstate_out (next_encstate_out),
					.round_counter_out (round_counter_out),
					.round_mem_we      (round_mem_we)
				);
			
				assign valid_dout = done_m;
			
				end



			else if (MODE == OFB_MODE) begin : GEN_OFB

				// -----------------------------
				// MAIN OFB instance (index 0)
				// -----------------------------
				
				aes_ofb #(
					.KEY_SIZE(KEY_SIZE)
				) ofb_main (
					.clk               (clk),
					.rst_n              (rst_n),
			
					.init              (init),
					.dec               (dec),              // unused inside aes_ofb (kept for compatibility)
					.og_key            (og_key),
					.iv                (iv),
			
					.text_in           (text_in),          // if DOP>1 later: use text_in[127:0]
					.terminate_session (terminate_session),
			
					.valid_in_key_aes   (valid_in_key_aes),
					.valid_in_block_aes (valid_in_block_aes),
			
					.text_out          (text_out),
					.done              (done_m),
			
					.key_expand_ready  (key_expand_ready),
			
					.next_encstate_out (next_encstate_out),
					.round_counter_out (round_counter_out),
					.round_mem_we      (round_mem_we)
				);
			
				assign valid_dout = done_m;
			

			end
		  
		  else if (MODE == VAR_MODES_MODE) begin : GEN_VAR_MODES
		  
		  
		  
		// ============================================================
		// VAR_MODES_MODE internal wires (one set per mode)
		// ============================================================
		
		// -------- text_out per mode --------
		wire [127:0] text_out_ecb;
		wire [127:0] text_out_ctr;
		wire [127:0] text_out_cbc;
		wire [127:0] text_out_cfb;
		wire [127:0] text_out_ofb;
		
		// -------- done/valid per mode --------
		wire done_m_ecb;
		wire done_m_ctr;
		wire done_m_cbc;
		wire done_m_cfb;
		wire done_m_ofb;
		
		// -------- key_expand_ready per mode --------
		wire key_expand_ready_ecb;
		wire key_expand_ready_ctr;
		wire key_expand_ready_cbc;
		wire key_expand_ready_cfb;
		wire key_expand_ready_ofb;
		
		// -------- debug per mode --------
		wire [127:0] next_encstate_out_ecb;
		wire [127:0] next_encstate_out_ctr;
		wire [127:0] next_encstate_out_cbc;
		wire [127:0] next_encstate_out_cfb;
		wire [127:0] next_encstate_out_ofb;
		
		wire [3:0]   round_counter_out_ecb;
		wire [3:0]   round_counter_out_ctr;
		wire [3:0]   round_counter_out_cbc;
		wire [3:0]   round_counter_out_cfb;
		wire [3:0]   round_counter_out_ofb;
		
		wire round_mem_we_ecb;
		wire round_mem_we_ctr;
		wire round_mem_we_cbc;
		wire round_mem_we_cfb;
		wire round_mem_we_ofb;
		

// ============================================================
// Final selected outputs (VAR_MODES_MODE)
// ============================================================
		reg  [127:0] 		 text_out_sel;
		reg                valid_dout_sel;
		reg                key_expand_ready_sel;
		reg  [127:0]       next_encstate_sel;
		reg  [3:0]         round_counter_sel;
		reg                round_mem_we_sel;
		
		always @(*) begin
			// defaults (safe)
			text_out_sel         = 128'b0;
			valid_dout_sel       = 1'b0;
			key_expand_ready_sel = 1'b0;
			next_encstate_sel    = 128'b0;
			round_counter_sel    = 4'b0;
			round_mem_we_sel     = 1'b0;
	 
    case (mode_sel)
        3'd0: begin // ECB
            text_out_sel         = text_out_ecb;
            valid_dout_sel       = done_m_ecb;
            key_expand_ready_sel = key_expand_ready_ecb;
            next_encstate_sel    = next_encstate_out_ecb;
            round_counter_sel    = round_counter_out_ecb;
            round_mem_we_sel     = round_mem_we_ecb;
        end

        3'd1: begin // CTR
            text_out_sel         = text_out_ctr;
            valid_dout_sel       = done_m_ctr;
            key_expand_ready_sel = key_expand_ready_ctr;
            next_encstate_sel    = next_encstate_out_ctr;
            round_counter_sel    = round_counter_out_ctr;
            round_mem_we_sel     = round_mem_we_ctr;
        end

        3'd2: begin // CBC
            text_out_sel         = text_out_cbc;
            valid_dout_sel       = done_m_cbc;
            key_expand_ready_sel = key_expand_ready_cbc;
            next_encstate_sel    = next_encstate_out_cbc;
            round_counter_sel    = round_counter_out_cbc;
            round_mem_we_sel     = round_mem_we_cbc;
        end

        3'd3: begin // CFB
            text_out_sel         = text_out_cfb;
            valid_dout_sel       = done_m_cfb;
            key_expand_ready_sel = key_expand_ready_cfb;
            next_encstate_sel    = next_encstate_out_cfb;
            round_counter_sel    = round_counter_out_cfb;
            round_mem_we_sel     = round_mem_we_cfb;
        end

        3'd4: begin // OFB
            text_out_sel         = text_out_ofb;
            valid_dout_sel       = done_m_ofb;
            key_expand_ready_sel = key_expand_ready_ofb;
            next_encstate_sel    = next_encstate_out_ofb;
            round_counter_sel    = round_counter_out_ofb;
            round_mem_we_sel     = round_mem_we_ofb;
        end

        default: begin
            // defaults = zeros
        end
    endcase
end


            // -----------------------------
            // MAIN ECB instance (index 0)
            // -----------------------------
            aes_ecb #(
                .KEY_SIZE(KEY_SIZE),
                .IS_MAIN (1)
            ) ecb_main (
                .clk                   (clk),
                .rst_n                 (rst_n),

                .init_m                (init && (mode_sel== 3'b000)),
                .dec_m                 (dec),
                .og_key_m              (og_key),
                .text_in_m             (text_in),
                .terminate_session_m   (terminate_session),

                .text_out_m            (text_out_ecb),
                .done_m                (done_m_ecb),
                .cipher_start_all      (),
                .roundkey_m_out        (),

                // unused slave ports
                .start_cipher          (1'b0),
                .dec                   (1'b0),
                .text_in               (128'b0),
                .read_roundkey_in      (128'b0),
                .text_out              (),
					 
					 //
					 
					 .key_expand_ready(key_expand_ready_ecb),
					 
					 .valid_in_key_aes(valid_in_key_aes),
					 .valid_in_block_aes(valid_in_block_aes),
					 
					 .next_encstate_out(next_encstate_out_ecb),
					 .round_counter_out(round_counter_out_ecb),
					 .round_mem_we(round_mem_we_ecb)
            );
				
            // -----------------------------
            // MAIN CTR instance (index 0)
            // -----------------------------
				
				 aes_ctr #(
                .KEY_SIZE(KEY_SIZE),
                .IS_MAIN (1)
            ) ctr_main (
                .clk                   (clk),
                .rst_n                 (rst_n),

                .init_m                (init  && (mode_sel== 3'b001)),
                .dec_m                 (dec),
                .og_key_m              (og_key),
					 
					 .counter_m             (iv),
					 
                .text_in_m             (text_in),
                .terminate_session_m   (terminate_session),

                .text_out_m            (text_out_ctr),
                .done_m                (done_m_ctr),
                .cipher_start_all      (),
                .roundkey_m_out        (),

                // unused slave ports
                .start_cipher          (1'b0),
                .dec                   (1'b0),
                .text_in               (128'b0),
                .read_roundkey_in      (128'b0),
					 
					 .counter_in    (128'b0),
					 
                .text_out              (),
					 
					 .key_expand_ready(key_expand_ready_ctr),
					 
					 .valid_in_key_aes(valid_in_key_aes),
					 .valid_in_block_aes(valid_in_block_aes),
					 
					 .next_encstate_out(next_encstate_out_ctr),
					 .round_counter_out(round_counter_out_ctr),
					 .round_mem_we(round_mem_we_ctr)
            );


					  
            // -----------------------------
            // MAIN CBC instance (index 0)
            // -----------------------------
            aes_cbc #(
                .KEY_SIZE(KEY_SIZE)
            ) cbc_main (
                .clk                   (clk),
                .rst_n                 (rst_n),

                .init                  (init && (mode_sel== 3'b010)),
                .dec                   (dec),
                .og_key                (og_key),
                .text_in               (text_in),
                .terminate_session     (terminate_session),
					 
					 .iv							(iv),

                .text_out              (text_out_cbc),
                .done            		(done_m_cbc),
					 
					 .valid_in_key_aes   (valid_in_key_aes),
					 .valid_in_block_aes (valid_in_block_aes),
					 
					 .key_expand_ready   (key_expand_ready_cbc),
       
					 .next_encstate_out  (next_encstate_out_cbc),
					 .round_counter_out  (round_counter_out_cbc),
					 .round_mem_we       (round_mem_we_cbc)
					 
            );


        				// -----------------------------
				// MAIN CFB instance (index 0)
				// -----------------------------
				aes_cfb #(
					.KEY_SIZE(KEY_SIZE)
				) cfb_main (
					.clk               (clk),
					.rst_n              (rst_n),
			
					.init              (init && (mode_sel== 3'b011)),
					.dec               (dec),              // used only for chaining rule inside aes_cfb
					.og_key            (og_key),
					.iv                (iv),
			
					.text_in           (text_in),
					.terminate_session (terminate_session),
			
					.valid_in_key_aes   (valid_in_key_aes),
					.valid_in_block_aes (valid_in_block_aes),
			
					.text_out          (text_out_cfb),
					.done              (done_m_cfb),
			
					.key_expand_ready  (key_expand_ready_cfb),
			
					.next_encstate_out (next_encstate_out_cfb),
					.round_counter_out (round_counter_out_cfb),
					.round_mem_we      (round_mem_we_cfb)
				);
			

				// -----------------------------
				// MAIN OFB instance (index 0)
				// -----------------------------
				
				aes_ofb #(
					.KEY_SIZE(KEY_SIZE)
				) ofb_main (
					.clk               (clk),
					.rst_n              (rst_n),
			
					.init              (init && (mode_sel== 3'b100)),
					.dec               (dec),              // unused inside aes_ofb (kept for compatibility)
					.og_key            (og_key),
					.iv                (iv),
			
					.text_in           (text_in),          // if DOP>1 later: use text_in[127:0]
					.terminate_session (terminate_session),
			
					.valid_in_key_aes   (valid_in_key_aes),
					.valid_in_block_aes (valid_in_block_aes),
			
					.text_out          (text_out_ofb),
					.done              (done_m_ofb),
			
					.key_expand_ready  (key_expand_ready_ofb),
			
					.next_encstate_out (next_encstate_out_ofb),
					.round_counter_out (round_counter_out_ofb),
					.round_mem_we      (round_mem_we_ofb)
				);
			

				assign text_out            = text_out_sel;
				assign valid_dout          = valid_dout_sel;
				assign key_expand_ready    = key_expand_ready_sel;
				assign next_encstate_out   = next_encstate_sel;
				assign round_counter_out   = round_counter_sel;
				assign round_mem_we        = round_mem_we_sel;


        end	
		  
		  endgenerate
endmodule