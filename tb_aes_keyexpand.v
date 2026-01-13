`timescale 1ns/1ps

module tb_aes_keyexpand;

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

    reg [127:0] og_key;

    // ---------------------------------------------------------
    // DUT Outputs
    // ---------------------------------------------------------
    wire [127:0] round_key;
    wire store_key_mem;
    wire [3:0] address;

    // ---------------------------------------------------------
    // Instantiate DUT
    // ---------------------------------------------------------
    aes_keyexpand dut (
        .clk(clk),
        .rst_n(rst_n),
        .init(init),
        .og_key(og_key),
        .store_key_mem(store_key_mem),
        .address(address),
        .round_key(round_key)
    );

    // ---------------------------------------------------------
    // Known AES-128 key from FIPS-197 example
    // ---------------------------------------------------------
    localparam [127:0] TEST_KEY = 128'h2B7E151628AED2A6ABF7158809CF4F3C;

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
        $display("Starting AES Key Expansion Test...");
        $display("Original key: %032h", TEST_KEY);
        $display("");
		  #1000; 
		  $finish;
    end
endmodule
