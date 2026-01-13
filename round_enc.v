module round_enc (
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    input  wire         final_round,
    output wire [127:0] state_out
);
    wire [127:0] sub, shift, mix, add;
    wire [127:0] add_input;
    
    // Encryption: SubBytes → ShiftRows → MixColumns → AddRoundKey
    subbytes       u_sub     (.in(state_in), .out(sub));
    aes_shiftrows  u_shift   (.in(sub),      .out(shift));
    aes_mixcolumns u_mix     (.in(shift),    .out(mix));
    
    // Final round skips MixColumns
    assign add_input = final_round ? shift : mix;
    
    aes_addroundkey u_add (
        .state_in(add_input),
        .round_key(round_key),
        .state_out(state_out)
    );
endmodule