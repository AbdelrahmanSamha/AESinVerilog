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
    aes_uart_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx)
    );

    // ---------------- UART PARAMETERS ----------------
    parameter CLK_FREQ = 50_000_000;
    parameter BAUD     = 115200;
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
		  #10000

        $display("---- UART AES TEST ----");
/*
        // ---------------- Header ----------------
        uart_send_byte(8'h01); // SOF
		  #200;
		  uart_rx = 1'b1;
        uart_send_byte(8'h00); // CMD
		  #200;
		  uart_rx = 1'b1;
        uart_send_byte(8'h20); // length = 32 bytes (2 blocks)
		  #200
		  uart_rx = 1'b1;	
        // ---------------- Key ----------------
        send_block_128(128'h2B7E151628AED2A6ABF7158809CF4F3C);
			uart_rx = 1'b1;
        // ---------------- Block 1 ----------------
        send_block_128(128'h6BC1BEE22E409F96E93D7E117393172A);
			uart_rx = 1'b1;
        // ---------------- Block 2 ----------------
        send_block_128(128'h10101010101010101010101010101010);
			uart_rx = 1'b1;
        // ---------------- Receive result (2 blocks) ----------------
        receive_blocks(2);

        #10000;
		  
		  */
/*
		  $display("---- UART AES TEST ----");

        // ---------------- Header ----------------
        uart_send_byte(8'h01); // SOF
		  #200;
		  uart_rx = 1'b1;
        uart_send_byte(8'b00000000); // CMD
		  #200;
		  uart_rx = 1'b1;
        uart_send_byte(8'h50); // length = 32 bytes (2 blocks)
		  #200
		  uart_rx = 1'b1;	
        // ---------------- Key ----------------
        send_block_128(128'h2B7E151628AED2A6ABF7158809CF4F3C);
			uart_rx = 1'b1;
        // ---------------- Block 1 ----------------
        send_block_128(128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF); // iv 
			uart_rx = 1'b1;
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
        uart_send_byte(8'h01); // SOF
		  #200;
		  uart_rx = 1'b1;
        uart_send_byte(8'b00001000); // CMD
		  #200;
		  uart_rx = 1'b1;
        uart_send_byte(8'h50); // length = 32 bytes (2 blocks)
		  #200
		  uart_rx = 1'b1;	
        // ---------------- Key ----------------
        send_block_128(128'h2B7E151628AED2A6ABF7158809CF4F3C);
			uart_rx = 1'b1;
        // ---------------- Block 1 ----------------
        send_block_128(128'hF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF); // iv 
			uart_rx = 1'b1;
        // ---------------- Block 2 ----------------
        send_block_128(128'h874d6191b620e3261bef6864990db6ce);
			uart_rx = 1'b1;
        // ---------------- Block 3 ----------------
        send_block_128(128'h9806f66b7970fdff8617187bb9fffdff);
			uart_rx = 1'b1;
        // ---------------- Block 4 ----------------
        send_block_128(128'h5ae4df3edbd5d35e5b4f09020db03eab);
			uart_rx = 1'b1;
        // ---------------- Block 5 ----------------
			send_block_128(128'h1e031dda2fbe03d1792170a0f3009cee);
			uart_rx = 1'b1;
        // ---------------- Block 6 ----------------
        send_block_128(128'ha01d57e8049a811ee0782087805bb512);
			uart_rx = 1'b1;
        // ---------------- Receive result (2 blocks) ----------------
        receive_blocks(5);
		  
	$stop;
    end

endmodule
