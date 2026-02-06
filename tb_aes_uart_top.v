/*`timescale 1ns/1ps

module tb_aes_uart_top;

    // ============================================================
    // CLOCK / RESET
    // ============================================================
    reg clk;
    reg rst_n;
    always #10 clk = ~clk; // 50 MHz

    // ============================================================
    // RX (decoded UART) -> DUT
    // ============================================================
    reg        rx_valid;
    reg [7:0]  rx_byte;

    // ============================================================
    // TX (decoded UART) <- DUT
    // ============================================================
    reg        tx_ready;
    wire       tx_valid;
    wire [7:0] tx_byte;

    // ============================================================
    // DUT
    // ============================================================
    aes_uart_top #(
        .KEY_SIZE(128),
        .DOP(1),
        .MODE(0) // ECB
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx_valid (rx_valid),
        .rx_byte  (rx_byte),
        .tx_ready (tx_ready),
        .tx_valid (tx_valid),
        .tx_byte  (tx_byte)
    );

    // ============================================================
    // CONSTANTS (EDIT HERE)
    // ============================================================
    localparam [7:0] CMD_AES = 8'h01;

    // flags: [2:0]=mode, [3]=dec, [5:4]=len_format
    localparam [7:0] FLAGS_ENC_ECB_LEN1 = 8'b00_00_0_000;
    localparam [7:0] FLAGS_DEC_ECB_LEN1 = 8'b00_00_1_000;

    // ============================================================
    // SEND ONE BYTE (decoded UART style)
    // ============================================================
    task send_byte;
        input [7:0] b;
        begin
            rx_valid = 1'b1;
            rx_byte  = b;
            @(posedge clk);
            rx_valid = 1'b0;
            @(posedge clk);
        end
    endtask

    // ============================================================
    // RECEIVE ONE BYTE (with timeout, NO HANG)
    // ============================================================
    task recv_byte;
        output [7:0] b;
        integer t;
        begin
            t = 0;
            while (!tx_valid) begin
                @(posedge clk);
                t = t + 1;
                if (t > 200000) begin
                    $display("ERROR: TX TIMEOUT");
                    $stop;
                end
            end
            b = tx_byte;
            @(posedge clk);
        end
    endtask

    // ============================================================
    // RUN AES FRAME (THIS IS WHAT YOU EDIT)
    // ============================================================
    task run_aes_frame;
        input [7:0]   cmd;
        input [7:0]   flags;
        input integer len_bytes_num;     // 1..4
        input [31:0]  len_value;         // DATA length
        input [127:0] key;
        input [127:0] data_block1;
        input [127:0] data_block2;       // optional
        input [127:0] expected1;         // optional (0 = skip)

        integer i;
        reg [7:0] b;
        reg [31:0] rx_len;
        integer rx_len_bytes;

        reg [127:0] rx_block1;
        reg [127:0] rx_block2;
    begin
        // --------------------------------------------------------
        // DISPLAY FRAME
        // --------------------------------------------------------
        $display("\n================================================");
        $display("CMD              = 0x%02x", cmd);
        $display("FLAGS            = 0x%02x", flags);
        $display("LEN BYTES NUM    = %0d", len_bytes_num);
        $display("LEN VALUE        = %0d (0x%08x)", len_value, len_value);
        $display("KEY              = %032x", key);
        $display("DATA BLOCK 1     = %032x", data_block1);
        if (len_value > 16)
            $display("DATA BLOCK 2     = %032x", data_block2);
        $display("================================================");

        // --------------------------------------------------------
        // SEND RX FRAME
        // --------------------------------------------------------
        send_byte(cmd);
        send_byte(flags);

        // LENGTH (big-endian)
        for (i = len_bytes_num-1; i >= 0; i = i - 1)
            send_byte(len_value >> (8*i));

        // KEY
        for (i = 0; i < 16; i = i + 1)
            send_byte(key[127 - 8*i -: 8]);

        // DATA BLOCK 1
        for (i = 0; i < 16; i = i + 1)
            send_byte(data_block1[127 - 8*i -: 8]);

        // DATA BLOCK 2 (if any)
        if (len_value > 16)
            for (i = 0; i < 16; i = i + 1)
                send_byte(data_block2[127 - 8*i -: 8]);

        // --------------------------------------------------------
        // RECEIVE TX FRAME
        // --------------------------------------------------------
        recv_byte(b);
        $display("TX_CMD           = 0x%02x", b);

        recv_byte(b);
        $display("TX_FLAGS         = 0x%02x", b);
        rx_len_bytes = b[5:4] + 1;

        rx_len = 0;
        for (i = 0; i < rx_len_bytes; i = i + 1) begin
            recv_byte(b);
            rx_len = (rx_len << 8) | b;
        end
        $display("TX_LEN           = %0d bytes", rx_len);

        // RX DATA BLOCK 1
        rx_block1 = 0;
        for (i = 0; i < 16; i = i + 1) begin
            recv_byte(b);
            rx_block1 = (rx_block1 << 8) | b;
        end
        $display("TX_DATA BLOCK 1  = %032x", rx_block1);

        // RX DATA BLOCK 2
        if (rx_len > 16) begin
            rx_block2 = 0;
            for (i = 0; i < 16; i = i + 1) begin
                recv_byte(b);
                rx_block2 = (rx_block2 << 8) | b;
            end
            $display("TX_DATA BLOCK 2  = %032x", rx_block2);
        end

        // --------------------------------------------------------
        // CHECK
        // --------------------------------------------------------
        if (expected1 !== 128'h0) begin
            if (rx_block1 === expected1)
                $display("RESULT: CORRECT ✅");
            else
                $display("RESULT: INCORRECT ❌");
        end
    end
    endtask

    // ============================================================
    // MAIN
    // ============================================================
    initial begin
        clk      = 0;
        rst_n    = 0;
        rx_valid = 0;
        rx_byte  = 0;
        tx_ready = 1;

        #200;
        rst_n = 1;
        #200;

        // ================= ENCRYPT =================
        run_aes_frame(
            CMD_AES,
            FLAGS_ENC_ECB_LEN1,
            1,
            32'd16,
            128'h2b7e151628aed2a6abf7158809cf4f3c,
            128'h6bc1bee22e409f96e93d7e117393172a,
            128'h3ad77bb40d7a3660a89ecaf32466ef97,
            128'h3ad77bb40d7a3660a89ecaf32466ef97
        );

	 run_aes_frame(
    CMD_AES,
    FLAGS_DEC_ECB_LEN1,
    1,
    32'd16,
    128'h000102030405060708090a0b0c0d0e0f,  // different KEY
    128'h69c4e0d86a7b0430d8cdb78070b4c55a,  // different DATA (ciphertext)
    128'h0,                               // IV unused in ECB
    128'h00112233445566778899aabbccddeeff   // expected plaintext
);

        // ================= DECRYPT =================
 /*       run_aes_frame(
            CMD_AES,
            FLAGS_DEC_ECB_LEN1,
            1,
            32'd16,
            128'h2b7e151628aed2a6abf7158809cf4f3c,
            128'h3ad77bb40d7a3660a89ecaf32466ef97,
            128'h0,
            128'h6bc1bee22e409f96e93d7e117393172a
        );

        #200;
        $stop;
    end

endmodule
*/


`timescale 1ns/1ps

module tb_aes_uart_top;

    // ============================================================
    // CLOCK / RESET
    // ============================================================
    reg clk;
    reg rst_n;
    always #10 clk = ~clk; // 50 MHz

    // ============================================================
    // RX (decoded UART) -> DUT
    // ============================================================
    reg        rx_valid;
    reg [7:0]  rx_byte;

    // ============================================================
    // TX (decoded UART) <- DUT
    // ============================================================
    reg        tx_ready;
    wire       tx_valid;
    wire [7:0] tx_byte;

    // ============================================================
    // DUT
    // ============================================================
    aes_uart_top #(
        .KEY_SIZE(128),
        .DOP(1),
        .MODE(0) // ECB
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx_valid (rx_valid),
        .rx_byte  (rx_byte),
        .tx_ready (tx_ready),
        .tx_valid (tx_valid),
        .tx_byte  (tx_byte)
    );

    // ============================================================
    // CONSTANTS (EDIT HERE)
    // ============================================================
    localparam [7:0] CMD_AES       = 8'h01;
    localparam [7:0] CMD_BLOCK_LAB = 8'h02;

    // flags: [2:0]=mode, [3]=dec, [5:4]=len_format
    localparam [7:0] FLAGS_ENC_ECB_LEN1 = 8'b00_00_0_000;
    localparam [7:0] FLAGS_DEC_ECB_LEN1 = 8'b00_00_1_000;

    // AES-128 rounds: Nr=10 -> 11 states
    localparam integer AES128_ROUND_STATES = 11;

    // ============================================================
    // SEND ONE BYTE (decoded UART style)
    // ============================================================
    task send_byte;
        input [7:0] b;
        begin
            rx_valid = 1'b1;
            rx_byte  = b;
            @(posedge clk);
            rx_valid = 1'b0;
            @(posedge clk);
        end
    endtask

    // ============================================================
    // RECEIVE ONE BYTE (with timeout, NO HANG)
    // ============================================================
    task recv_byte;
        output [7:0] b;
        integer t;
        begin
            t = 0;
            while (!tx_valid) begin
                @(posedge clk);
                t = t + 1;
                if (t > 200000) begin
                    $display("ERROR: TX TIMEOUT");
                    $stop;
                end
            end
            b = tx_byte;
            @(posedge clk);
        end
    endtask

    // ============================================================
    // RUN AES FRAME
    // Supports:
    // - CMD_AES: RX reads 16 bytes result
    // - CMD_BLOCK_LAB: RX reads 11*16 bytes rounds + 16 bytes result
    //   NOTE: LENGTH field stays 16 (your protocol), so TB detects LAB by TX_CMD=0x82
    // ============================================================
    task run_aes_frame;
        input [7:0]   cmd;
        input [7:0]   flags;
        input integer len_bytes_num;     // 1..4
        input [31:0]  len_value;         // DATA length (sent in RX header)
        input [127:0] key;
        input [127:0] data_block1;
        input [127:0] data_block2;       // optional
        input [127:0] expected1;         // optional (0 = skip)

        integer i;
        integer r, j;
        reg [7:0]  b;
        reg [7:0]  tx_cmd_lat;
        reg [31:0] rx_len;
        integer    rx_len_bytes;

        reg [127:0] rx_block1;
        reg [127:0] rx_block2;
        reg [127:0] round_state;
    begin
        // --------------------------------------------------------
        // DISPLAY FRAME
        // --------------------------------------------------------
        $display("\n================================================");
        $display("CMD              = 0x%02x", cmd);
        $display("FLAGS            = 0x%02x", flags);
        $display("LEN BYTES NUM    = %0d", len_bytes_num);
        $display("LEN VALUE        = %0d (0x%08x)", len_value, len_value);
        $display("KEY              = %032x", key);
        $display("DATA BLOCK 1     = %032x", data_block1);
        if (len_value > 16)
            $display("DATA BLOCK 2     = %032x", data_block2);
        $display("================================================");

        // --------------------------------------------------------
        // SEND RX FRAME
        // --------------------------------------------------------
        send_byte(cmd);
        send_byte(flags);

        // LENGTH (big-endian)
        for (i = len_bytes_num-1; i >= 0; i = i - 1)
            send_byte(len_value >> (8*i));

        // KEY (16 bytes for AES-128)
        for (i = 0; i < 16; i = i + 1)
            send_byte(key[127 - 8*i -: 8]);

        // DATA BLOCK 1
        for (i = 0; i < 16; i = i + 1)
            send_byte(data_block1[127 - 8*i -: 8]);

        // DATA BLOCK 2 (if any)
        if (len_value > 16)
            for (i = 0; i < 16; i = i + 1)
                send_byte(data_block2[127 - 8*i -: 8]);

        // --------------------------------------------------------
        // RECEIVE TX FRAME
        // --------------------------------------------------------
        recv_byte(b);
        tx_cmd_lat = b;
        $display("TX_CMD           = 0x%02x", tx_cmd_lat);

        recv_byte(b);
        $display("TX_FLAGS         = 0x%02x", b);
        rx_len_bytes = b[5:4] + 1;

        rx_len = 0;
        for (i = 0; i < rx_len_bytes; i = i + 1) begin
            recv_byte(b);
            rx_len = (rx_len << 8) | b;
        end
        $display("TX_LEN           = %0d bytes", rx_len);

        // --------------------------------------------------------
        // If this is BLOCK_LAB response, dump rounds first
        // TX_CMD should be (CMD_BLOCK_LAB | 8'h80) = 0x82
        // --------------------------------------------------------
        if (tx_cmd_lat == (CMD_BLOCK_LAB | 8'h80)) begin
            $display("---- ROUND DUMP (AES-128: %0d states) ----", AES128_ROUND_STATES);
            for (r = 0; r < AES128_ROUND_STATES; r = r + 1) begin
                round_state = 128'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    recv_byte(b);
                    round_state = (round_state << 8) | b;
                end
                $display("ROUND[%0d]        = %032x", r, round_state);
            end
            $display("----------------------------------------");
        end

        // RX DATA BLOCK 1 (always read final result next)
        rx_block1 = 128'd0;
        for (i = 0; i < 16; i = i + 1) begin
            recv_byte(b);
            rx_block1 = (rx_block1 << 8) | b;
        end
        $display("TX_DATA BLOCK 1  = %032x", rx_block1);

        // Optional RX second block if length says more (not used in your lab mode)
        if (rx_len > 16) begin
            rx_block2 = 128'd0;
            for (i = 0; i < 16; i = i + 1) begin
                recv_byte(b);
                rx_block2 = (rx_block2 << 8) | b;
            end
            $display("TX_DATA BLOCK 2  = %032x", rx_block2);
        end

        // --------------------------------------------------------
        // CHECK (only checks final result block1)
        // --------------------------------------------------------
        if (expected1 !== 128'h0) begin
            if (rx_block1 === expected1)
                $display("RESULT: CORRECT ✅");
            else
                $display("RESULT: INCORRECT ❌");
        end
    end
    endtask

    // ============================================================
    // MAIN
    // ============================================================
    initial begin
        clk      = 0;
        rst_n    = 0;
        rx_valid = 0;
        rx_byte  = 0;
        tx_ready = 1;

        #200;
        rst_n = 1;
        #200;

        // ================= ENCRYPT (BLOCK_LAB: will also print rounds) =================
        run_aes_frame(
            CMD_BLOCK_LAB,
            FLAGS_ENC_ECB_LEN1,
            1,
            32'd16,
            128'h2b7e151628aed2a6abf7158809cf4f3c,
            128'h6bc1bee22e409f96e93d7e117393172a,
            128'h0,
            128'h3ad77bb40d7a3660a89ecaf32466ef97
        );

        // ================= DECRYPT (normal AES command, no rounds printed) =================
 /*       run_aes_frame(
            CMD_AES,
            FLAGS_DEC_ECB_LEN1,
            1,
            32'd16,
            128'h000102030405060708090a0b0c0d0e0f,
            128'h69c4e0d86a7b0430d8cdb78070b4c55a,
            128'h0,
            128'h00112233445566778899aabbccddeeff
        );
*/
        #200;
        $stop;
    end

endmodule
