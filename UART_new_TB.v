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

    // ---------------- UART RX capture ----------------
    reg [7:0] rx_byte;

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
            wait (uart_tx == 1'b0);     // wait for start bit
            #(BIT_TIME + BIT_TIME/2);
            for (i = 0; i < 8; i = i + 1) begin
                byte[i] = uart_tx;
                #(BIT_TIME);
            end
            #(BIT_TIME/2);              // stop bit
        end
    endtask

    // ---------------- SEND FULL FRAME TASK ----------------
    task send_full_frame;
        input [127:0] key;
        input [127:0] block;

        integer i;
        reg [7:0] key_bytes   [0:15];
        reg [7:0] block_bytes [0:15];

        begin
            // Split key and block into bytes
            for (i = 0; i < 16; i = i + 1) begin
                key_bytes[i]   = key  [127 - i*8 -: 8];
                block_bytes[i] = block[127 - i*8 -: 8];
            end

            // ---------------- Header ----------------
            uart_send_byte(8'h02);
            uart_send_byte(8'h00);
            uart_send_byte(8'h10);

            // ---------------- Key ----------------
            for (i = 0; i < 16; i = i + 1)
                uart_send_byte(key_bytes[i]);

            // Small gap
            #(BIT_TIME * 5);

            // ---------------- Block ----------------
            for (i = 0; i < 16; i = i + 1)
                uart_send_byte(block_bytes[i]);
        end
    endtask

    // ---------------- MAIN TEST ----------------
    initial begin
        clk     = 0;
        rst_n   = 0;
        uart_rx = 1'b1;   // idle high

        // Reset
        #200;
        rst_n = 1;
        #200;

        $display("---- UART AES FRAME TEST ----");

        send_full_frame(
            128'h2B7E151628AED2A6ABF7158809CF4F3C, // key
            128'h6BC1BEE22E409F96E93D7E117393172A  // block
        );

        // Optionally capture returned bytes
        repeat (160) begin
            uart_receive_byte(rx_byte);
            $display("RX = %02x", rx_byte);
        end

        #1000;
        $stop;
    end

endmodule
