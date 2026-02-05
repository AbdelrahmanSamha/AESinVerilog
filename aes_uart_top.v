module aes_uart_top #(
    parameter integer KEY_SIZE = 128,
    parameter integer DOP      = 1,
    parameter integer MODE     = 0
)(
    input  wire        clk,
    input  wire        rst_n,

    // ================= UART RX =================
    input  wire        rx_valid,
    input  wire [7:0]  rx_byte,

    // ================= UART TX =================
    input  wire        tx_ready,
    output wire        tx_valid,
    output wire [7:0]  tx_byte
);

    // ============================================================
    // RX FSM → BUFFER control signals
    // ============================================================
    wire        aes_start;
    wire        key_we, iv_we, block_we;
    wire        dec;

    // ============================================================
    // BUFFER → AES signals
    // ============================================================
    wire [KEY_SIZE-1:0] key_reg;
    wire [127:0]        iv_reg;
    wire [127:0]        block_reg;

    wire key_ready;
    wire iv_ready;
    wire block_ready;
	 
    wire valid_d_in;
	 
	 wire key_expand_ready;
	 wire valid_in_key_aes;
	 wire valid_in_block_aes;

    // ============================================================
    // AES → TX signals
    // ============================================================
    wire [127:0] aes_out;
    wire         aes_done;

    // ============================================================
    // RX CONTROL FSM
    // ============================================================
    control_fsm_rx #(
        .KEY_SIZE(KEY_SIZE),
        .MODE(MODE)
    ) u_rx_fsm (
        .clk        (clk),
        .rst_n      (rst_n),

        .rx_valid   (rx_valid),
        .rx_byte    (rx_byte),
		  
        .aes_start_out  (aes_start),
        .aes_data_in(),

        .key_we     (key_we),
        .iv_we      (iv_we),
        .block_we   (block_we),
		  
		  
        .key_ready  (key_ready),
        .iv_ready   (iv_ready),
        .block_ready(block_ready),

        .dec        (dec),
		
		  .key_expand_ready(key_expand_ready),
		 
		  .valid_in_key_aes(valid_in_key_aes),
		  .valid_in_block_aes(valid_in_block_aes)

    );

    // ============================================================
    // AES BYTE BUFFER
    // ============================================================
    aes_buffer #(
        .KEY_SIZE(KEY_SIZE)
    ) u_buffer (
        .clk        (clk),
        .rst_n      (rst_n),

        .byte_in    (rx_byte),

        .key_we     (key_we),
        .iv_we      (iv_we),
        .block_we   (block_we),

        .out_we     (aes_done),
        .aes_out_block (aes_out),

        .key_reg    (key_reg),
        .iv_reg     (iv_reg),
        .block_reg  (block_reg),
        .out_block  (),

        .key_ready  (key_ready),
        .iv_ready   (iv_ready),
        .block_ready(block_ready)
    );

    // ============================================================
    // AES CORE
    // ============================================================
    aes_top #(
        .KEY_SIZE(KEY_SIZE),
        .DOP     (DOP),
        .MODE    (MODE)
    ) u_aes (
        .clk        (clk),
        .rst_n      (rst_n),

        .init       (aes_start),          // start key expansion
        .dec        (dec),
       // .valid_din  (),

        .og_key     (key_reg),
        .text_in    (block_reg),

        .terminate_session (1'b0),

        .text_out   (aes_out),
        .valid_dout (aes_done),
		  
		  .key_expand_ready(key_expand_ready),

		  .valid_in_key_aes(valid_in_key_aes),
		  .valid_in_block_aes(valid_in_block_aes)
    );

    // ============================================================
    // TX CONTROL FSM
    // ============================================================
    control_fsm_tx u_tx_fsm (
        .clk        (clk),
        .rst_n      (rst_n),

        .tx_ready   (tx_ready),
        .tx_valid   (tx_valid),
        .tx_byte    (tx_byte),

        .aes_done   (aes_done),
        .aes_result (aes_out),

        .error_flag (1'b0)
    );

endmodule
