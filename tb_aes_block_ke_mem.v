`timescale 1ns/1ps

module tb_aes_block_ke_mem;

    // ---------------------------------------------------------
    // Parameter for AES key size
    // ---------------------------------------------------------
    parameter KEY_SIZE = 256;   // 128, 192, 256
    parameter DEC_MODE = 1;     // 0 = encrypt, 1 = decrypt

    // ---------------------------------------------------------
    // Clock generation
    // ---------------------------------------------------------
    reg clk = 0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // DUT Inputs
    // ---------------------------------------------------------
    reg rst_n = 0;
    reg init  = 0;
    reg dec   = DEC_MODE;
    reg [127:0] plaintext;
    reg [KEY_SIZE-1:0] key;

    // ---------------------------------------------------------
    // DUT Outputs
    // ---------------------------------------------------------
    wire [127:0] ciphertext;
    wire done;

    // ---------------------------------------------------------
    // DUT
    // ---------------------------------------------------------
    aes_top #(
        .KEY_SIZE(KEY_SIZE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .init(init),
        .dec(dec),
        .plaintext(plaintext),
        .key(key),
        .ciphertext(ciphertext),
        .done(done)
    );

    // ---------------------------------------------------------
    // AES Test Vectors (FIPS-197)
    // ---------------------------------------------------------
    localparam [127:0] AES128_PT = 128'h3243F6A8885A308D313198A2E0370734;
    localparam [127:0] AES128_CT = 128'h3925841D02DC09FBDC118597196A0B32;

    localparam [127:0] AES192_PT = 128'h6BC1BEE22E409F96E93D7E117393172A;
    localparam [127:0] AES192_CT = 128'hBD334F1D6E45F25FF712A214571FA5CC;

    localparam [127:0] AES256_PT = 128'h6BC1BEE22E409F96E93D7E117393172A;
    localparam [127:0] AES256_CT = 128'hF3EED1BDB5D2A03C064B5A7E3DB181F8;

    localparam [127:0] EXPECTED_PT =
        (KEY_SIZE == 128) ? AES128_PT :
        (KEY_SIZE == 192) ? AES192_PT :
        (KEY_SIZE == 256) ? AES256_PT : 128'b0;

    localparam [127:0] EXPECTED_CT =
        (KEY_SIZE == 128) ? AES128_CT :
        (KEY_SIZE == 192) ? AES192_CT :
        (KEY_SIZE == 256) ? AES256_CT : 128'b0;

    // ---------------------------------------------------------
    // Select key and input data
    // ---------------------------------------------------------
    initial begin
        case (KEY_SIZE)
            128: key = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
            192: key = 192'h8E73B0F7DA0E6452C810F32B809079E562F8EAD2522C6B7B;
            256: key = 256'h603DEB1015CA71BE2B73AEF0857D77811F352C073B6108D72D9810A30914DFF4;
        endcase

        // IMPORTANT PART
        if (dec == 1'b0)
            plaintext = EXPECTED_PT;   // encryption
        else
            plaintext = EXPECTED_CT;   // decryption
    end

    // ---------------------------------------------------------
    // Test procedure
    // ---------------------------------------------------------
    initial begin
        rst_n = 0;
        init  = 0;
        #20 rst_n = 1;

        #10 init = 1;
        #10 init = 0;

        wait(done);

        if (!dec) begin
            $display("AES-%0d ENCRYPTION", KEY_SIZE);
            $display("Expected CT: %032h", EXPECTED_CT);
            $display("Got      CT: %032h", ciphertext);

            if (ciphertext == EXPECTED_CT)
                $display(" PASS");
            else
                $display(" FAIL");
        end
        else begin
            $display("AES-%0d DECRYPTION", KEY_SIZE);
            $display("Expected PT: %032h", EXPECTED_PT);
            $display("Got      PT: %032h", ciphertext);

            if (ciphertext == EXPECTED_PT)
                $display(" PASS");
            else
                $display(" FAIL");
        end

        #100;
        $finish;
    end

endmodule
