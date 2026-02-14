module aes_uart_top #(
    parameter integer KEY_SIZE = 128,
    parameter integer DOP      = 1,
    parameter integer MODE     = 0,
    parameter integer FIXED_VARKEY_MODE = 0 
)(
    input  wire        clk,
    input  wire        rst_n,
/*
    // ================= UART RX =================
    input  wire        rx_valid,
    input  wire [7:0]  rx_byte,

    // ================= UART TX =================
    input  wire        tx_ready,
    output wire        tx_valid,
    output wire [7:0]  tx_byte
	*/ 
	 input  wire 			uart_rx,       // Incoming serial line
    output wire 			uart_tx        // Outgoing serial line
	 

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
    wire                out_block_valid;

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
	 
	 wire finish_cmd_rst;
	 
	 wire [2:0] mode_sel;
	 wire [1:0] key_size_sel;
	
	 assign mode_sel = flags_reg[2:0];
	 assign key_size_sel = flags_reg[7:6];
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


    wire [7:0] rx_byte;
    wire rx_valid;


    wire tx_valid;   
    wire [7:0] tx_byte;
    wire tx_ready;         
    wire tx_done;     

	 wire        buf_sha_we;
	 
	 wire [511:0] sha_block_reg;
	 wire         sha_ready;
	 
	 wire         sha_out_we;
	 wire [255:0] sha_out_hash;
	 
	 wire         out_sha_valid;
	 wire [255:0] sha_out_reg;
	 	
	 wire         sha_sys_start;
	 wire         sha_valid_data;
	 
	 wire         trng_start;
	 wire         trng_done;
	 wire [255:0] trng_data;
	 
	 wire [255:0] sha_trng_result;
	 wire sha_trng_done;
	 wire is_trng_cmd;


    // ============================================================
    // RX FSM
    // ============================================================
    rx_fsm #(
        .KEY_SIZE(KEY_SIZE),
        .MODE    (MODE),
		  .FIXED_VARKEY_MODE(FIXED_VARKEY_MODE)
    ) u_rx_fsm (
        .clk        (clk),
        .reset_n    (rst_n),

        .rx_valid   (rx_valid),
        .rx_byte    (rx_byte),

        // buffer write strobes
        .buf_cmd_we    (buf_cmd_we),
        .buf_flags_we  (buf_flags_we),
        .buf_len_we_out    (buf_len_we),

        .buf_key_we    (buf_key_we),
        .buf_iv_we     (buf_iv_we),
        .buf_data_we   (buf_block_we),
		  .buf_sha_we    (buf_sha_we),

        .buf_data_addr (buf_data_addr),
        .buf_wbyte     (buf_wbyte),

        // parsed header values (optional)
        .cmd_out     (rx_cmd),
        .flags_out   (rx_flags),
        .length_out  (rx_length),

        .buf_commit  (rx_commit),
        .rx_done     (rx_done),
		  
		  .mode_sel(mode_sel)
    );

    // ============================================================
    // AES BYTE BUFFER
    // ============================================================
    aes_buffer #(
        .KEY_SIZE(KEY_SIZE)
    ) u_buf (
        .clk        (clk),
        .rst_n      (rst_n && finish_cmd_rst),

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
        .block_ready  (block_ready),
        .out_block_valid  (out_block_valid),

		  .sha_we        (buf_sha_we),

		  .sha_out_we    (sha_trng_done),
		  .sha_out_hash  (sha_trng_result),
		  
		  .sha_block_reg (sha_block_reg),
		  .sha_ready     (sha_ready),
		  
		  .out_sha_valid (out_sha_valid),
		  .sha_out_reg   (sha_out_reg)

    );

    // ============================================================
    // CORE CONTROL FSM (header gating + blk_sent protection)
    // ============================================================
    core_fsm #(
        .MODE    (MODE),
		  .FIXED_VARKEY_MODE(FIXED_VARKEY_MODE)
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
		  .finish_cmd_rst(finish_cmd_rst),
		  
		  .mode_sel(mode_sel),
		  .tx_done(tx_done),

		  .sha_ready      (sha_ready),
		  .sha_hash_valid (out_sha_valid),   // buffer pulses this when hash captured
		  
		  .sha_sys_start     (sha_sys_start),
		  .sha_valid_data    (sha_valid_data),
		  
		  .trng_start    (trng_start),
		  .trng_done     (trng_done),
		  .cmd_is_trng   (is_trng_cmd)
			 
    );

    // ============================================================
    // AES CORE
    // ============================================================
    aes_top #(
        .KEY_SIZE(KEY_SIZE),
        .DOP     (DOP),
        .MODE    (MODE),
		  .FIXED_VARKEY_MODE(FIXED_VARKEY_MODE)
    ) u_aes (
        .clk        (clk),
        .rst_n      (rst_n && finish_cmd_rst),

        .init       (aes_start),
        .dec        (dec),

        .valid_in_key_aes   (valid_in_key_aes),
        .valid_in_block_aes (valid_in_block_aes),

        .og_key     (key_reg),
        .text_in    (block_reg),
        .iv    (iv_reg),

        .terminate_session (1'b0),

        .text_out   (aes_out_bus),
        .valid_dout (aes_done),

        .key_expand_ready (key_expand_ready),
		  
		  .next_encstate_out(next_encstate_out),
		  .round_counter_out(round_counter_out),
		  .round_mem_we(round_mem_we),
		  
		  .mode_sel(mode_sel),
		  .key_size_sel(key_size_sel)
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
        .KEY_SIZE(KEY_SIZE)
		  )u_tx_fsm (
        .clk        (clk),
        .rst_n      (rst_n),

        .tx_ready   (tx_ready),
        .tx_valid   (tx_valid),
        .tx_byte    (tx_byte),

        .aes_done   (out_block_valid),
        .aes_result (out_block),

        .cmd_in     (cmd_reg),
	
		  .round_rd_addr(round_rd_addr),
		  .round_rd_data(round_mem_out),

		  .tx_busy(),
		  .tx_done(tx_done),
		  
		  .sha_done   (out_sha_valid),
		  .sha_result (sha_out_reg)

     
    );
	 
	 
	 	mux2to1 #(4) addr_mux (
				.in0(round_rd_addr),
				.in1(round_counter_out),
				.sel(round_mem_sel),
				.out(round_mem_address)
			);
			
	assign round_mem_sel = round_mem_we;
	 
	 // ============================================================
	 // SHA TOP
	 // ============================================================
	 toplevel_hash u_sha (
		 .clk        (clk),
		 .rst_n      (rst_n && finish_cmd_rst),   // reset SHA when session resets
		 .sys_start  (sha_sys_start),
		 .length     (length_reg),
		 .valid_data (sha_valid_data),
		 .data       (sha_block_reg),
	 
		 .hash_out   (sha_out_hash),
		 .hash_valid (sha_out_we)
	 );
	 
	 // ============================================================
	 // TRNG TOP
	 // ============================================================
			TRNG u_trng (
			.clk        (clk),
			.rst_n      (rst_n && finish_cmd_rst),  // reset with session reset
			.start      (trng_start),
			.enable_osc (),                     
			.done       (trng_done),
			.random_data(trng_data)
		);
		

		
		mux2to1 #(.WIDTH(256)) u_mux_sha_trng_data (
			.in0 (sha_out_hash),    // SHA path
			.in1 (trng_data),   // TRNG path
			.sel (is_trng_cmd),
			.out (sha_trng_result)
		);
		
		
		mux2to1 #(.WIDTH(1)) u_mux_sha_trng_valid (
			.in0 (sha_out_we),   // SHA done pulse
			.in1 (trng_done),  // TRNG done pulse
			.sel (is_trng_cmd),
			.out (sha_trng_done)
		);
		
    // ============================================================
    // uart_rx
    // ============================================================
		  uart_rx u_uart_rx (
        .clk(clk),
        .reset(rst_n),
        .uart_rx(uart_rx),
        .rx_byte(rx_byte),
        .rx_valid(rx_valid)
    );
	
    // ============================================================
    // uart_tx
    // ============================================================
	    uart_tx u_uart_tx (
        .clk(clk),
        .reset(rst_n),
        .tx_start(tx_valid),     
        .tx_byte(tx_byte),       
        .uart_tx(uart_tx),      
        .tx_ready(tx_ready)          
    );

endmodule
