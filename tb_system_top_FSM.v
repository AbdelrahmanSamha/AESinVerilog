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
            // Start bit
            uart_rx = 1'b0;
            #(BIT_TIME);

            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = byte[i];
                #(BIT_TIME);
            end

            // Stop bit
            uart_rx = 1'b1;
            #(BIT_TIME);
        end
    endtask

    // ---------------- UART RECEIVE TASK ----------------
    task uart_receive_byte;
        output [7:0] byte;
        integer i;
        begin
            // Wait for start bit
            wait (uart_tx == 1'b0);
            #(BIT_TIME + BIT_TIME/2);

            // Sample data bits
            for (i = 0; i < 8; i = i + 1) begin
                byte[i] = uart_tx;
                #(BIT_TIME);
            end

            // Stop bit
            #(BIT_TIME);
        end
    endtask

    // ---------------- MAIN TEST ----------------
    initial begin
        // Init
        clk = 0;
        rst_n = 0;
        uart_rx = 1'b1;
        init_accel = 0;
        dec = 0;  // encryption
        rx_count = 0;

        // Reset
        #200;
        rst_n = 1;
        #200;

        // Start system
        init_accel = 1;
        #40;
        init_accel = 0;

        // ---------- SEND AES KEY ----------
        uart_send_byte(8'h00);
        uart_send_byte(8'h01);
        uart_send_byte(8'h02);
        uart_send_byte(8'h03);
        uart_send_byte(8'h04);
        uart_send_byte(8'h05);
        uart_send_byte(8'h06);
        uart_send_byte(8'h07);
        uart_send_byte(8'h08);
        uart_send_byte(8'h09);
        uart_send_byte(8'h0A);
        uart_send_byte(8'h0B);
        uart_send_byte(8'h0C);
        uart_send_byte(8'h0D);
        uart_send_byte(8'h0E);
        uart_send_byte(8'h0F);

        #(BIT_TIME * 5);

        // ---------- SEND PLAINTEXT ----------
        uart_send_byte(8'h00);
        uart_send_byte(8'h11);
        uart_send_byte(8'h22);
        uart_send_byte(8'h33);
        uart_send_byte(8'h44);
        uart_send_byte(8'h55);
        uart_send_byte(8'h66);
        uart_send_byte(8'h77);
        uart_send_byte(8'h88);
        uart_send_byte(8'h99);
        uart_send_byte(8'hAA);
        uart_send_byte(8'hBB);
        uart_send_byte(8'hCC);
        uart_send_byte(8'hDD);
        uart_send_byte(8'hEE);
        uart_send_byte(8'hFF);

        // ---------- RECEIVE CIPHERTEXT ----------
        while (rx_count < 16) begin
            uart_receive_byte(rx_byte);
            cipher_bytes[rx_count] = rx_byte;
            $display("TX[%0d] = %02x", rx_count, rx_byte);
            rx_count = rx_count + 1;
        end

        // ---------- PRINT RESULT ----------
        $display("\n=== AES-128 CIPHERTEXT ===");
        $display("%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            cipher_bytes[0],  cipher_bytes[1],  cipher_bytes[2],  cipher_bytes[3],
            cipher_bytes[4],  cipher_bytes[5],  cipher_bytes[6],  cipher_bytes[7],
            cipher_bytes[8],  cipher_bytes[9],  cipher_bytes[10], cipher_bytes[11],
            cipher_bytes[12], cipher_bytes[13], cipher_bytes[14], cipher_bytes[15]
        );

        // Reference check (optional manual compare)
        $display("Expected: 69c4e0d86a7b0430d8cdb78070b4c55a");

        #200;
        $stop;
    end

endmodule
