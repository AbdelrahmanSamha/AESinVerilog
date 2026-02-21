module aes_top #(
    parameter integer KEY_SIZE  = 256,
    parameter integer DOP       = 1,
    parameter integer MODE      = 0,
    parameter integer FIXED_VARKEY_MODE = 0 
)(
    input                     clk,
    input                     rst_n,

    input                     init,
    input                     dec,
  
	
	 input [2:0] mode_sel,
	 input [1:0] key_size_sel,
	
	
	 input valid_in_key_aes,
    input valid_in_block_aes,

    input [127:0] iv, // iv or ctr
	
    input  [KEY_SIZE-1:0]     og_key,
    input  [127:0]      text_in,
    input                     terminate_session,

    output [127:0]      text_out,
    output                    valid_dout,
	
	 
    output                    key_expand_ready,
	 
	 output [127:0] next_encstate_out,
	 output  [3:0]   round_counter_out,
	 output round_mem_we
	  
);

    localparam integer ECB_MODE = 0;
    localparam integer CTR_MODE = 1;
    localparam integer CBC_MODE = 2;
    localparam integer CFB_MODE = 3;
    localparam integer OFB_MODE = 4; 
    localparam integer VAR_MODES_MODE = 5;  
    localparam integer VAR_KEYS_MODE = 6;  
	 localparam integer VAR_FULL_MODE = 7; 

    genvar i;
	 
	 
	 wire dec_aes_core;
    assign dec_aes_core = dec && ((mode_sel == 3'd0) || (mode_sel == 3'd2));

	 
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
					 .key_sel               (key_size_sel), 

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
				         	.key_sel               (key_size_sel), 

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
					 
					 .key_sel               (key_size_sel), 

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

					         .key_sel               (key_size_sel), 
					 
                        // slave ports
                        .start_cipher     (cipher_start_all),
                        .dec              (dec),
                        .text_in          (text_in[i*128 +: 128]),
                        .read_roundkey_in (roundkey_bus),
				
								.counter_in    (128'b0),   
      
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
					 
					 .key_sel               (key_size_sel), 
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
					.key_sel               (key_size_sel), 
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
					
					.key_sel               (key_size_sel), 
			
					.key_expand_ready  (key_expand_ready),
			
					.next_encstate_out (next_encstate_out),
					.round_counter_out (round_counter_out),
					.round_mem_we      (round_mem_we)
				);
			
				assign valid_dout = done_m;
			

			end
			

	
		  
		  else if (MODE == VAR_MODES_MODE) begin : GEN_VAR_MODES

            // --------------------------------------------------------
            // Per-mode final outputs (controller-side)
            // --------------------------------------------------------
            wire [127:0] text_out_ecb, text_out_ctr, text_out_cbc, text_out_cfb, text_out_ofb;
            wire         done_ecb,     done_ctr,     done_cbc,     done_cfb,     done_ofb;
            wire         keyr_ecb,     keyr_ctr,     keyr_cbc,     keyr_cfb,     keyr_ofb;

            // --------------------------------------------------------
            // Per-mode control outputs (controller -> shared datapath)
            // --------------------------------------------------------
            wire         cipher_start_ecb, cipher_start_ctr, cipher_start_cbc, cipher_start_cfb, cipher_start_ofb;
            wire [127:0] aes_in_block_ecb, aes_in_block_ctr, aes_in_block_cbc, aes_in_block_cfb, aes_in_block_ofb;
            wire         key_exp_start_ecb, key_exp_start_ctr, key_exp_start_cbc, key_exp_start_cfb, key_exp_start_ofb;
            wire         mem_key_rw_ecb,    mem_key_rw_ctr,    mem_key_rw_cbc,    mem_key_rw_cfb,    mem_key_rw_ofb;

            // --------------------------------------------------------
            // Shared datapath signals (ONE set)
            // --------------------------------------------------------
            wire         cipher_start;
            wire [127:0] aes_in_block;
            wire [127:0] aes_raw_out;
            wire         block_done;

            wire         key_exp_start;
            wire         key_expand_finish;

            wire         mem_key_rw;

            wire [3:0]   read_key_address;
            wire [3:0]   write_key_address;
            wire [4:0]   key_address;

            wire         mem_round_key_en;
            wire [127:0] gen_roundkey;
            wire [127:0] roundkey_out;

            // --------------------------------------------------------
            // Controller->datapath selection MUX
            // --------------------------------------------------------
            reg         cipher_start_sel;
            reg [127:0] aes_in_block_sel;
            reg         key_exp_start_sel;
            reg         mem_key_rw_sel;
				
				reg [127:0] text_out_sel;
				reg         valid_dout_sel;
				reg         keyr_sel;

            always @(*) begin
                cipher_start_sel  = 1'b0;
                aes_in_block_sel  = 128'b0;
                key_exp_start_sel = 1'b0;
                mem_key_rw_sel    = 1'b0;

                case (mode_sel)
                    3'd0: begin // ECB
                        cipher_start_sel  = cipher_start_ecb;
                        aes_in_block_sel  = aes_in_block_ecb;
                        key_exp_start_sel = key_exp_start_ecb;
                        mem_key_rw_sel    = mem_key_rw_ecb;
                    end
                    3'd1: begin // CTR
                        cipher_start_sel  = cipher_start_ctr;
                        aes_in_block_sel  = aes_in_block_ctr;
                        key_exp_start_sel = key_exp_start_ctr;
                        mem_key_rw_sel    = mem_key_rw_ctr;
                    end
                    3'd2: begin // CBC
                        cipher_start_sel  = cipher_start_cbc;
                        aes_in_block_sel  = aes_in_block_cbc;
                        key_exp_start_sel = key_exp_start_cbc;
                        mem_key_rw_sel    = mem_key_rw_cbc;
                    end
                    3'd3: begin // CFB
                        cipher_start_sel  = cipher_start_cfb;
                        aes_in_block_sel  = aes_in_block_cfb;
                        key_exp_start_sel = key_exp_start_cfb;
                        mem_key_rw_sel    = mem_key_rw_cfb;
                    end
                    3'd4: begin // OFB
                        cipher_start_sel  = cipher_start_ofb;
                        aes_in_block_sel  = aes_in_block_ofb;
                        key_exp_start_sel = key_exp_start_ofb;
                        mem_key_rw_sel    = mem_key_rw_ofb;
                    end
                    default: begin end
                endcase
            end

            assign cipher_start  = cipher_start_sel;
            assign aes_in_block  = aes_in_block_sel;
            assign key_exp_start = key_exp_start_sel;
            assign mem_key_rw    = mem_key_rw_sel;

			
    // ============================================================
    // Block Encrypt (shared datapath )
    // ============================================================
            block_encrypt BE (
                .clk           (clk),
                .rst_n         (rst_n),
                .start         (cipher_start),
                .dec           (dec_aes_core),
                .plaintext     (aes_in_block),
                .roundkey      (roundkey_out),
                .ciphertext    (aes_raw_out),
                .key_address   (read_key_address),
                .done          (block_done),
					 .key_sel               (key_size_sel), 


                .next_encstate (next_encstate_out),
                .round_counter (round_counter_out),
                .round_mem_we  (round_mem_we)
            );
    // ============================================================
    // Key Expansion (shared)
    // ============================================================
            aes_keyexpand #(KEY_SIZE) KEYEXP (
                .clk           (clk),
                .rst_n         (rst_n),
                .init          (key_exp_start),
                .og_key        (og_key),
                .store_key_mem (mem_round_key_en),
                .address       (write_key_address),
                .round_key     (gen_roundkey),
                .finish        (key_expand_finish)
            );

    // ============================================================
    // Round-key memory (shared)
    // ============================================================
            mem_round_keys KEYMEM (
                .clock   (clk),
                .address (key_address),
                .data    (gen_roundkey),
                .wren    (mem_round_key_en),
                .q       (roundkey_out)
            );

    // ============================================================
    // Address mux (read during cipher, write during keyexp)
    // ============================================================
            mux2to1 #(4) ADDR_MUX (
                .in0 (read_key_address),
                .in1 (write_key_address),
                .sel (mem_key_rw),
                .out (key_address[3:0])
            );
            assign key_address[4] = 1'b0;
	

			// -----------------------------
			// MAIN ECB instance
			// -----------------------------
			aes_ecb_var ECB_CTRL (
				.clk               (clk),
				.rst_n              (rst_n),
			
				.init_m             (init),
				.dec_m              (dec),
			
				.text_in_m          (text_in),
				.terminate_session_m(terminate_session),
			
				// outputs with _ecb
				.text_out_m         (text_out_ecb),
				.done_m             (done_ecb),
			
				.key_expand_ready   (keyr_ecb),
			
				.valid_in_key_aes   (valid_in_key_aes),
				.valid_in_block_aes (valid_in_block_aes),
			
				// BE handshake/data (outputs)
				.cipher_start      (cipher_start_ecb),
				.aes_in_block      (aes_in_block_ecb),
				.aes_raw_out       (aes_raw_out),
				.block_done        (block_done),
			
				// Keyexp handshake (outputs)
				.key_exp_start      (key_exp_start_ecb),
				.key_expand_finish  (key_expand_finish),
			
				// mem mux select (output)
				.mem_key_rw         (mem_key_rw_ecb)
			);
			
				
            // -----------------------------
            // MAIN CTR instance 
            // -----------------------------

			aes_ctr_var CTR_CTRL (
				.clk                 (clk),
				.rst_n               (rst_n),
			

				.init_m              (init),
				.dec               (dec),
				.text_in           (text_in),
				.text_out            (text_out_ctr),
				
				.terminate_session_m (terminate_session),
				.counter_m           (iv),


				.key_expand_ready    (keyr_ctr),
			

				.valid_in_key_aes    (valid_in_key_aes),
				.valid_in_block_aes  (valid_in_block_aes),
			
				// -----------------------------
				// Shared datapath interface
				// -----------------------------

				.cipher_start        (cipher_start_ctr),
				.aes_in_block        (aes_in_block_ctr),
				.key_exp_start       (key_exp_start_ctr),
				.mem_key_rw          (mem_key_rw_ctr),

				.aes_raw_out         (aes_raw_out),
				.block_done          (block_done),
				.key_expand_finish   (key_expand_finish),
				
				.done_m              (done_ctr)
			);
			
				

			// -----------------------------
			// MAIN CBC instance 
			// -----------------------------
			aes_cbc_var CBC_CTRL (
				.clk               (clk),
				.rst_n              (rst_n),
			
				.init              (init),
				.dec               (dec),
				.iv                (iv),
			
				.text_in           (text_in),
				.terminate_session (terminate_session),
			
				.valid_in_key_aes   (valid_in_key_aes),
				.valid_in_block_aes (valid_in_block_aes),
			
				// outputs with _cbc
				.text_out          (text_out_cbc),
				.done              (done_cbc),
			
				.key_expand_ready  (keyr_cbc),
			
				// BE handshake/data (outputs)
				.cipher_start      (cipher_start_cbc),
				.aes_in_block      (aes_in_block_cbc),
				.aes_raw_out       (aes_raw_out),
				.block_done        (block_done),
			
				// Keyexp handshake (outputs)
				.key_exp_start     (key_exp_start_cbc),
				.key_expand_finish (key_expand_finish),
			
			
				// mem mux select (output)
				.mem_key_rw        (mem_key_rw_cbc)
			);
			
	
			// -----------------------------
			// MAIN CFB instance
			// -----------------------------
			aes_cfb_var CFB_CTRL (
				.clk               (clk),
				.rst_n              (rst_n),
			
				.init              (init),
				.dec               (dec),
				.iv                (iv),
			
				.text_in           (text_in),
				.terminate_session (terminate_session),
			
				.valid_in_key_aes   (valid_in_key_aes),
				.valid_in_block_aes (valid_in_block_aes),
			
				// outputs with _cfb
				.text_out          (text_out_cfb),
				.done              (done_cfb),
				.key_expand_ready  (keyr_cfb),
			
				// BE handshake/data
				.cipher_start      (cipher_start_cfb),
				.aes_in_block      (aes_in_block_cfb),
				.aes_raw_out       (aes_raw_out),
				.block_done        (block_done),
			
				// Keyexp handshake
				.key_exp_start     (key_exp_start_cfb),
				.key_expand_finish (key_expand_finish),
			
				// mem mux select
				.mem_key_rw        (mem_key_rw_cfb)
			);
			
				
				// -----------------------------
				// MAIN OFB instance 
				// -----------------------------
				// -----------------------------
			// MAIN OFB instance
			// -----------------------------
			aes_ofb_var OFB_CTRL (
				.clk               (clk),
				.rst_n              (rst_n),
			
				.init              (init),
				.dec               (dec),
				.iv                (iv),
			
				.text_in           (text_in),
				.terminate_session (terminate_session),
			
				.valid_in_key_aes   (valid_in_key_aes),
				.valid_in_block_aes (valid_in_block_aes),
			
				// outputs with _ofb
				.text_out          (text_out_ofb),
				.done              (done_ofb),
				.key_expand_ready  (keyr_ofb),
			
				// BE handshake/data
				.cipher_start      (cipher_start_ofb),
				.aes_in_block      (aes_in_block_ofb),
				.aes_raw_out       (aes_raw_out),
				.block_done        (block_done),
			
				// Keyexp handshake
				.key_exp_start     (key_exp_start_ofb),
				.key_expand_finish (key_expand_finish),
			
				// mem mux select
				.mem_key_rw        (mem_key_rw_ofb)
			);
			
            always @(*) begin
                text_out_sel   = 128'b0;
                valid_dout_sel = 1'b0;
                keyr_sel       = 1'b0;

                case (mode_sel)
                    3'd0: begin text_out_sel = text_out_ecb; valid_dout_sel = done_ecb; keyr_sel = keyr_ecb; end
                    3'd1: begin text_out_sel = text_out_ctr; valid_dout_sel = done_ctr; keyr_sel = keyr_ctr; end
                    3'd2: begin text_out_sel = text_out_cbc; valid_dout_sel = done_cbc; keyr_sel = keyr_cbc; end
                    3'd3: begin text_out_sel = text_out_cfb; valid_dout_sel = done_cfb; keyr_sel = keyr_cfb; end
                    3'd4: begin text_out_sel = text_out_ofb; valid_dout_sel = done_ofb; keyr_sel = keyr_ofb; end
                    default: begin end
                endcase
            end

            // DOP currently treated as 1 in VAR_MODES_MODE
            assign text_out         =  text_out_sel;
            assign valid_dout       = valid_dout_sel;
            assign key_expand_ready = keyr_sel;

			

        end	
		  

		  
else if (MODE == VAR_KEYS_MODE) begin : GEN_VAR_KEYS

    // ============================================================
    // Runtime key-size select
    // ============================================================
    localparam [1:0] KS_128 = 2'd0;
    localparam [1:0] KS_192 = 2'd1;
    localparam [1:0] KS_256 = 2'd2;

    // ============================================================
    // Controller <-> datapath wires (from the fixed-mode controller)
    // ============================================================
    wire         cipher_start_ctrl;
    wire [127:0] aes_in_block_ctrl;
    wire         key_exp_start_ctrl;
    wire         mem_key_rw_ctrl;

    // ============================================================
    // Final outputs from the fixed-mode controller
    // ============================================================
    wire [127:0] text_out_fixed;
    wire         done_fixed;
    wire         keyr_fixed;

    // ============================================================
    // SINGLE DATAPATH WIRES (selected at runtime)
    // ============================================================
    wire [127:0] aes_raw_out_1;
    wire         block_done_1;

    wire [3:0]   read_key_address_1;
    wire [3:0]   write_key_address_1;
    wire [4:0]   key_address_1;

    wire         mem_round_key_en_1;
    wire [127:0] gen_roundkey_1;
    wire [127:0] roundkey_out_1;

    wire [127:0] next_encstate_1;
    wire [3:0]   round_counter_1;
    wire         round_mem_we_1;

    // Debug outputs (no debug mux anymore)
    assign next_encstate_out = next_encstate_1;
    assign round_counter_out = round_counter_1;
    assign round_mem_we      = round_mem_we_1;

    // ============================================================
    // KEEP 3 KEYEXP modules, but select their write signals
    // ============================================================
    wire         mem_round_key_en_128, mem_round_key_en_192, mem_round_key_en_256;
    wire [3:0]   write_key_address_128, write_key_address_192, write_key_address_256;
    wire [127:0] gen_roundkey_128, gen_roundkey_192, gen_roundkey_256;
    wire         key_expand_finish_128, key_expand_finish_192, key_expand_finish_256;

    aes_keyexpand #(128) KEYEXP_128 (
        .clk           (clk),
        .rst_n         (rst_n),
        .init          (key_exp_start_ctrl),
        .og_key        (og_key[127:0]),
        .store_key_mem (mem_round_key_en_128),
        .address       (write_key_address_128),
        .round_key     (gen_roundkey_128),
        .finish        (key_expand_finish_128)
    );

    aes_keyexpand #(192) KEYEXP_192 (
        .clk           (clk),
        .rst_n         (rst_n),
        .init          (key_exp_start_ctrl),
        .og_key        (og_key[191:0]),
        .store_key_mem (mem_round_key_en_192),
        .address       (write_key_address_192),
        .round_key     (gen_roundkey_192),
        .finish        (key_expand_finish_192)
    );

    aes_keyexpand #(256) KEYEXP_256 (
        .clk           (clk),
        .rst_n         (rst_n),
        .init          (key_exp_start_ctrl),
        .og_key        (og_key[255:0]),
        .store_key_mem (mem_round_key_en_256),
        .address       (write_key_address_256),
        .round_key     (gen_roundkey_256),
        .finish        (key_expand_finish_256)
    );

    // ============================================================
    // Key-size select mux for KEYEXP -> KEYMEM write interface
    // ============================================================
    reg         mem_round_key_en_sel;
    reg [3:0]   write_key_address_sel;
    reg [127:0] gen_roundkey_sel;
    reg         key_expand_finish_sel;

    always @(*) begin
        // default = 128
        mem_round_key_en_sel  = mem_round_key_en_128;
        write_key_address_sel = write_key_address_128;
        gen_roundkey_sel      = gen_roundkey_128;
        key_expand_finish_sel = key_expand_finish_128;

        case (key_size_sel)
            KS_128: begin
                mem_round_key_en_sel  = mem_round_key_en_128;
                write_key_address_sel = write_key_address_128;
                gen_roundkey_sel      = gen_roundkey_128;
                key_expand_finish_sel = key_expand_finish_128;
            end
            KS_192: begin
                mem_round_key_en_sel  = mem_round_key_en_192;
                write_key_address_sel = write_key_address_192;
                gen_roundkey_sel      = gen_roundkey_192;
                key_expand_finish_sel = key_expand_finish_192;
            end
            default: begin // KS_256
                mem_round_key_en_sel  = mem_round_key_en_256;
                write_key_address_sel = write_key_address_256;
                gen_roundkey_sel      = gen_roundkey_256;
                key_expand_finish_sel = key_expand_finish_256;
            end
        endcase
    end

    assign mem_round_key_en_1  = mem_round_key_en_sel;
    assign write_key_address_1 = write_key_address_sel;
    assign gen_roundkey_1      = gen_roundkey_sel;

    // ============================================================
    // SINGLE KEY MEMORY
    // IMPORTANT: depth must support AES-256 (addr 0..14), depth 16 ideal
    // ============================================================
    mem_round_keys KEYMEM_1 (
        .clock   (clk),
        .address (key_address_1),
        .data    (gen_roundkey_1),
        .wren    (mem_round_key_en_1),
        .q       (roundkey_out_1)
    );

    // Address mux: read from BE vs write from KEYEXP
    mux2to1 #(4) ADDR_MUX_1 (
        .in0 (read_key_address_1),
        .in1 (write_key_address_1),
        .sel (mem_key_rw_ctrl),
        .out (key_address_1[3:0])
    );
    assign key_address_1[4] = 1'b0;

    // ============================================================
    // SINGLE BLOCK ENCRYPT (runtime key_sel)  <<< MAIN CHANGE
    // ============================================================
    block_encrypt BE_1 (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (cipher_start_ctrl),
        .dec           (dec_aes_core),
        .plaintext     (aes_in_block_ctrl),
        .roundkey      (roundkey_out_1),
        .key_sel       (key_size_sel),      // <<< ADDED (runtime key size)
        .ciphertext    (aes_raw_out_1),
        .key_address   (read_key_address_1),
        .done          (block_done_1),
        .next_encstate (next_encstate_1),
        .round_counter (round_counter_1),
        .round_mem_we  (round_mem_we_1)
    );

    // Feedback to controller (selected datapath is now single)
    wire [127:0] aes_raw_out_sel       = aes_raw_out_1;
    wire         block_done_sel        = block_done_1;
    wire         key_expand_finish_sel_w = key_expand_finish_sel;

    // ============================================================
    // FIXED MODE (compile-time) controller generation
    // Only ONE controller is synthesized.
    // ============================================================
    begin : GEN_FIXED_CTRL
        if (FIXED_VARKEY_MODE == ECB_MODE) begin : GEN_FIXED_ECB_VARKEY
            aes_ecb_var CTRL (
                .clk                (clk),
                .rst_n              (rst_n),
                .init_m             (init),
                .dec_m              (dec),
                .text_in_m          (text_in),
                .terminate_session_m(terminate_session),
                .text_out_m         (text_out_fixed[127:0]),
                .done_m             (done_fixed),
                .key_expand_ready   (keyr_fixed),
                .valid_in_key_aes   (valid_in_key_aes),
                .valid_in_block_aes (valid_in_block_aes),
                .cipher_start       (cipher_start_ctrl),
                .aes_in_block       (aes_in_block_ctrl),
                .aes_raw_out        (aes_raw_out_sel),
                .block_done         (block_done_sel),
                .key_exp_start      (key_exp_start_ctrl),
                .key_expand_finish  (key_expand_finish_sel_w),
                .mem_key_rw         (mem_key_rw_ctrl)
            );
        end
        else if (FIXED_VARKEY_MODE == CTR_MODE) begin : GEN_FIXED_CTR_VARKEY
            aes_ctr_var CTRL (
                .clk                (clk),
                .rst_n              (rst_n),
                .init_m             (init),
                .dec                (dec),
                .text_in            (text_in),
                .text_out           (text_out_fixed[127:0]),
                .terminate_session_m(terminate_session),
                .counter_m          (iv),
                .key_expand_ready   (keyr_fixed),
                .valid_in_key_aes   (valid_in_key_aes),
                .valid_in_block_aes (valid_in_block_aes),
                .cipher_start       (cipher_start_ctrl),
                .aes_in_block       (aes_in_block_ctrl),
                .key_exp_start      (key_exp_start_ctrl),
                .mem_key_rw         (mem_key_rw_ctrl),
                .aes_raw_out        (aes_raw_out_sel),
                .block_done         (block_done_sel),
                .key_expand_finish  (key_expand_finish_sel_w),
                .done_m             (done_fixed)
            );
        end
        else if (FIXED_VARKEY_MODE == CBC_MODE) begin : GEN_FIXED_CBC_VARKEY
            aes_cbc_var CTRL (
                .clk               (clk),
                .rst_n             (rst_n),
                .init              (init),
                .dec               (dec),
                .iv                (iv),
                .text_in           (text_in),
                .terminate_session (terminate_session),
                .valid_in_key_aes   (valid_in_key_aes),
                .valid_in_block_aes (valid_in_block_aes),
                .text_out          (text_out_fixed[127:0]),
                .done              (done_fixed),
                .key_expand_ready  (keyr_fixed),
                .cipher_start      (cipher_start_ctrl),
                .aes_in_block      (aes_in_block_ctrl),
                .aes_raw_out       (aes_raw_out_sel),
                .block_done        (block_done_sel),
                .key_exp_start     (key_exp_start_ctrl),
                .key_expand_finish (key_expand_finish_sel_w),
                .mem_key_rw        (mem_key_rw_ctrl)
            );
        end
        else if (FIXED_VARKEY_MODE == CFB_MODE) begin : GEN_FIXED_CFB_VARKEY
            aes_cfb_var CTRL (
                .clk               (clk),
                .rst_n             (rst_n),
                .init              (init),
                .dec               (dec),
                .iv                (iv),
                .text_in           (text_in),
                .terminate_session (terminate_session),
                .valid_in_key_aes   (valid_in_key_aes),
                .valid_in_block_aes (valid_in_block_aes),
                .text_out          (text_out_fixed[127:0]),
                .done              (done_fixed),
                .key_expand_ready  (keyr_fixed),
                .cipher_start      (cipher_start_ctrl),
                .aes_in_block      (aes_in_block_ctrl),
                .aes_raw_out       (aes_raw_out_sel),
                .block_done        (block_done_sel),
                .key_exp_start     (key_exp_start_ctrl),
                .key_expand_finish (key_expand_finish_sel_w),
                .mem_key_rw        (mem_key_rw_ctrl)
            );
        end
        else begin : GEN_FIXED_OFB_VARKEY // default OFB
            aes_ofb_var CTRL (
                .clk               (clk),
                .rst_n             (rst_n),
                .init              (init),
                .dec               (dec),
                .iv                (iv),
                .text_in           (text_in),
                .terminate_session (terminate_session),
                .valid_in_key_aes   (valid_in_key_aes),
                .valid_in_block_aes (valid_in_block_aes),
                .text_out          (text_out_fixed[127:0]),
                .done              (done_fixed),
                .key_expand_ready  (keyr_fixed),
                .cipher_start      (cipher_start_ctrl),
                .aes_in_block      (aes_in_block_ctrl),
                .aes_raw_out       (aes_raw_out_sel),
                .block_done        (block_done_sel),
                .key_exp_start     (key_exp_start_ctrl),
                .key_expand_finish (key_expand_finish_sel_w),
                .mem_key_rw        (mem_key_rw_ctrl)
            );
        end
    end

    // Final outputs
    assign text_out         = text_out_fixed;
    assign valid_dout       = done_fixed;
    assign key_expand_ready = keyr_fixed;

end

else if (MODE == VAR_FULL_MODE) begin : GEN_VAR_FULL

    // ============================================================
    // Runtime selects
    // ============================================================
    localparam [1:0] KS_128 = 2'd0;
    localparam [1:0] KS_192 = 2'd1;
    localparam [1:0] KS_256 = 2'd2;

    // ============================================================
    // Per-mode outputs (final)
    // ============================================================
    wire [127:0] text_out_ecb, text_out_ctr, text_out_cbc, text_out_cfb, text_out_ofb;
    wire         done_ecb,     done_ctr,     done_cbc,     done_cfb,     done_ofb;
    wire         keyr_ecb,     keyr_ctr,     keyr_cbc,     keyr_cfb,     keyr_ofb;

    // ============================================================
    // Per-mode controller -> datapath control signals
    // ============================================================
    wire         cipher_start_ecb, cipher_start_ctr, cipher_start_cbc, cipher_start_cfb, cipher_start_ofb;
    wire [127:0] aes_in_block_ecb, aes_in_block_ctr, aes_in_block_cbc, aes_in_block_cfb, aes_in_block_ofb;
    wire         key_exp_start_ecb, key_exp_start_ctr, key_exp_start_cbc, key_exp_start_cfb, key_exp_start_ofb;
    wire         mem_key_rw_ecb,    mem_key_rw_ctr,    mem_key_rw_cbc,    mem_key_rw_cfb,    mem_key_rw_ofb;

    // ============================================================
    // Selected controller outputs (by mode_sel)
    // ============================================================
    reg         cipher_start_sel;
    reg [127:0] aes_in_block_sel;
    reg         key_exp_start_sel;
    reg         mem_key_rw_sel;

    reg [127:0] text_out_sel;
    reg         valid_dout_sel;
    reg         keyr_sel;

    always @(*) begin
        cipher_start_sel  = 1'b0;
        aes_in_block_sel  = 128'b0;
        key_exp_start_sel = 1'b0;
        mem_key_rw_sel    = 1'b0;

        case (mode_sel)
            3'd0: begin
                cipher_start_sel  = cipher_start_ecb;
                aes_in_block_sel  = aes_in_block_ecb;
                key_exp_start_sel = key_exp_start_ecb;
                mem_key_rw_sel    = mem_key_rw_ecb;
            end
            3'd1: begin
                cipher_start_sel  = cipher_start_ctr;
                aes_in_block_sel  = aes_in_block_ctr;
                key_exp_start_sel = key_exp_start_ctr;
                mem_key_rw_sel    = mem_key_rw_ctr;
            end
            3'd2: begin
                cipher_start_sel  = cipher_start_cbc;
                aes_in_block_sel  = aes_in_block_cbc;
                key_exp_start_sel = key_exp_start_cbc;
                mem_key_rw_sel    = mem_key_rw_cbc;
            end
            3'd3: begin
                cipher_start_sel  = cipher_start_cfb;
                aes_in_block_sel  = aes_in_block_cfb;
                key_exp_start_sel = key_exp_start_cfb;
                mem_key_rw_sel    = mem_key_rw_cfb;
            end
            3'd4: begin
                cipher_start_sel  = cipher_start_ofb;
                aes_in_block_sel  = aes_in_block_ofb;
                key_exp_start_sel = key_exp_start_ofb;
                mem_key_rw_sel    = mem_key_rw_ofb;
            end
            default: begin end
        endcase
    end

    wire         cipher_start_ctrl  = cipher_start_sel;
    wire [127:0] aes_in_block_ctrl  = aes_in_block_sel;
    wire         key_exp_start_ctrl = key_exp_start_sel;
    wire         mem_key_rw_ctrl    = mem_key_rw_sel;

    // ============================================================
    // SINGLE DATAPATH WIRES
    // ============================================================
    wire [127:0] aes_raw_out_1;
    wire         block_done_1;

    wire [3:0]   read_key_address_1;
    wire [3:0]   write_key_address_1;
    wire [4:0]   key_address_1;

    wire         mem_round_key_en_1;
    wire [127:0] gen_roundkey_1;
    wire [127:0] roundkey_out_1;

    wire [127:0] next_encstate_1;
    wire [3:0]   round_counter_1;
    wire         round_mem_we_1;

    // ============================================================
    // KEEP 3 KEYEXP modules, but select their write signals
    // ============================================================
    wire         mem_round_key_en_128, mem_round_key_en_192, mem_round_key_en_256;
    wire [3:0]   write_key_address_128, write_key_address_192, write_key_address_256;
    wire [127:0] gen_roundkey_128, gen_roundkey_192, gen_roundkey_256;
    wire         key_expand_finish_128, key_expand_finish_192, key_expand_finish_256;

    aes_keyexpand #(128) KEYEXP_128 (
        .clk           (clk),
        .rst_n         (rst_n),
        .init          (key_exp_start_ctrl),
        .og_key        (og_key[127:0]),
        .store_key_mem (mem_round_key_en_128),
        .address       (write_key_address_128),
        .round_key     (gen_roundkey_128),
        .finish        (key_expand_finish_128)
    );

    aes_keyexpand #(192) KEYEXP_192 (
        .clk           (clk),
        .rst_n         (rst_n),
        .init          (key_exp_start_ctrl),
        .og_key        (og_key[191:0]),
        .store_key_mem (mem_round_key_en_192),
        .address       (write_key_address_192),
        .round_key     (gen_roundkey_192),
        .finish        (key_expand_finish_192)
    );

    aes_keyexpand #(256) KEYEXP_256 (
        .clk           (clk),
        .rst_n         (rst_n),
        .init          (key_exp_start_ctrl),
        .og_key        (og_key[255:0]),
        .store_key_mem (mem_round_key_en_256),
        .address       (write_key_address_256),
        .round_key     (gen_roundkey_256),
        .finish        (key_expand_finish_256)
    );

	 
    reg         mem_round_key_en_sel;
    reg [3:0]   write_key_address_sel;
    reg [127:0] gen_roundkey_sel;
    reg         key_expand_finish_sel;

    always @(*) begin
        // default 128
        mem_round_key_en_sel  = mem_round_key_en_128;
        write_key_address_sel = write_key_address_128;
        gen_roundkey_sel      = gen_roundkey_128;
        key_expand_finish_sel = key_expand_finish_128;

        case (key_size_sel)
            KS_128: begin
                mem_round_key_en_sel  = mem_round_key_en_128;
                write_key_address_sel = write_key_address_128;
                gen_roundkey_sel      = gen_roundkey_128;
                key_expand_finish_sel = key_expand_finish_128;
            end
            KS_192: begin
                mem_round_key_en_sel  = mem_round_key_en_192;
                write_key_address_sel = write_key_address_192;
                gen_roundkey_sel      = gen_roundkey_192;
                key_expand_finish_sel = key_expand_finish_192;
            end
            default: begin // KS_256
                mem_round_key_en_sel  = mem_round_key_en_256;
                write_key_address_sel = write_key_address_256;
                gen_roundkey_sel      = gen_roundkey_256;
                key_expand_finish_sel = key_expand_finish_256;
            end
        endcase
    end

    assign mem_round_key_en_1  = mem_round_key_en_sel;
    assign write_key_address_1 = write_key_address_sel;
    assign gen_roundkey_1      = gen_roundkey_sel;

    // ============================================================
    // SINGLE KEY MEMORY
    // IMPORTANT: must support addr 0..14 (AES-256). Depth 16 is ideal.
    // ============================================================
    mem_round_keys KEYMEM_1 (
        .clock   (clk),
        .address (key_address_1),
        .data    (gen_roundkey_1),
        .wren    (mem_round_key_en_1),
        .q       (roundkey_out_1)
    );

    // Address mux (read from BE vs write from KEYEXP)
    mux2to1 #(4) ADDR_MUX_1 (
        .in0 (read_key_address_1),
        .in1 (write_key_address_1),
        .sel (mem_key_rw_ctrl),
        .out (key_address_1[3:0])
    );
    assign key_address_1[4] = 1'b0;

    // ============================================================
    // SINGLE BLOCK ENCRYPT (runtime key_sel)
    // ============================================================
    block_encrypt BE_1 (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (cipher_start_ctrl),
        .dec           (dec_aes_core),
        .plaintext     (aes_in_block_ctrl),
        .roundkey      (roundkey_out_1),
        .key_sel       (key_size_sel),       // <<< ADDED: runtime key size
        .ciphertext    (aes_raw_out_1),
        .key_address   (read_key_address_1),
        .done          (block_done_1),
        .next_encstate (next_encstate_1),
        .round_counter (round_counter_1),
        .round_mem_we  (round_mem_we_1)
    );

    // ============================================================
    // Feedback to controllers comes from the single datapath
    // ============================================================
    wire [127:0] aes_raw_out_sel       = aes_raw_out_1;
    wire         block_done_sel        = block_done_1;
    wire         key_expand_finish_sel_w = key_expand_finish_sel;

    // Debug outputs (no more debug mux)
    assign next_encstate_out = next_encstate_1;
    assign round_counter_out = round_counter_1;
    assign round_mem_we      = round_mem_we_1;

    // ============================================================
    // Controllers (unchanged)
    // Each controller gets feedback from the single datapath.
    // ============================================================
    aes_ecb_var ECB_CTRL (
        .clk                (clk),
        .rst_n              (rst_n),
        .init_m             (init),
        .dec_m              (dec),
        .text_in_m          (text_in),
        .terminate_session_m(terminate_session),
        .text_out_m         (text_out_ecb),
        .done_m             (done_ecb),
        .key_expand_ready   (keyr_ecb),
        .valid_in_key_aes   (valid_in_key_aes),
        .valid_in_block_aes (valid_in_block_aes),
        .cipher_start       (cipher_start_ecb),
        .aes_in_block       (aes_in_block_ecb),
        .aes_raw_out        (aes_raw_out_sel),
        .block_done         (block_done_sel),
        .key_exp_start      (key_exp_start_ecb),
        .key_expand_finish  (key_expand_finish_sel_w),
        .mem_key_rw         (mem_key_rw_ecb)
    );

    aes_ctr_var CTR_CTRL (
        .clk                (clk),
        .rst_n              (rst_n),
        .init_m             (init),
        .dec                (dec),
        .text_in            (text_in),
        .text_out           (text_out_ctr),
        .terminate_session_m(terminate_session),
        .counter_m          (iv),
        .key_expand_ready   (keyr_ctr),
        .valid_in_key_aes   (valid_in_key_aes),
        .valid_in_block_aes (valid_in_block_aes),
        .cipher_start       (cipher_start_ctr),
        .aes_in_block       (aes_in_block_ctr),
        .key_exp_start      (key_exp_start_ctr),
        .mem_key_rw         (mem_key_rw_ctr),
        .aes_raw_out        (aes_raw_out_sel),
        .block_done         (block_done_sel),
        .key_expand_finish  (key_expand_finish_sel_w),
        .done_m             (done_ctr)
    );

    aes_cbc_var CBC_CTRL (
        .clk               (clk),
        .rst_n             (rst_n),
        .init              (init),
        .dec               (dec),
        .iv                (iv),
        .text_in           (text_in),
        .terminate_session (terminate_session),
        .valid_in_key_aes   (valid_in_key_aes),
        .valid_in_block_aes (valid_in_block_aes),
        .text_out          (text_out_cbc),
        .done              (done_cbc),
        .key_expand_ready  (keyr_cbc),
        .cipher_start      (cipher_start_cbc),
        .aes_in_block      (aes_in_block_cbc),
        .aes_raw_out       (aes_raw_out_sel),
        .block_done        (block_done_sel),
        .key_exp_start     (key_exp_start_cbc),
        .key_expand_finish (key_expand_finish_sel_w),
        .mem_key_rw        (mem_key_rw_cbc)
    );

    aes_cfb_var CFB_CTRL (
        .clk               (clk),
        .rst_n             (rst_n),
        .init              (init),
        .dec               (dec),
        .iv                (iv),
        .text_in           (text_in),
        .terminate_session (terminate_session),
        .valid_in_key_aes   (valid_in_key_aes),
        .valid_in_block_aes (valid_in_block_aes),
        .text_out          (text_out_cfb),
        .done              (done_cfb),
        .key_expand_ready  (keyr_cfb),
        .cipher_start      (cipher_start_cfb),
        .aes_in_block      (aes_in_block_cfb),
        .aes_raw_out       (aes_raw_out_sel),
        .block_done        (block_done_sel),
        .key_exp_start     (key_exp_start_cfb),
        .key_expand_finish (key_expand_finish_sel_w),
        .mem_key_rw        (mem_key_rw_cfb)
    );

    aes_ofb_var OFB_CTRL (
        .clk               (clk),
        .rst_n             (rst_n),
        .init              (init),
        .dec               (dec),
        .iv                (iv),
        .text_in           (text_in),
        .terminate_session (terminate_session),
        .valid_in_key_aes   (valid_in_key_aes),
        .valid_in_block_aes (valid_in_block_aes),
        .text_out          (text_out_ofb),
        .done              (done_ofb),
        .key_expand_ready  (keyr_ofb),
        .cipher_start      (cipher_start_ofb),
        .aes_in_block      (aes_in_block_ofb),
        .aes_raw_out       (aes_raw_out_sel),
        .block_done        (block_done_sel),
        .key_exp_start     (key_exp_start_ofb),
        .key_expand_finish (key_expand_finish_sel_w),
        .mem_key_rw        (mem_key_rw_ofb)
    );

    // ============================================================
    // Final output select by mode_sel (unchanged)
    // ============================================================
    always @(*) begin
        text_out_sel   = 128'b0;
        valid_dout_sel = 1'b0;
        keyr_sel       = 1'b0;

        case (mode_sel)
            3'd0: begin text_out_sel = text_out_ecb; valid_dout_sel = done_ecb; keyr_sel = keyr_ecb; end
            3'd1: begin text_out_sel = text_out_ctr; valid_dout_sel = done_ctr; keyr_sel = keyr_ctr; end
            3'd2: begin text_out_sel = text_out_cbc; valid_dout_sel = done_cbc; keyr_sel = keyr_cbc; end
            3'd3: begin text_out_sel = text_out_cfb; valid_dout_sel = done_cfb; keyr_sel = keyr_cfb; end
            3'd4: begin text_out_sel = text_out_ofb; valid_dout_sel = done_ofb; keyr_sel = keyr_ofb; end
            default: begin end
        endcase
    end

    assign text_out         = text_out_sel;
    assign valid_dout       = valid_dout_sel;
    assign key_expand_ready = keyr_sel;

end

		  endgenerate
endmodule