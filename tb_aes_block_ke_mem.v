`timescale 1ns/1ps

module tb_aes_block_ke_mem;

    // ---------------------------------------------------------
    // Parameters
    // ---------------------------------------------------------
    parameter integer KEY_SIZE = 128;  // 128, 192, 256
    parameter integer DOP      = 4;    // 1 .. 4
    parameter integer MODE     = 1;    // ECB
    parameter integer DEC_MODE = 0;    // 0 = encrypt, 1 = decrypt

    // ---------------------------------------------------------
    // Clock generation
    // ---------------------------------------------------------
    reg clk = 0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // DUT inputs
    // ---------------------------------------------------------
    reg                     rst_n;
    reg                     init;
    reg                     dec;
    reg                     valid_din;
    reg                     terminate_session;
    reg  [KEY_SIZE-1:0]     og_key;
    reg  [DOP*128-1:0]      text_in;

    // ---------------------------------------------------------
    // DUT outputs
    // ---------------------------------------------------------
    wire [DOP*128-1:0]      text_out;
    wire                    valid_dout;

    // ---------------------------------------------------------
    // DUT
    // ---------------------------------------------------------
    aes_top #(
        .KEY_SIZE (KEY_SIZE),
        .DOP      (DOP),
        .MODE     (MODE)
    ) dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .init               (init),
        .dec                (dec),
        .valid_din          (valid_din),
        .og_key             (og_key),
        .text_in            (text_in),
        .terminate_session  (terminate_session),
        .text_out           (text_out),
        .valid_dout         (valid_dout)
    );

    // ---------------------------------------------------------
    // Plaintext blocks (NIST vectors)
    // ---------------------------------------------------------
 /*
 localparam [127:0] PT0 = 128'h6BC1BEE22E409F96E93D7E117393172A;
	 
	 
    localparam [127:0] PT1 = 128'hAE2D8A571E03AC9C9EB76FAC45AF8E51;
    localparam [127:0] PT2 = 128'h30C81C46A35CE411E5FBC1191A0A52EF;
    localparam [127:0] PT3 = 128'hF69F2445DF4F9B17AD2B417BE66C3710;
*/
	 localparam [127:0] PT0 = 128'h874d6191b620e3261bef6864990db6ce;
    localparam [127:0] PT1 = 128'h9806f66b7970fdff8617187bb9fffdff;
    localparam [127:0] PT2 = 128'h06e3607ac42fb572fd5bb6cee65a2141;
    localparam [127:0] PT3 = 128'hc0b45879b83cca74b58b36ac1a3c44be;

    // ---------------------------------------------------------
    // Key selection (same as your original TB)
    // ---------------------------------------------------------
    initial begin
        case (KEY_SIZE)
            128: og_key = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
            192: og_key = 192'h8E73B0F7DA0E6452C810F32B809079E562F8EAD2522C6B7B;
            256: og_key = 256'h603DEB1015CA71BE2B73AEF0857D77811F352C073B6108D72D9810A30914DFF4;
            default: og_key = {KEY_SIZE{1'b0}};
        endcase
    end

    // ---------------------------------------------------------
    // Pack plaintext according to DOP
    // ---------------------------------------------------------
    initial begin 
	text_in = {DOP*128{1'b0}};

        if (DOP >= 1) text_in[127:0]        = PT0;
        if (DOP >= 2) text_in[255:128]      = PT1;
        if (DOP >= 3) text_in[383:256]      = PT2;
        if (DOP >= 4) text_in[511:384]      = PT3;
    end

    // ---------------------------------------------------------
    // Test sequence
    // ---------------------------------------------------------
	integer i;
    initial begin
        rst_n               = 0;
        init                = 0;
        dec                 = DEC_MODE;
        valid_din           = 0;
        terminate_session   = 0;

        #20;
        rst_n = 1;

        #15;
        init      = 1;
	#10;
        valid_din = 1;

        #10;
        //init      = 0;
        //valid_din = 0;
	

        // Wait for encryption/decryption to finish
        wait (valid_dout);

        $display("=======================================");
        $display("AES TOP TEST");
        $display("KEY_SIZE = %0d", KEY_SIZE);
        $display("DOP      = %0d", DOP);
        $display("MODE     = %s", dec ? "DECRYPT" : "ENCRYPT");

        for ( i = 0; i < DOP; i = i + 1) begin
            $display("Block %0d OUT = %032h",
                     i,
                     text_out[i*128 +: 128]);
        end

        $display("=======================================");

        #100;
        $finish;
    end

endmodule
