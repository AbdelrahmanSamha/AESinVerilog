`timescale 1ns/1ps
module tb_aes;
    reg clk=0, rst_n=0, start=0;
    reg [127:0] plaintext, key;
    wire done;
    wire [127:0] ciphertext;

    aes_top dut (
        .clk(clk), .rst_n(rst_n),
        .start(start),
        .plaintext(plaintext),
        .key(key),
        .done(done),
        .ciphertext(ciphertext)
    );

    always #5 clk = ~clk;

    initial begin
        plaintext = 128'h00112233445566778899AABBCCDDEEFF;
        key       = 128'h000102030405060708090A0B0C0D0E0F;
        #10 rst_n = 1;
        #10 start = 1; #10 start = 0;
        wait(done);
        $display("Ciphertext = %h", ciphertext);
        $finish;
    end
endmodule
