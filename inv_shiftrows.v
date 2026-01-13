module inv_shiftrows (
    input  wire [127:0] in,
    output wire [127:0] out
);

    /*
        Inverse ShiftRows operation for AES decryption
        
        Original (shifted) state : 
        ------------------------------------------------------
        |   b0   |   b4   |   b8   |   b12  |
        |[127:120]|[95:88] |[63:56] |[31:24] |
        |--------|--------|--------|--------|
        |   b1   |   b5   |   b9   |   b13  |
        |[119:112]|[87:80] |[55:48] |[23:16] |
        |--------|--------|--------|--------|
        |   b2   |   b6   |   b10  |   b14  |
        |[111:104]|[79:72] |[47:40] |[15:8]  |
        |--------|--------|--------|--------|
        |   b3   |   b7   |   b11  |   b15  |
        |[103:96] |[71:64] |[39:32] |[7:0]   |
        ------------------------------------------------------

        After inverse shift (restored state):
        ------------------------------------------------------
        |   b0   |   b4   |   b8   |   b12  |
        |[127:120]|[95:88] |[63:56] |[31:24] |
        |--------|--------|--------|--------|
        |   b13  |   b1   |   b5   |   b9   |
        |[23:16] |[119:112]|[87:80] |[55:48] |
        |--------|--------|--------|--------|
        |   b10  |   b14  |   b2   |   b6   |
        |[47:40] |[15:8]  |[111:104]|[79:72] |
        |--------|--------|--------|--------|
        |   b7   |   b11  |   b15  |   b3   |
        |[71:64] |[39:32] |[7:0]   |[103:96]|
        ------------------------------------------------------

        Operation:
        - Row 0: no shift (same as forward)
        - Row 1: right shift by 1 (circular)
        - Row 2: right shift by 2 (circular)  
        - Row 3: right shift by 3 (circular)
    */

    // Row 0 (no shift)
    assign out[127:120] = in[127:120]; // b0
    assign out[95:88]   = in[95:88];   // b4
    assign out[63:56]   = in[63:56];   // b8
    assign out[31:24]   = in[31:24];   // b12

    // Row 1 (right shift by 1 - circular)
    assign out[119:112] = in[23:16];   // b1 <- b13
    assign out[87:80]   = in[119:112]; // b5 <- b1
    assign out[55:48]   = in[87:80];   // b9 <- b5
    assign out[23:16]   = in[55:48];   // b13 <- b9

    // Row 2 (right shift by 2 - circular)
    assign out[111:104] = in[47:40];   // b2 <- b10
    assign out[79:72]   = in[15:8];    // b6 <- b14
    assign out[47:40]   = in[111:104]; // b10 <- b2
    assign out[15:8]    = in[79:72];   // b14 <- b6

    // Row 3 (right shift by 3 - circular)
    assign out[103:96]  = in[71:64];   // b3 <- b7
    assign out[71:64]   = in[39:32];   // b7 <- b11
    assign out[39:32]   = in[7:0];     // b11 <- b15
    assign out[7:0]     = in[103:96];  // b15 <- b3

endmodule