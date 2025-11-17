module aes_round (
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    input  wire         final_round,
    output 		 [127:0] state_out
);
    wire [127:0] sub, shift, mix, add;

    subbytes   u_sub   (.in(state_in), .out(sub));
    aes_shiftrows  u_shift (.in(sub),      .out(shift));
    aes_mixcolumns u_mix   (.in(shift),    .out(mix));
    aes_addroundkey u_add  (
        .state_in(final_round ? shift : mix),
        .round_key(round_key),
        .state_out(add)
    );
		
	 assign state_out = add; 		
		

endmodule
