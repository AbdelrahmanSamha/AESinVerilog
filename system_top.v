module system_top (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [7:0] plaintext,
    input  wire [7:0] key,
    output           done,
    output 	  [7:0] ciphertext
);

	//////////////////////////////////
	// ECB should be implmeneted here. 
	////////////////////////////////
	wire [127:0] PT,CT, CK;
	
	assign PT = {96'b0,plaintext};
	assign CK = {96'b0,key};
	assign ciphertext = CT[7:0];
	
	 block_encrypt BE(
		 	.clk(clk),
			.rst_n(rst_n), 
		 	.start(start),
		 	 .plaintext(PT), 
		 	 .cipherkey(CK), 
			 .ciphertext(CT),
		 	 .done(done)
		);
	
	mem_round_keys( .clock(clk), .address(), .data(), .wren(), .q());
	

endmodule
