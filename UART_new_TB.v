`timescale 1ns/1ps

module UART_new_TB;

    // ---------------- DUT signals ----------------
    reg  clk;
    reg  rst_n;
    reg  uart_rx;
    wire uart_tx;

    // ---------------- Clock (50 MHz) ----------------
    always #10 clk = ~clk;

    // ---------------- Instantiate DUT ----------------
    aes_uart_top #(
        .KEY_SIZE (256),
        .DOP      (1),
        .MODE     (7),
		  .FIXED_VARKEY_MODE(0)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .uart_rx (uart_rx),
        .uart_tx (uart_tx)
    );



    // ---------------- UART PARAMETERS ----------------
    parameter CLK_FREQ = 50_000_000;
    parameter BAUD     = 921600;
    parameter BIT_TIME = 1_000_000_000 / BAUD; // ns

    // ---------------- RX storage ----------------
    reg [7:0] rx_byte;
    reg [7:0] rx_block [0:15];
    integer rx_count;
    integer block_index;
    integer blocks_received;
    reg rx_enable;

    // ---------------- TX storage (what we are sending) ----------------
    reg [7:0] tx_byte;

    // ---------------- UART SEND BYTE ----------------
    task uart_send_byte;
        input [7:0] byte;
        integer i;
        begin
            tx_byte = byte;
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

    // ---------------- UART RECEIVE BYTE ----------------
    task uart_receive_byte;
        output [7:0] byte;
        integer i;
        begin
            wait (uart_tx == 1'b0);     // wait for start bit
            #(BIT_TIME + BIT_TIME/2);
            for (i = 0; i < 8; i = i + 1) begin
                byte[i] = uart_tx;
                #(BIT_TIME);
            end
            #(BIT_TIME/2);
        end
    endtask

    // ---------------- SEND VARIABLE BYTE STREAM (Quartus-safe) ----------------
    // data packed: MSB = first byte sent
    task send_bytes;
        input integer length;
        input [2047:0] data; // up to 256 bytes
        integer i;
        reg [7:0] byte;
        begin
            for (i = 0; i < length; i = i + 1) begin
                byte = data[2047 - i*8 -: 8];
                uart_send_byte(byte);
            end
        end
    endtask

    // ---------------- SEND 128-bit BLOCK ----------------
    task send_block_128;
        input [127:0] block;
        integer i;
        reg [7:0] bytes [0:15];
        begin
            // Split into bytes (MSB first)
            for (i = 0; i < 16; i = i + 1)
                bytes[i] = block[127 - i*8 -: 8];

            for (i = 0; i < 16; i = i + 1)
                uart_send_byte(bytes[i]);

            #(BIT_TIME * 5);
        end
    endtask

    // ---------------- SEND 192-bit KEY (24 bytes) ----------------
    task send_key_192;
        input [191:0] key;
        integer i;
        reg [7:0] b;
        begin
            for (i = 0; i < 24; i = i + 1) begin
                b = key[191 - i*8 -: 8];   // MSB first
                uart_send_byte(b);
            end
            #(BIT_TIME * 5);
        end
    endtask

    // ---------------- SEND 256-bit KEY (32 bytes) ----------------
    task send_key_256;
        input [255:0] key;
        integer i;
        reg [7:0] b;
        begin
            for (i = 0; i < 32; i = i + 1) begin
                b = key[255 - i*8 -: 8];   // MSB first
                uart_send_byte(b);
            end
            #(BIT_TIME * 5);
        end
    endtask

    // ---------------- BACKGROUND RX LISTENER ----------------
    initial begin
        rx_count        = 0;
        block_index     = 0;
        blocks_received = 0;
        rx_enable       = 1;

        forever begin
            if (rx_enable) begin
                uart_receive_byte(rx_byte);

                rx_block[rx_count] = rx_byte;
                $display("RX[%0d] = %02x", rx_count, rx_byte);

                rx_count = rx_count + 1;

                if (rx_count == 16) begin
                    $display("---- Received block %0d ----", block_index);
                    $write("%02x%02x%02x%02x%02x%02x%02x%02x",
                        rx_block[0], rx_block[1], rx_block[2], rx_block[3],
                        rx_block[4], rx_block[5], rx_block[6], rx_block[7]);
                    $write("%02x%02x%02x%02x%02x%02x%02x%02x\n",
                        rx_block[8], rx_block[9], rx_block[10], rx_block[11],
                        rx_block[12], rx_block[13], rx_block[14], rx_block[15]);

                    rx_count = 0;
                    block_index = block_index + 1;
                    blocks_received = blocks_received + 1;
                end
            end
        end
    end

    // ---------------- RECEIVE N BLOCKS (wait only) ----------------
    task receive_blocks;
        input integer num_blocks;
        begin
            wait (blocks_received >= num_blocks);
        end
    endtask

    // ---------------- MAIN TEST ----------------
    initial begin
        clk     = 0;
        rst_n   = 0;
        uart_rx = 1'b1;

        // Reset
        #200;
        rst_n = 1;
        #200;


        // ---------------- Key (choose ONE) ----------------

        // ===== AES-128 =====
        // send_block_128(128'h2B7E151628AED2A6ABF7158809CF4F3C);

        // ===== AES-192 (24 bytes) =====
        // send_key_192(192'h8E73B0F7DA0E6452C810F32B809079E562F8EAD2522C6B7B);

        // ===== AES-256 (32 bytes) =====
       /* send_key_256(
            256'h603DEB1015CA71BE2B73AEF0857D7781
                 1F352C073B6108D72D9810A30914DFF4
        );

        uart_rx = 1'b1;
*/
    /*  // ---------------- IV ----------------
		  $display("---- UART AES TEST ----");

        // ---------------- Header ----------------
        uart_send_byte(8'h01); // cmd
		  #200;
		  uart_rx = 1'b1;
		  
        uart_send_byte(8'b00000000); // flags
		  #200;
		  uart_rx = 1'b1;
		  
        uart_send_byte(8'h05); // length = 32 bytes (2 blocks)
		  #200
		  uart_rx = 1'b1;	
		  
        // ---------------- Key ----------------
       send_key_256(256'h2B7E151628AED2A6ABF7158809CF4F3C);
       // send_key_192(192'h8E73B0F7DA0E6452C810F32B809079E562F8EAD2522C6B7B);
		 
     //  send_key_256(256'h603DEB1015CA71BE2B73AEF0857D77811F352C073B6108D72D9810A30914DFF4);
			uart_rx = 1'b1;
        // ---------------- Block 1 ----------------
       //send_block_128(128'h000102030405060708090A0B0C0D0E0F); // iv 
       //send_block_128(128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF); // iv 
		//	uart_rx = 1'b1;
        // ---------------- Block 2 ----------------
        send_block_128(128'h6BC1BEE22E409F96E93D7E117393172A);
			uart_rx = 1'b1;
       // ---------------- Block 3 ----------------
        send_block_128(128'hAE2D8A571E03AC9C9EB76FAC45AF8E51);
			uart_rx = 1'b1;
        // ---------------- Block 4 ----------------
        send_block_128(128'h30C81C46A35CE411E5FBC1191A0A52EF);
			uart_rx = 1'b1;
        // ---------------- Block 5 ----------------
			send_block_128(128'hF69F2445DF4F9B17AD2B417BE66C3710);
			uart_rx = 1'b1;
        // ---------------- Block 6 ----------------
        send_block_128(128'h10101010101010101010101010101010);
			uart_rx = 1'b1;
        // ---------------- Receive result (2 blocks) ----------------
	 
        receive_blocks(5);

*/
 		$display("---- UART AES TEST ----");

        // ---------------- Header ----------------
        uart_send_byte(8'h06); // CMD
		  #200;
		  uart_rx = 1'b1;
       /* uart_send_byte(8'b00001000); // FLAGS
		  #200;
		  uart_rx = 1'b1;
        uart_send_byte(8'h05); // length = 32 bytes (2 blocks)
		  #200
		  uart_rx = 1'b1;	
		  */
        // ---------------- Key ----------------
        send_key_256(256'd7);
	   	  uart_rx = 1'b1;
		  send_key_256(256'd9);
	   	  uart_rx = 1'b1;
        // ---------------- Block 1 ----------------
       // send_block_128(128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF); // iv 
		//	uart_rx = 1'b1;
        // ---------------- Block 2 ----------------
   /*     send_block_128(128'h3ad77bb40d7a3660a89ecaf32466ef97);
			uart_rx = 1'b1;
			
        // ---------------- Block 3 ----------------
        send_block_128(128'hf5d3d58503b9699de785895a96fdbaaf);
			uart_rx = 1'b1;
        // ---------------- Block 4 ----------------
        send_block_128(128'h43b1cd7f598ece23881b00e3ed030688);
			uart_rx = 1'b1;
        // ---------------- Block 5 ----------------
			send_block_128(128'h7b0c785e27e8ad3f8223207104725dd4);
			uart_rx = 1'b1;
        // ---------------- Block 6 ----------------
      //  send_block_128(128'ha254be88e037ddd9d79fb6411c3f9df8);
			//uart_rx = 1'b1;
        // ---------------- Receive result (2 blocks) ----------------
	*/
        receive_blocks(2);
		  
//#1000000;
        $stop;
    end

endmodule