module aes_top #(
    parameter integer KEY_SIZE  = 128,
    parameter integer DOP       = 1,
    parameter integer MODE      = 0
)(
    input                     clk,
    input                     rst_n,

    input                     init,
    input                     dec,
   // input                     valid_din,
	
	
	 input valid_in_key_aes,
    input valid_in_block_aes,
	
    input  [KEY_SIZE-1:0]     og_key,
    input  [DOP*128-1:0]      text_in,
    input                     terminate_session,

    output [DOP*128-1:0]      text_out,
    output                    valid_dout,
	
	 
    output                    key_expand_ready
	 
);

    localparam integer ECB_MODE = 0;

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
					 .valid_in_block_aes(valid_in_block_aes)
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
								
								.key_expand_ready(key_expand_ready),
								
								.valid_in_key_aes(valid_in_key_aes),
								.valid_in_block_aes(valid_in_block_aes)
                    );

                end
            end

            assign valid_dout = done_m;

        end		  
		  

		  
		  
    endgenerate
	 
	 

endmodule