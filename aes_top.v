module aes_top #(
    parameter integer KEY_SIZE  = 128,
    parameter integer DOP       = 1,
    parameter integer MODE      = 1
)(
    input                     clk,
    input                     rst_n,

    input                     init,
    input                     dec,
    input                     valid_din,
    input  [KEY_SIZE-1:0]     og_key,
    input  [DOP*128-1:0]      text_in,
    input                     terminate_session,

    output [DOP*128-1:0]      text_out,
    output                    valid_dout
);

    localparam integer ECB_MODE = 0;
    localparam integer CTR_MODE = 1;

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
                .valid_in_m            (valid_din),
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
                .text_out              ()
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
                        .valid_in_m       (1'b0),
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

                        .text_out         (text_out[i*128 +: 128])
                    );

                end
            end

            assign valid_dout = done_m;

        end
		  
		  else if (MODE == CTR_MODE) begin : GEN_CTR

            // -----------------------------
            // MAIN ECB instance (index 0)
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
					 
					 .counter_m             (128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdfeff),
					 
                .text_in_m             (text_in[127:0]),
                .valid_in_m            (valid_din),
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
					 
                .text_out              ()
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
                        .valid_in_m       (1'b0),
                        .terminate_session_m (1'b0),
								
								.counter_m  (1'b0),
								
								.text_out_m(),
								.done_m(),
								.cipher_start_all(),
								.roundkey_m_out(),

                        // slave ports
                        .start_cipher     (cipher_start_all),
                        .dec              (dec),
                        .text_in          (text_in[i*128 +: 128]),
                        .read_roundkey_in (roundkey_bus),
				
								.counter_in    (128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFF00),
      
								.text_out         (text_out[i*128 +: 128])
                    );

                end
            end

            assign valid_dout = done_m;

        end
		  
    endgenerate
	 
	 

endmodule
