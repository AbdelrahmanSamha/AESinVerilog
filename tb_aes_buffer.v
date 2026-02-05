`timescale 1ns/1ps

module tb_aes_buffer;

    // =====================================================
    // parameters
    // =====================================================
    localparam KEY_SIZE = 128;   // try 192 or 256 also

    // =====================================================
    // DUT signals
    // =====================================================
    reg         clk;
    reg         rst_n;

    reg  [7:0]  byte_in;
    reg         key_we;
    reg         iv_we;
    reg         block_we;

    reg         out_we;
    reg [127:0] aes_out_block;

    wire [KEY_SIZE-1:0] key_reg;
    wire [127:0]        iv_reg;
    wire [127:0]        block_reg;
    wire [127:0]        out_block;

    wire key_ready;
    wire iv_ready;
    wire block_ready;

    // =====================================================
    // DUT
    // =====================================================
    aes_buffer #(
        .KEY_SIZE(KEY_SIZE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .byte_in(byte_in),
        .key_we(key_we),
        .iv_we(iv_we),
        .block_we(block_we),

        .out_we(out_we),
        .aes_out_block(aes_out_block),

        .key_reg(key_reg),
        .iv_reg(iv_reg),
        .block_reg(block_reg),
        .out_block(out_block),

        .key_ready(key_ready),
        .iv_ready(iv_ready),
        .block_ready(block_ready)
    );

    // =====================================================
    // clock
    // =====================================================
    always #5 clk = ~clk;   // 100 MHz

    // =====================================================
    // test sequence
    // =====================================================
    integer i;

    initial begin
        // init
        clk = 0;
        rst_n = 0;

        byte_in  = 8'h00;
        key_we   = 0;
        iv_we    = 0;
        block_we = 0;
        out_we   = 0;
        aes_out_block = 128'h0;

        // reset
        #20;
        rst_n = 1;

        // ================= LOAD KEY (128-bit = 16 bytes) =================
        $display("Loading KEY...");
        for (i = 0; i < KEY_SIZE/8; i = i + 1) begin
            @(posedge clk);
            key_we  <= 1'b1;
            byte_in <= i;          // test pattern: 00 01 02 ...
        end
        @(posedge clk);
        key_we <= 1'b0;

        #10;
        $display("KEY_READY=%0d  KEY=0x%h", key_ready, key_reg);

        // ================= LOAD IV (16 bytes) =================
        $display("Loading IV...");
        for (i = 0; i < 16; i = i + 1) begin
            @(posedge clk);
            iv_we   <= 1'b1;
            byte_in <= 8'hA0 + i;
        end
        @(posedge clk);
        iv_we <= 1'b0;

        #10;
        $display("IV_READY=%0d  IV=0x%h", iv_ready, iv_reg);

        // ================= LOAD DATA BLOCK (16 bytes) =================
        $display("Loading DATA block...");
        for (i = 0; i < 16; i = i + 1) begin
            @(posedge clk);
            block_we <= 1'b1;
            byte_in  <= 8'h10 + i;
        end
        @(posedge clk);
        block_we <= 1'b0;

        #10;
        $display("BLOCK_READY=%0d  BLOCK=0x%h", block_ready, block_reg);

        // ================= STORE AES OUTPUT (one-shot) =================
        $display("Writing AES output block...");
        @(posedge clk);
        aes_out_block <= 128'h00112233445566778899AABBCCDDEEFF;
        out_we <= 1'b1;

        @(posedge clk);
        out_we <= 1'b0;

        #10;
        $display("OUT_BLOCK=0x%h", out_block);

        // done
        #50;
        $finish;
    end

endmodule
