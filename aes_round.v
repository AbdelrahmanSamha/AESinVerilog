module aes_round (
    input  wire         clk,
    input  wire         en,
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    input  wire         final_round,
    output reg  [127:0] state_out
);
    wire [127:0] sub, shift, mix, add;

    aes_subbytes   u_sub   (.in(state_in), .out(sub));
    aes_shiftrows  u_shift (.in(sub),      .out(shift));
    aes_mixcolumns u_mix   (.state_in(shift),    .state_out(mix));
    aes_addroundkey u_add  (
        .state_in(final_round ? shift : mix),
        .round_key(round_key),
        .state_out(add)
    );

    always @(posedge clk) if (en) state_out <= add;
endmodule
