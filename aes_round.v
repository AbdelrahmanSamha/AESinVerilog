module aes_round (
	 input clk,
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    input  wire         final_round,
    input  wire         dec,           // decryption signal
    output wire [127:0] state_out
);
    wire [127:0] enc_path_out, dec_path_out;
    
    // Encryption path: SubBytes → ShiftRows → MixColumns → AddRoundKey
    round_enc u_enc_round (
	     .clk(clk),
        .state_in(state_in),
        .round_key(round_key),
        .final_round(final_round),
        .state_out(enc_path_out)
    );
    
    // Decryption path: InvShiftRows → InvSubBytes → AddRoundKey → InvMixColumns
    round_dec u_dec_round (
	     .clk(clk),
        .state_in(state_in),
        .round_key(round_key),
        .final_round(final_round),
        .state_out(dec_path_out)
    );
    
    // Mux to select between encryption and decryption
    mux2to1 #(.WIDTH(128)) u_mux_mode (
        .in0(enc_path_out),    // encryption
        .in1(dec_path_out),    // decryption
        .sel(dec),
        .out(state_out)
    );
endmodule