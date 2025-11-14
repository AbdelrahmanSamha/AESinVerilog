module system_top (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [127:0] plaintext,
    input  wire [127:0] key,
    output reg          done,
    output reg  [127:0] ciphertext
);
    // internal signals
    wire [127:0] round_key;
    wire [127:0] state_out;
    wire [3:0]   round_num;
    wire         final_round;
    wire         round_en;
	//////////////////////////////////
	// ECB should be implmeneted here. 
	////////////////////////////////

endmodule
