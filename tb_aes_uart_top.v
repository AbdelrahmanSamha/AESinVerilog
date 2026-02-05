`timescale 1ns/1ps

module tb_aes_uart_top;

    // ============================================================
    // CLOCK / RESET
    // ============================================================
    reg clk;
    reg rst_n;

    always #10 clk = ~clk; // 50 MHz

    // ============================================================
    // RX (decoded UART)
    // ============================================================
    reg        rx_valid;
    reg [7:0]  rx_byte;

    // ============================================================
    // TX (decoded UART)
    // ============================================================
    reg        tx_ready;
    wire       tx_valid;
    wire [7:0] tx_byte;

    // ============================================================
    // DUT
    // ============================================================
    aes_uart_top dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx_valid (rx_valid),
        .rx_byte  (rx_byte),
        .tx_ready (tx_ready),
        .tx_valid (tx_valid),
        .tx_byte  (tx_byte)
    );

    // ============================================================
    // CONSTANTS
    // ============================================================
    localparam SOF = 8'hA5;
    localparam EOF = 8'h5A;
    localparam CMD = 8'h01;

    // FLAGS:
    // bit[0] = dec
    // bit[5:4] = 00 -> 1 length byte
    localparam FLAGS_ENC = 8'h00;
    localparam FLAGS_DEC = 8'h01;

    // ============================================================
    // TEST
    // ============================================================
    integer i;
    reg [127:0] rx_cipher;

    initial begin
        // ---------------- INIT ----------------
        clk      = 0;
        rst_n    = 0;
        rx_valid = 0;
        rx_byte  = 0;
        tx_ready = 1;

        #200;
        rst_n = 1;
        #200;

        // ========================================================
        // ENCRYPT FRAME
        // ========================================================

        // SOF
        rx_valid = 1; rx_byte = SOF; @(posedge clk);
        rx_valid = 0; @(posedge clk);

        // CMD
        rx_valid = 1; rx_byte = 8'h00; @(posedge clk);
        rx_valid = 0; @(posedge clk);

        // FLAGS (ENC)
        rx_valid = 1; rx_byte = FLAGS_ENC; @(posedge clk);
        rx_valid = 0; @(posedge clk);

        // LENGTH = 32 bytes (key + block)
        rx_valid = 1; rx_byte = 8'd32; @(posedge clk);
        rx_valid = 0; @(posedge clk);

        // KEY (128-bit)
        rx_byte = 8'h2b; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h7e; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h15; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h16; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h28; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'hae; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'hd2; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'ha6; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'hab; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'hf7; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h15; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h88; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h09; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'hcf; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h4f; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h3c; rx_valid = 1; @(posedge clk); rx_valid = 0;
		 
		
#2000;	
	@(posedge clk);

        // PLAINTEXT
        rx_byte = 8'h6b; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'hc1; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'hbe; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'he2; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h2e; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h40; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h9f; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h96; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'he9; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h3d; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h7e; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h11; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h73; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h93; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h17; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);
        rx_byte = 8'h2a; rx_valid = 1; @(posedge clk); rx_valid = 0; @(posedge clk);

        // EOF
        rx_valid = 1; rx_byte = EOF; @(posedge clk);
        rx_valid = 0; @(posedge clk);

        // ========================================================
        // RECEIVE RESULT
        // ========================================================
        rx_cipher = 0;

        // wait SOF
        wait (tx_valid && tx_byte == SOF); @(posedge clk);

        // CMD / FLAGS / LEN
        repeat (3) begin
            wait (tx_valid); @(posedge clk);
        end

        // PAYLOAD
        for (i = 0; i < 16; i = i + 1) begin
            wait (tx_valid);
            rx_cipher = (rx_cipher << 8) | tx_byte;
            @(posedge clk);
        end

        // EOF
        wait (tx_valid && tx_byte == EOF);

        $display("CIPHER = %032x", rx_cipher);
        $display("EXPECT = 3ad77bb40d7a3660a89ecaf32466ef97");

        #200;
        $stop;
    end

endmodule
