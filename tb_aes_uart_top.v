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
    localparam integer KEY_SIZE_TB = 128;

    aes_uart_top #(
        .KEY_SIZE(KEY_SIZE_TB),
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
    // CONSTANTS
    // ============================================================
    localparam [7:0] CMD_AES       = 8'h01;
    localparam [7:0] CMD_BLOCK_LAB = 8'h02;

    // flags: [2:0]=mode, [3]=dec, [5:4]=len_format
    localparam [7:0] FLAGS_ENC_ECB_LEN1 = 8'b00_00_0_000;
    localparam [7:0] FLAGS_DEC_ECB_LEN1 = 8'b00_00_1_000;

    // rounds derived from KEY_SIZE_TB (matches tx_fsm logic)
    localparam integer Nr_TB =
        (KEY_SIZE_TB == 128) ? 10 :
        (KEY_SIZE_TB == 192) ? 12 :
        (KEY_SIZE_TB == 256) ? 14 : 0;

    localparam integer ROUND_STATES_TB = Nr_TB + 1;

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
    // RUN AES FRAME (TX DATA-ONLY FORMAT)
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
        reg [7:0]   b;

        reg [127:0] rx_block1;
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
        // SEND RX FRAME (unchanged)
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

        // --------------------------------------------------------
        // >>> ADD SMALL GAP BETWEEN BLOCK1 AND BLOCK2 <<<
        // --------------------------------------------------------
        if (len_value > 16) begin
            rx_valid = 1'b0;
            rx_byte  = 8'h00;
            repeat (100) @(posedge clk);   // << change 10 to desired gap cycles
        end

        // DATA BLOCK 2 (if any)
        if (len_value > 16)
            for (i = 0; i < 16; i = i + 1)
                send_byte(data_block2[127 - 8*i -: 8]);

        // --------------------------------------------------------
        // RECEIVE TX PAYLOAD ONLY (NEW FORMAT)
        // --------------------------------------------------------
        if (cmd == CMD_BLOCK_LAB) begin
            $display("---- ROUND DUMP (%0d states) ----", ROUND_STATES_TB);
            for (r = 0; r < ROUND_STATES_TB; r = r + 1) begin
                round_state = 128'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    recv_byte(b);
                    round_state = (round_state << 8) | b;
                end
                $display("ROUND[%0d]        = %032x", r, round_state);
            end
            $display("--------------------------------");
        end

        // Receive final 16-byte result
        rx_block1 = 128'd0;
        for (i = 0; i < 16; i = i + 1) begin
            recv_byte(b);
            rx_block1 = (rx_block1 << 8) | b;
        end
        $display("TX_RESULT BLOCK  = %032x", rx_block1);

        // --------------------------------------------------------
        // CHECK (checks final result)
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

        run_aes_frame(
            CMD_AES,
            FLAGS_ENC_ECB_LEN1,
            1,
            32'd32,
            128'h2b7e151628aed2a6abf7158809cf4f3c,
            128'h6bc1bee22e409f96e93d7e117393172a,
            128'h00112233445566778899aabbccddeeff,
            128'h00112233445566778899aabbccddeeff
        );

        #200;
        $stop;
    end

endmodule
