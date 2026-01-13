`timescale 1ns/1ps

module tb_block_encrypt;

    // clocks & signals
    reg clk = 0;
    always #5 clk = ~clk; // 10 ns period

    reg rst_n = 0;
    reg start = 0;

    reg  [127:0] plaintext;
    reg  [127:0] cipherkey;
    wire [127:0] ciphertext;
    wire done;

    // instantiate DUT (assumes block_encrypt module is in scope)
    block_encrypt dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .plaintext(plaintext),
        .cipherkey(cipherkey),
        .ciphertext(ciphertext),
        .done(done),
		  .dec(1'b0)
    );

    // expected ciphertext from FIPS-197 (canonical example)
    localparam [127:0] EXPECTED_CT = 128'h3925841D02DC09FBDC118597196A0B32;

    initial begin
        // FIPS-197 example (bytes in hex, MSB left)
        // Plaintext:  32 43 f6 a8 88 5a 30 8d 31 31 98 a2 e0 37 07 34
        // Key:        2b 7e 15 16 28 ae d2 a6 ab f7 15 88 09 cf 4f 3c
        plaintext = 128'h3243F6A8885A308D313198A2E0370734;
        cipherkey = 128'h2B7E151628AED2A6ABF7158809CF4F3C;

        // Reset
        rst_n = 0;
        start = 0;
        #20;
        rst_n = 1; // release reset

        // small wait, then pulse start
        #20;
        start = 1;
        #10;
        start = 0;

	
	#2500;
        $display("Plaintext : %032h", plaintext);
        $display("Key       : %032h", cipherkey);
        $display("Ciphertext: %032h", ciphertext);
        $display("Expected  : %032h", EXPECTED_CT);
	
        if (ciphertext === EXPECTED_CT) begin
            $display("RESULT: PASS");
        end else begin
            $display("RESULT: FAIL");
        end

        $finish;
    end

endmodule
