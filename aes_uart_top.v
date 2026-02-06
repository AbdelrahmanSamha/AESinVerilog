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
    // RX FSM → BUFFER control signals (from core)
    // ============================================================
    wire        aes_start;
    wire        dec;
    wire        valid_in_key_aes;
    wire        valid_in_block_aes;

    // ============================================================
    // RX FSM <-> BUFFER wires (DECLARE ALL)
    // ============================================================
    wire        buf_cmd_we;
    wire        buf_flags_we;
    wire        buf_len_we;

    wire        buf_key_we;
    wire        buf_iv_we;
    wire        buf_block_we;

    wire [31:0] buf_data_addr;
    wire [7:0]  buf_wbyte;

    wire [7:0]  rx_cmd;
    wire [7:0]  rx_flags;
    wire [31:0] rx_length;

    wire        rx_commit;
    wire        rx_done;

    // ============================================================
    // BUFFER stored regs + ready pulses (DECLARE ALL)
    // ============================================================
    wire [7:0]          cmd_reg;
    wire [7:0]          flags_reg;
    wire [31:0]         length_reg;

    wire                cmd_ready;
    wire                flags_ready;
    wire                length_ready;

    // ============================================================
    // BUFFER → AES signals
    // ============================================================
    wire [KEY_SIZE-1:0] key_reg;
    wire [127:0]        iv_reg;
    wire [127:0]        block_reg;

    wire                key_ready;
    wire                iv_ready;
    wire                block_ready;

    // ============================================================
    // optional: buffer capture of AES output (DECLARE ALL)
    // ============================================================
    wire                out_we;
    wire [127:0]        aes_out_block;
    wire [127:0]        out_block;

    // ============================================================
    // AES → TX signals
    // ============================================================
    wire [DOP*128-1:0]  aes_out_bus;
    wire [127:0]        aes_out;
    wire                aes_done;
    wire                key_expand_ready;
	 
	 wire aes_rst;

    assign aes_out = aes_out_bus[127:0];

    // capture output in buffer if you want (optional)
    assign out_we        = aes_done;
    assign aes_out_block = aes_out;
	 
	 
	 wire [127:0] round_mem_out;
	 wire [127:0] next_encstate_out;
	 wire [3:0] round_counter_out;
	 wire [3:0] round_rd_addr;
	 wire [3:0] round_mem_address;
	 wire round_mem_we;
	 wire round_mem_sel;

    // ============================================================
    // RX FSM
    // ============================================================
    rx_fsm #(
        .KEY_SIZE(KEY_SIZE),
        .MODE    (MODE)
    ) u_rx_fsm (
        .clk        (clk),
        .reset_n    (rst_n),

        .rx_valid   (rx_valid),
        .rx_byte    (rx_byte),

        // buffer write strobes
        .buf_cmd_we    (buf_cmd_we),
        .buf_flags_we  (buf_flags_we),
        .buf_len_we    (buf_len_we),

        .buf_key_we    (buf_key_we),
        .buf_iv_we     (buf_iv_we),
        .buf_data_we   (buf_block_we),

        .buf_data_addr (buf_data_addr),
        .buf_wbyte     (buf_wbyte),

        // parsed header values (optional)
        .cmd_out     (rx_cmd),
        .flags_out   (rx_flags),
        .length_out  (rx_length),

        .buf_commit  (rx_commit),
        .rx_done     (rx_done)
    );

    // ============================================================
    // AES BYTE BUFFER
    // ============================================================
    aes_buffer #(
        .KEY_SIZE(KEY_SIZE)
    ) u_buf (
        .clk        (clk),
        .rst_n      (rst_n),

        .byte_in    (buf_wbyte),

        // header (1-cycle)
        .cmd_we     (buf_cmd_we),
        .flags_we   (buf_flags_we),
        .length_we  (buf_len_we),
        .length_in  (rx_length),

        // payload byte streams
        .key_we     (buf_key_we),
        .iv_we      (buf_iv_we),
        .block_we   (buf_block_we),

        // AES output capture (optional)
        .out_we         (out_we),
        .aes_out_block  (aes_out_block),

        // stored regs
        .cmd_reg    (cmd_reg),
        .flags_reg  (flags_reg),
        .length_reg (length_reg),

        .key_reg    (key_reg),
        .iv_reg     (iv_reg),
        .block_reg  (block_reg),
        .out_block  (out_block),

        // status
        .cmd_ready    (cmd_ready),
        .flags_ready  (flags_ready),
        .length_ready (length_ready),

        .key_ready    (key_ready),
        .iv_ready     (iv_ready),
        .block_ready  (block_ready)
    );

    // ============================================================
    // CORE CONTROL FSM (header gating + blk_sent protection)
    // ============================================================
    core_fsm #(
        .MODE    (MODE)
    ) u_core (
        .clk        (clk),
        .rst_n      (rst_n),

        .cmd_ready    (cmd_ready),
        .flags_ready  (flags_ready),
        .length_ready (length_ready),

        .cmd_reg      (cmd_reg),
        .flags_reg    (flags_reg),
        .length_reg   (length_reg),

        .key_ready    (key_ready),
        .iv_ready     (iv_ready),
        .block_ready  (block_ready),

        .key_expand_ready (key_expand_ready),
        .aes_done         (aes_done),

        .aes_start        (aes_start),
        .dec              (dec),
        .valid_in_key_aes (valid_in_key_aes),
        .valid_in_block_aes(valid_in_block_aes),
		  .aes_rst(aes_rst)

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
        .rst_n      (rst_n && aes_rst),

        .init       (aes_start),
        .dec        (dec),

        .valid_in_key_aes   (valid_in_key_aes),
        .valid_in_block_aes (valid_in_block_aes),

        .og_key     (key_reg),
        .text_in    (block_reg),

        .terminate_session (1'b0),

        .text_out   (aes_out_bus),
        .valid_dout (aes_done),

        .key_expand_ready (key_expand_ready),
		  
		  .next_encstate_out(next_encstate_out),
		  .round_counter_out(round_counter_out),
		  .round_mem_we(round_mem_we)
    );

	 
    // ============================================================
    // aes_round_mem
    // ============================================================
	 
	 aes_round_mem	aes_round_mem_inst (
		.address ({1'b0,round_mem_address}),
		.clock (clk),
		.data (next_encstate_out),
		.wren (round_mem_we),
		.q (round_mem_out)
	);


    // ============================================================
    // TX CONTROL FSM
    // ============================================================
      tx_fsm #(
        .CMD_RESP_OR(8'h80)
    ) u_tx_fsm (
        .clk        (clk),
        .rst_n      (rst_n),

        .tx_ready   (tx_ready),
        .tx_valid   (tx_valid),
        .tx_byte    (tx_byte),

        .aes_done   (aes_done),
        .aes_result (aes_out),

        .cmd_in     (cmd_reg),
        .flags_in   (flags_reg),
	
		  .round_rd_addr(round_rd_addr),
		  .round_rd_data(round_mem_out),

			.tx_busy(),

        .error_flag (1'b0)
    );
	 
	 
	 	mux2to1 #(4) addr_mux (
				.in0(round_rd_addr),
				.in1(round_counter_out),
				.sel(round_mem_sel),
				.out(round_mem_address)
			);
			
	assign round_mem_sel = round_mem_we;
	
	
	/*
	// select TX address whenever TX is busy sending (round dump / result)
assign round_mem_sel = tx_busy;

// 5-bit mux: in0=AES, in1=TX
mux2to1 #(5) addr_mux (
    .in0({1'b0, round_counter_out}),  // AES write/read address during encryption
    .in1({1'b0, round_rd_addr}),       // TX read address during round dumping
    .sel(round_mem_sel),
    .out(round_mem_address)
);
*/
endmodule
