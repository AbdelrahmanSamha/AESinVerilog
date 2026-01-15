`timescale 1ns/1ps

module tb_aes_keyexpand;

    // ---------------------------------------------------------
    // Parameter for DUT key size
    // ---------------------------------------------------------
    parameter KEY_SIZE = 256;   // Can be 128, 192, 256

    // ---------------------------------------------------------
    // Clock generation
    // ---------------------------------------------------------
    reg clk = 0;
    always #5 clk = ~clk;   // 10 ns clock period (100 MHz)

    // ---------------------------------------------------------
    // DUT Inputs
    // ---------------------------------------------------------
    reg rst_n = 0;
    reg init  = 0;

    reg [KEY_SIZE-1:0] og_key;

    // ---------------------------------------------------------
    // DUT Outputs
    // ---------------------------------------------------------
    wire [127:0] round_key;
    wire store_key_mem;
    wire [3:0] address;
	 wire finish; 

    // ---------------------------------------------------------
    // Instantiate DUT with parameter override
    // ---------------------------------------------------------
    aes_keyexpand #(
        .KEY_SIZE(KEY_SIZE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .init(init),
        .og_key(og_key),
        .store_key_mem(store_key_mem),
        .address(address),
        .round_key(round_key),
		  .finish(finish)
    );

    // ---------------------------------------------------------
    // Known AES-128/192/256 key
    // ---------------------------------------------------------
    // Pick a key width that matches KEY_SIZE
    localparam [KEY_SIZE-1:0] TEST_KEY =
        (KEY_SIZE == 128) ? 128'h2B7E151628AED2A6ABF7158809CF4F3C :
        (KEY_SIZE == 192) ? 192'h8E73B0F7DA0E6452C810F32B809079E562F8EAD2522C6B7B :
        (KEY_SIZE == 256) ? 256'h603DEB1015CA71BE2B73AEF0857D77811F352C073B6108D72D9810A30914DFF4 :
        {KEY_SIZE{1'b0}}; // default zeros if invalid

    initial begin
        // -----------------------------------------------------
        // Initial values
        // -----------------------------------------------------
        og_key = TEST_KEY;
        init   = 0;
        rst_n  = 0;

        // Apply reset
        #20;
        rst_n = 1;

        // -----------------------------------------------------
        // Pulse init to load key
        // -----------------------------------------------------
        #20;
        init = 1;
        #10;
        init = 0;

        // -----------------------------------------------------
        // Observe key expansion
        // -----------------------------------------------------
        $display("Starting AES-%0d Key Expansion Test...", KEY_SIZE);
        $display("Original key: %0h", TEST_KEY);
        $display("");
        wait(finish == 1'b1) 
	#100
	     $finish;
		  
    end
endmodule