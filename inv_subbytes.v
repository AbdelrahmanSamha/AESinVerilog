module inv_subbytes(
    input  [127:0] in,
    output [127:0] out
);

    // Instance 0: bits [7:0]
    inv_sbox s0 (.in(in[7:0]),    .out(out[7:0]));
    
    // Instance 1: bits [15:8]
    inv_sbox s1 (.in(in[15:8]),   .out(out[15:8]));
    
    // Instance 2: bits [23:16]
    inv_sbox s2 (.in(in[23:16]),  .out(out[23:16]));
    
    // Instance 3: bits [31:24]
    inv_sbox s3 (.in(in[31:24]),  .out(out[31:24]));
    
    // Instance 4: bits [39:32]
    inv_sbox s4 (.in(in[39:32]),  .out(out[39:32]));
    
    // Instance 5: bits [47:40]
    inv_sbox s5 (.in(in[47:40]),  .out(out[47:40]));
    
    // Instance 6: bits [55:48]
    inv_sbox s6 (.in(in[55:48]),  .out(out[55:48]));
    
    // Instance 7: bits [63:56]
    inv_sbox s7 (.in(in[63:56]),  .out(out[63:56]));
    
    // Instance 8: bits [71:64]
    inv_sbox s8 (.in(in[71:64]),  .out(out[71:64]));
    
    // Instance 9: bits [79:72]
    inv_sbox s9 (.in(in[79:72]),  .out(out[79:72]));
    
    // Instance 10: bits [87:80]
    inv_sbox s10 (.in(in[87:80]), .out(out[87:80]));
    
    // Instance 11: bits [95:88]
    inv_sbox s11 (.in(in[95:88]), .out(out[95:88]));
    
    // Instance 12: bits [103:96]
    inv_sbox s12 (.in(in[103:96]), .out(out[103:96]));
    
    // Instance 13: bits [111:104]
    inv_sbox s13 (.in(in[111:104]), .out(out[111:104]));
    
    // Instance 14: bits [119:112]
    inv_sbox s14 (.in(in[119:112]), .out(out[119:112]));
    
    // Instance 15: bits [127:120]
    inv_sbox s15 (.in(in[127:120]), .out(out[127:120]));

endmodule