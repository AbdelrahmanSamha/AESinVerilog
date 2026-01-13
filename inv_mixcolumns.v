module inv_mixcolumns (
    input  wire [127:0] in,
    output wire [127:0] out
);

    /*
        Inverse MixColumns operation for AES decryption
        
        The inverse MixColumns uses a different matrix:
        
        [0E 0B 0D 09]
        [09 0E 0B 0D] 
        [0D 09 0E 0B]
        [0B 0D 09 0E]
        
        For each column [b0, b1, b2, b3]:
        
        s0' = 0x0E*b0 ^ 0x0B*b1 ^ 0x0D*b2 ^ 0x09*b3
        s1' = 0x09*b0 ^ 0x0E*b1 ^ 0x0B*b2 ^ 0x0D*b3  
        s2' = 0x0D*b0 ^ 0x09*b1 ^ 0x0E*b2 ^ 0x0B*b3
        s3' = 0x0B*b0 ^ 0x0D*b1 ^ 0x09*b2 ^ 0x0E*b3
    */

    wire [7:0] b0,  b1,  b2,  b3;
    wire [7:0] b4,  b5,  b6,  b7;
    wire [7:0] b8,  b9,  b10, b11;
    wire [7:0] b12, b13, b14, b15;
	 
    wire [7:0] S00, S10, S20, S30; // 1st column
    wire [7:0] S01, S11, S21, S31; // 2nd column
    wire [7:0] S02, S12, S22, S32; // 3rd column
    wire [7:0] S03, S13, S23, S33; // 4th column
	
	// Column-major mapping (same as forward)
	assign b0  = in[127:120];
	assign b1  = in[119:112];
	assign b2  = in[111:104];
	assign b3  = in[103:96];
	
	assign b4  = in[95:88];
	assign b5  = in[87:80];
	assign b6  = in[79:72];
	assign b7  = in[71:64];
	
	assign b8  = in[63:56];
	assign b9  = in[55:48];
	assign b10 = in[47:40];
	assign b11 = in[39:32];
	
	assign b12 = in[31:24];
	assign b13 = in[23:16];
	assign b14 = in[15:8];
	assign b15 = in[7:0];
	
    // --------------------------
    // Inverse MixColumns transformations
    // --------------------------

    // === First column (b0, b1, b2, b3) ===
    wire [7:0] b0_x9, b0_xB, b0_xD, b0_xE;
    wire [7:0] b1_x9, b1_xB, b1_xD, b1_xE;
    wire [7:0] b2_x9, b2_xB, b2_xD, b2_xE;
    wire [7:0] b3_x9, b3_xB, b3_xD, b3_xE;

    mult9  mult9_b0  (.in(b0), .out(b0_x9));
    multB  multB_b0  (.in(b0), .out(b0_xB));
    multD  multD_b0  (.in(b0), .out(b0_xD));
    multE  multE_b0  (.in(b0), .out(b0_xE));

    mult9  mult9_b1  (.in(b1), .out(b1_x9));
    multB  multB_b1  (.in(b1), .out(b1_xB));
    multD  multD_b1  (.in(b1), .out(b1_xD));
    multE  multE_b1  (.in(b1), .out(b1_xE));

    mult9  mult9_b2  (.in(b2), .out(b2_x9));
    multB  multB_b2  (.in(b2), .out(b2_xB));
    multD  multD_b2  (.in(b2), .out(b2_xD));
    multE  multE_b2  (.in(b2), .out(b2_xE));

    mult9  mult9_b3  (.in(b3), .out(b3_x9));
    multB  multB_b3  (.in(b3), .out(b3_xB));
    multD  multD_b3  (.in(b3), .out(b3_xD));
    multE  multE_b3  (.in(b3), .out(b3_xE));

    assign S00 = b0_xE ^ b1_xB ^ b2_xD ^ b3_x9;
    assign S10 = b0_x9 ^ b1_xE ^ b2_xB ^ b3_xD;
    assign S20 = b0_xD ^ b1_x9 ^ b2_xE ^ b3_xB;
    assign S30 = b0_xB ^ b1_xD ^ b2_x9 ^ b3_xE;

    // === Second column (b4, b5, b6, b7) ===
    wire [7:0] b4_x9, b4_xB, b4_xD, b4_xE;
    wire [7:0] b5_x9, b5_xB, b5_xD, b5_xE;
    wire [7:0] b6_x9, b6_xB, b6_xD, b6_xE;
    wire [7:0] b7_x9, b7_xB, b7_xD, b7_xE;

    mult9  mult9_b4  (.in(b4), .out(b4_x9));
    multB  multB_b4  (.in(b4), .out(b4_xB));
    multD  multD_b4  (.in(b4), .out(b4_xD));
    multE  multE_b4  (.in(b4), .out(b4_xE));

    mult9  mult9_b5  (.in(b5), .out(b5_x9));
    multB  multB_b5  (.in(b5), .out(b5_xB));
    multD  multD_b5  (.in(b5), .out(b5_xD));
    multE  multE_b5  (.in(b5), .out(b5_xE));

    mult9  mult9_b6  (.in(b6), .out(b6_x9));
    multB  multB_b6  (.in(b6), .out(b6_xB));
    multD  multD_b6  (.in(b6), .out(b6_xD));
    multE  multE_b6  (.in(b6), .out(b6_xE));

    mult9  mult9_b7  (.in(b7), .out(b7_x9));
    multB  multB_b7  (.in(b7), .out(b7_xB));
    multD  multD_b7  (.in(b7), .out(b7_xD));
    multE  multE_b7  (.in(b7), .out(b7_xE));

    assign S01 = b4_xE ^ b5_xB ^ b6_xD ^ b7_x9;
    assign S11 = b4_x9 ^ b5_xE ^ b6_xB ^ b7_xD;
    assign S21 = b4_xD ^ b5_x9 ^ b6_xE ^ b7_xB;
    assign S31 = b4_xB ^ b5_xD ^ b6_x9 ^ b7_xE;

    // === Third column (b8, b9, b10, b11) ===
    wire [7:0] b8_x9, b8_xB, b8_xD, b8_xE;
    wire [7:0] b9_x9, b9_xB, b9_xD, b9_xE;
    wire [7:0] b10_x9, b10_xB, b10_xD, b10_xE;
    wire [7:0] b11_x9, b11_xB, b11_xD, b11_xE;

    mult9  mult9_b8   (.in(b8),  .out(b8_x9));
    multB  multB_b8   (.in(b8),  .out(b8_xB));
    multD  multD_b8   (.in(b8),  .out(b8_xD));
    multE  multE_b8   (.in(b8),  .out(b8_xE));

    mult9  mult9_b9   (.in(b9),  .out(b9_x9));
    multB  multB_b9   (.in(b9),  .out(b9_xB));
    multD  multD_b9   (.in(b9),  .out(b9_xD));
    multE  multE_b9   (.in(b9),  .out(b9_xE));

    mult9  mult9_b10  (.in(b10), .out(b10_x9));
    multB  multB_b10  (.in(b10), .out(b10_xB));
    multD  multD_b10  (.in(b10), .out(b10_xD));
    multE  multE_b10  (.in(b10), .out(b10_xE));

    mult9  mult9_b11  (.in(b11), .out(b11_x9));
    multB  multB_b11  (.in(b11), .out(b11_xB));
    multD  multD_b11  (.in(b11), .out(b11_xD));
    multE  multE_b11  (.in(b11), .out(b11_xE));

    assign S02 = b8_xE ^ b9_xB ^ b10_xD ^ b11_x9;
    assign S12 = b8_x9 ^ b9_xE ^ b10_xB ^ b11_xD;
    assign S22 = b8_xD ^ b9_x9 ^ b10_xE ^ b11_xB;
    assign S32 = b8_xB ^ b9_xD ^ b10_x9 ^ b11_xE;

    // === Fourth column (b12, b13, b14, b15) ===
    wire [7:0] b12_x9, b12_xB, b12_xD, b12_xE;
    wire [7:0] b13_x9, b13_xB, b13_xD, b13_xE;
    wire [7:0] b14_x9, b14_xB, b14_xD, b14_xE;
    wire [7:0] b15_x9, b15_xB, b15_xD, b15_xE;

    mult9  mult9_b12  (.in(b12), .out(b12_x9));
    multB  multB_b12  (.in(b12), .out(b12_xB));
    multD  multD_b12  (.in(b12), .out(b12_xD));
    multE  multE_b12  (.in(b12), .out(b12_xE));

    mult9  mult9_b13  (.in(b13), .out(b13_x9));
    multB  multB_b13  (.in(b13), .out(b13_xB));
    multD  multD_b13  (.in(b13), .out(b13_xD));
    multE  multE_b13  (.in(b13), .out(b13_xE));

    mult9  mult9_b14  (.in(b14), .out(b14_x9));
    multB  multB_b14  (.in(b14), .out(b14_xB));
    multD  multD_b14  (.in(b14), .out(b14_xD));
    multE  multE_b14  (.in(b14), .out(b14_xE));

    mult9  mult9_b15  (.in(b15), .out(b15_x9));
    multB  multB_b15  (.in(b15), .out(b15_xB));
    multD  multD_b15  (.in(b15), .out(b15_xD));
    multE  multE_b15  (.in(b15), .out(b15_xE));

    assign S03 = b12_xE ^ b13_xB ^ b14_xD ^ b15_x9;
    assign S13 = b12_x9 ^ b13_xE ^ b14_xB ^ b15_xD;
    assign S23 = b12_xD ^ b13_x9 ^ b14_xE ^ b15_xB;
    assign S33 = b12_xB ^ b13_xD ^ b14_x9 ^ b15_xE;

	// Assign output back into 128-bit wire (column-major order)
	assign out[127:120] = S00;
	assign out[119:112] = S10;
	assign out[111:104] = S20;
	assign out[103:96]  = S30;
	
	assign out[95:88]   = S01;
	assign out[87:80]   = S11;
	assign out[79:72]   = S21;
	assign out[71:64]   = S31;
	
	assign out[63:56]   = S02;
	assign out[55:48]   = S12;
	assign out[47:40]   = S22;
	assign out[39:32]   = S32;
	
	assign out[31:24]   = S03;
	assign out[23:16]   = S13;
	assign out[15:8]    = S23;
	assign out[7:0]     = S33;

endmodule

// Multiplication by 0x09 in GF(2^8): 0x09 = 0x08 ^ 0x01 = 2*(2*(2*x)) ^ x
module mult9 (
    input  wire [7:0] in,
    output wire [7:0] out
);
    wire [7:0] mult2_out1, mult2_out2, mult2_out3;

    mult2 m1 (.in(in),         .out(mult2_out1));  // 2*x
    mult2 m2 (.in(mult2_out1), .out(mult2_out2));  // 4*x  
    mult2 m3 (.in(mult2_out2), .out(mult2_out3));  // 8*x

    assign out = mult2_out3 ^ in;  // 8*x ^ x = 9*x
endmodule

// Multiplication by 0x0B in GF(2^8): 0x0B = 0x08 ^ 0x02 ^ 0x01 = 2*(2*(2*x)) ^ 2*x ^ x
module multB (
    input  wire [7:0] in,
    output wire [7:0] out
);
    wire [7:0] mult2_out1, mult2_out2, mult2_out3;

    mult2 m1 (.in(in),         .out(mult2_out1));  // 2*x
    mult2 m2 (.in(mult2_out1), .out(mult2_out2));  // 4*x
    mult2 m3 (.in(mult2_out2), .out(mult2_out3));  // 8*x

    assign out = mult2_out3 ^ mult2_out1 ^ in;  // 8*x ^ 2*x ^ x = 11*x
endmodule

// Multiplication by 0x0D in GF(2^8): 0x0D = 0x08 ^ 0x04 ^ 0x01 = 2*(2*(2*x)) ^ 2*(2*x) ^ x
module multD (
    input  wire [7:0] in,
    output wire [7:0] out
);
    wire [7:0] mult2_out1, mult2_out2, mult2_out3;

    mult2 m1 (.in(in),         .out(mult2_out1));  // 2*x
    mult2 m2 (.in(mult2_out1), .out(mult2_out2));  // 4*x  
    mult2 m3 (.in(mult2_out2), .out(mult2_out3));  // 8*x

    assign out = mult2_out3 ^ mult2_out2 ^ in;  // 8*x ^ 4*x ^ x = 13*x
endmodule

// Multiplication by 0x0E in GF(2^8): 0x0E = 0x08 ^ 0x04 ^ 0x02 = 2*(2*(2*x)) ^ 2*(2*x) ^ 2*x
module multE (
    input  wire [7:0] in,
    output wire [7:0] out
);
    wire [7:0] mult2_out1, mult2_out2, mult2_out3;

    mult2 m1 (.in(in),         .out(mult2_out1));  // 2*x
    mult2 m2 (.in(mult2_out1), .out(mult2_out2));  // 4*x
    mult2 m3 (.in(mult2_out2), .out(mult2_out3));  // 8*x

    assign out = mult2_out3 ^ mult2_out2 ^ mult2_out1;  // 8*x ^ 4*x ^ 2*x = 14*x
endmodule