module aes_mixcolumns (
    input  wire [127:0] in,
    output wire [127:0] out
);


/*
		original state : 
		------------------------------------------------------
		|		b0		|		b4			|		b8		|		b12	  |
		|	  			|	 	   		|				|				  |
		|				|					|				|				  |
		|-----------|--------------|-----------|-------------|
		|		b1		|		b5			|		b9		|		b13	  |
		|	  			|	 	   		|				|				  |
		|				|					|				|				  |
		|-----------|--------------|-----------|-------------|
		|		b2		|		b6			|		b10	|		b14	  |
		|	 			|	 	  		   |				|				  |
		|				|					|				|				  |
		|-----------|--------------|-----------|-------------|
		|		b3		|		b7			|		b11	|		b15	  |
		|	 			|	 			   |				|				  |
		|				|					|				|				  |
		------------------------------------------------------
		
		------------------------------------------------------
		|		1.		|		 5.		|		9.		|		13. 	  |
		|	  	02		|	 	 03  		|		01		|		01		  |
		|				|					|				|				  |
		|-----------|--------------|-----------|-------------|
		|		2.		|		6.			|		10.	|		14. 	  |
		|	  	01		|	 	02   		|		03		|		01		  |
		|				|					|				|				  |
		|-----------|--------------|-----------|-------------|
		|		3.		|		7.			|		11.	|		15. 	  |
		|	 	01		|	 	01		   |		02		|		03		  |
		|				|					|				|				  |
		|-----------|--------------|-----------|-------------|
		|		4.		|		8.			|		12. 	|		16. 	  |
		|	 	03		|	 	01		   |		01		|		02		  |
		|				|					|				|				  |
		------------------------------------------------------

In this operation we will define a fixed operation on each cell to generate the output state. 
	for the output state we are going to have 4 columns, and the provided procedure will cover the first column.
	this can be found in the official document of the algorithm AES FIPS 197. 
	-------------
	|		S'0c	|	s'0c = 2*(c[0]) ^ 3*(c[1]) ^ c[2] ^ c[3]
	|	  			|
	|				|
	|-----------|
	|		S'1c	|	s1c' = c[0] ^ 2*(c[1]) ^ 3*(c[2]) ^ c[3]
	|	  			|
	|				|
	|-----------|
	|		S'2c	|	s'2c = c[0] ^ c[1] ^ 2*(c[2]) ^ 3*(c[3])
	|	 			|
	|				|
	|-----------|
	|		S'3c	|	s'3c = 3*(c[0]) ^ c[1] ^ c[2] ^ 2*(c[3])
	|				|
	|				|
   -------------
	
	
	multiplication here is not ordinal there are rules to it becasue we are in GF(2^8), we'll first define multiplication by 2: 
	
	2* : 
		
		2*x = {
					2*x 				 if no ov
				
					2*x[7:0] ^ 0x1B if ov 
				}	
	3* : 
	
		3*x= 2*x ^ x 
		
		
	so essientially we are going to these operations on each cell to produce the final 4by4 state. 
	
*/ 
 
    wire [7:0] b0,  b1,  b2,  b3;
    wire [7:0] b4,  b5,  b6,  b7;
    wire [7:0] b8,  b9,  b10, b11;
    wire [7:0] b12, b13, b14, b15;
	 
    wire [7:0] S00, S10, S20, S30; //1st column
    wire [7:0] S01, S11, S21, S31; //2nd column
    wire [7:0] S02, S12, S22, S32; //3rd column
    wire [7:0] S03, S13, S23, S33; //4th column
	
	//column-major mapping 
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
    // MixColumns transformations
    // --------------------------

    // === First column (b0, b1, b2, b3) ===
    wire [7:0] b0_x2, b1_x2, b2_x2, b3_x2;
    wire [7:0] b0_x3, b1_x3, b2_x3, b3_x3;

    mult2 mult2_b0 (.in(b0), .out(b0_x2));
    mult2 mult2_b1 (.in(b1), .out(b1_x2));
    mult2 mult2_b2 (.in(b2), .out(b2_x2));
    mult2 mult2_b3 (.in(b3), .out(b3_x2));

    mult3 mult3_b0 (.in(b0), .out(b0_x3));
    mult3 mult3_b1 (.in(b1), .out(b1_x3));
    mult3 mult3_b2 (.in(b2), .out(b2_x3));
    mult3 mult3_b3 (.in(b3), .out(b3_x3));

    assign S00 = b0_x2 ^ b1_x3 ^ b2 ^ b3;
    assign S10 = b0 ^ b1_x2 ^ b2_x3 ^ b3;
    assign S20 = b0 ^ b1 ^ b2_x2 ^ b3_x3;
    assign S30 = b0_x3 ^ b1 ^ b2 ^ b3_x2;

    // === Second column (b4, b5, b6, b7) ===
    wire [7:0] b4_x2, b5_x2, b6_x2, b7_x2;
    wire [7:0] b4_x3, b5_x3, b6_x3, b7_x3;

    mult2 mult2_b4 (.in(b4), .out(b4_x2));
    mult2 mult2_b5 (.in(b5), .out(b5_x2));
    mult2 mult2_b6 (.in(b6), .out(b6_x2));
    mult2 mult2_b7 (.in(b7), .out(b7_x2));

    mult3 mult3_b4 (.in(b4), .out(b4_x3));
    mult3 mult3_b5 (.in(b5), .out(b5_x3));
    mult3 mult3_b6 (.in(b6), .out(b6_x3));
    mult3 mult3_b7 (.in(b7), .out(b7_x3));

    assign S01 = b4_x2 ^ b5_x3 ^ b6 ^ b7;
    assign S11 = b4 ^ b5_x2 ^ b6_x3 ^ b7;
    assign S21 = b4 ^ b5 ^ b6_x2 ^ b7_x3;
    assign S31 = b4_x3 ^ b5 ^ b6 ^ b7_x2;

    // === Third column (b8, b9, b10, b11) ===
    wire [7:0] b8_x2, b9_x2, b10_x2, b11_x2;
    wire [7:0] b8_x3, b9_x3, b10_x3, b11_x3;

    mult2 mult2_b8  (.in(b8),  .out(b8_x2));
    mult2 mult2_b9  (.in(b9),  .out(b9_x2));
    mult2 mult2_b10 (.in(b10), .out(b10_x2));
    mult2 mult2_b11 (.in(b11), .out(b11_x2));

    mult3 mult3_b8  (.in(b8),  .out(b8_x3));
    mult3 mult3_b9  (.in(b9),  .out(b9_x3));
    mult3 mult3_b10 (.in(b10), .out(b10_x3));
    mult3 mult3_b11 (.in(b11), .out(b11_x3));

    assign S02 = b8_x2 ^ b9_x3 ^ b10 ^ b11;
    assign S12 = b8 ^ b9_x2 ^ b10_x3 ^ b11;
    assign S22 = b8 ^ b9 ^ b10_x2 ^ b11_x3;
    assign S32 = b8_x3 ^ b9 ^ b10 ^ b11_x2;

    // === Fourth column (b12, b13, b14, b15) ===
    wire [7:0] b12_x2, b13_x2, b14_x2, b15_x2;
    wire [7:0] b12_x3, b13_x3, b14_x3, b15_x3;

    mult2 mult2_b12 (.in(b12), .out(b12_x2));
    mult2 mult2_b13 (.in(b13), .out(b13_x2));
    mult2 mult2_b14 (.in(b14), .out(b14_x2));
    mult2 mult2_b15 (.in(b15), .out(b15_x2));

    mult3 mult3_b12 (.in(b12), .out(b12_x3));
    mult3 mult3_b13 (.in(b13), .out(b13_x3));
    mult3 mult3_b14 (.in(b14), .out(b14_x3));
    mult3 mult3_b15 (.in(b15), .out(b15_x3));

    assign S03 = b12_x2 ^ b13_x3 ^ b14 ^ b15;
    assign S13 = b12 ^ b13_x2 ^ b14_x3 ^ b15;
    assign S23 = b12 ^ b13 ^ b14_x2 ^ b15_x3;
    assign S33 = b12_x3 ^ b13 ^ b14 ^ b15_x2;
	

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







// Multiply by 2 in GF(2^8)
module mult2 (
    input  wire [7:0] in,
    output wire [7:0] out
);
    assign out = (in[7] == 1'b1) ? ((in << 1) ^ 8'h1B) : (in << 1);
endmodule


// Multiply by 3 in GF(2^8)
module mult3 (
    input  wire [7:0] in,
    output wire [7:0] out
);
    wire [7:0] mult2_out;

    // Instantiate the mult2 module
    mult2 u_mult2 (
        .in(in),
        .out(mult2_out)
    );

    // In GF(2^8), multiplication by 3 = (2 * b) XOR b
    assign out = mult2_out ^ in;

endmodule
