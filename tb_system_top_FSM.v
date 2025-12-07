`timescale 1ns/1ps

module tb_system_top_FSM;

    // ---------------- DUT signals ----------------
    reg         clk;
    reg         rst_n;
    reg         init_accel;
    reg         dec;
    reg         uart_rx;
    wire        uart_tx;
    wire        done;

    // ---------------- Clock (50 MHz) ----------------
    always #10 clk = ~clk;

    // ---------------- Instantiate DUT ----------------
    system_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .init_accel(init_accel),
        .dec(dec),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .top_fsm_done(done)
    );

    // ---------------- UART PARAMETERS ----------------
    parameter CLK_FREQ = 50_000_000;
    parameter BAUD     = 115200;
    parameter BIT_TIME = 1_000_000_000 / BAUD; // ns

    // ---------------- UART TX capture ----------------
    reg [7:0] cipher_bytes [0:15];
    reg [7:0] rx_byte;
    integer   rx_count;

    // ---------------- UART SEND TASK ----------------
    task uart_send_byte;
        input [7:0] byte;
        integer i;
        begin
            uart_rx = 1'b0;             // start bit
            #(BIT_TIME);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = byte[i];      // LSB first
                #(BIT_TIME);
            end
            uart_rx = 1'b1;             // stop bit
            #(BIT_TIME);
        end
    endtask

    // ---------------- UART RECEIVE TASK ----------------
    task uart_receive_byte;
        output [7:0] byte;
        integer i;
        begin
            wait (uart_tx == 1'b0);    // wait for start bit
            #(BIT_TIME + BIT_TIME/2);
            for (i = 0; i < 8; i = i + 1) begin
                byte[i] = uart_tx;
                #(BIT_TIME);
            end
            #(BIT_TIME/2);              // stop bit sampling
        end
    endtask

			// ---------------- SEND / RECEIVE AES TASK ----------------
		task run_aes_test;
			input  [127:0] key;
			input  [127:0] block;
			input  [127:0] expected; // optional expected ciphertext
		
			integer i;
			reg [7:0] key_bytes  [0:15];
			reg [7:0] block_bytes[0:15];
			reg [127:0] cipher_combined;
			integer k;
		
		begin
			// Split 128-bit key/block into bytes
			for (i = 0; i < 16; i = i + 1) begin
				key_bytes[i]   = key  [127 - i*8 -: 8];
				block_bytes[i] = block[127 - i*8 -: 8];
			end
		
			rx_count = 0;
		
			// Send AES key
			for (i = 0; i < 16; i = i + 1)
				uart_send_byte(key_bytes[i]);
			#(BIT_TIME * 5);
		
			// Send plaintext block
			for (i = 0; i < 16; i = i + 1)
				uart_send_byte(block_bytes[i]);
		
			// Receive ciphertext
			while (rx_count < 16) begin
				uart_receive_byte(rx_byte);
				cipher_bytes[rx_count] = rx_byte;
				$display("RX[%0d] = %02x", rx_count, rx_byte);
				rx_count = rx_count + 1;
			end
		
		
			//---------------------------------------------
			// Print ciphertext
			//---------------------------------------------
			$display("\n=== AES-128 CIPHERTEXT ===");
			$write("%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x\n",
				cipher_bytes[0],  cipher_bytes[1],  cipher_bytes[2],  cipher_bytes[3],
				cipher_bytes[4],  cipher_bytes[5],  cipher_bytes[6],  cipher_bytes[7],
				cipher_bytes[8],  cipher_bytes[9],  cipher_bytes[10], cipher_bytes[11],
				cipher_bytes[12], cipher_bytes[13], cipher_bytes[14], cipher_bytes[15]
			);
		
		
			//---------------------------------------------
			// Rebuild 128-bit cipher_combined
			//---------------------------------------------
			cipher_combined = 128'h0;
			for (k = 0; k < 16; k = k + 1)
				cipher_combined[127 - 8*k -: 8] = cipher_bytes[k];
		
		
			//---------------------------------------------
			// Expected output
			//---------------------------------------------
			if (expected !== 128'h0) begin
				$display("Expected:");
				$display("%032x", expected);
			end
		
		
			//---------------------------------------------
			// Compare
			//---------------------------------------------
			if (cipher_combined === expected)
				$display("CORRECT");
			else
				$display("INCORRECT");
		
		end
		endtask


    // ---------------- MAIN TEST ----------------
    initial begin
        clk = 0;
        rst_n = 0;
        uart_rx = 1'b1;
        init_accel = 0;
        dec = 0;  // encryption

        // Reset DUT
        #200;
        rst_n = 1;
        #200;

        // Start system
        init_accel = 1;
        #40;
		  	$display("----------------------------------------------");
			$display("-----------Encryption TESTING-----------------");
			$display("----------------------------------------------");

        // ---------- RUN MULTIPLE AES ENcryption TESTS ----------
		  $display("--------------------Begin new TEST--------------------------");
        run_aes_test(128'h2b7e151628aed2a6abf7158809cf4f3c, //key
                     128'h6bc1bee22e409f96e93d7e117393172a, //block
                     128'h3ad77bb40d7a3660a89ecaf32466ef97);//expected 
							
		  $display("--------------------Begin new TEST--------------------------");
        run_aes_test(128'h2b7e151628aed2a6abf7158809cf4f3c, 
                     128'hae2d8a571e03ac9c9eb76fac45af8e51, 
                     128'hf5d3d58503b9699de785895a96fdbaaf);
							
		  $display("--------------------Begin new TEST--------------------------");
        run_aes_test(128'h2b7e151628aed2a6abf7158809cf4f3c, 
                     128'h30c81c46a35ce411e5fbc1191a0a52ef, 
                     128'h43b1cd7f598ece23881b00e3ed030688);
							
		  $display("--------------------Begin new TEST--------------------------");
        run_aes_test(128'h2b7e151628aed2a6abf7158809cf4f3c, 
                     128'hf69f2445df4f9b17ad2b417be66c3710, 
                     128'h7b0c785e27e8ad3f8223207104725dd4);
			
			// ---------- RUN MULTIPLE AES Decryption TESTS ----------
			$display("----------------------------------------------");
			$display("-----------Decryption TESTING-----------------");
			$display("----------------------------------------------");
			#40;
			dec = 1;  // decryption
			#40;
        // ---------- RUN MULTIPLE AES ENcryption TESTS ----------
		  $display("--------------------Begin new TEST--------------------------");
        run_aes_test(128'h2b7e151628aed2a6abf7158809cf4f3c, //key
                     128'h3ad77bb40d7a3660a89ecaf32466ef97, //block
                     128'h6bc1bee22e409f96e93d7e117393172a);//expected 

		  $display("--------------------Begin new TEST--------------------------");
        run_aes_test(128'h2b7e151628aed2a6abf7158809cf4f3c, 
                     128'hf5d3d58503b9699de785895a96fdbaaf, 
                     128'hae2d8a571e03ac9c9eb76fac45af8e51);
							
		  $display("--------------------Begin new TEST--------------------------");		
        run_aes_test(128'h2b7e151628aed2a6abf7158809cf4f3c, 
                     128'h43b1cd7f598ece23881b00e3ed030688, 
                     128'h30c81c46a35ce411e5fbc1191a0a52ef);
							
		  $display("--------------------Begin new TEST--------------------------");	
        run_aes_test(128'h2b7e151628aed2a6abf7158809cf4f3c, 
                     128'h7b0c785e27e8ad3f8223207104725dd4, 
                     128'hf69f2445df4f9b17ad2b417be66c3710);			
        #200;
        $stop;
    end

endmodule
