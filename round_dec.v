module round_dec (
	 input clk,
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    input  wire         final_round,
    output wire [127:0] state_out
);
    wire [127:0] ishift, isub, add, imix;
    wire [127:0] add_input;
    
    // Decryption: InvShiftRows → InvSubBytes → AddRoundKey → InvMixColumns
    inv_shiftrows  u_ishift  (.in(state_in), .out(ishift));
    inv_subbytes   u_isub    (.in(ishift),   .out(isub), .clk(clk));
    
    // AddRoundKey
    aes_addroundkey u_add (
        .state_in(isub),
        .round_key(round_key),
        .state_out(add)
    );
    
    // Inverse MixColumns (skipped in final round)
    inv_mixcolumns u_imix (.in(add), .out(imix));
    
    // Final round skips InvMixColumns
    assign state_out = final_round ? add : imix;
endmodule