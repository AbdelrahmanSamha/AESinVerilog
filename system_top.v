module system_top (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         init_accel,
	 input  wire         dec,
	 input  wire 			uart_rx,       // Incoming serial line
    output wire 			uart_tx,       // Outgoing serial line
    output  reg        done
);


	wire [127:0] CT;
	wire [3:0] read_key_address, write_key_address;
	wire [4:0] key_address;
	wire mem_round_key_en;
	wire [127:0] write_roundkey, read_roundkey; 
	wire rx_valid;
   wire aes_done;
   wire tx_ready;
   wire [7:0] rx_byte;
   wire [127:0] out_block;

   wire [7:0] tx_byte_out;
   wire aes_start_out;
   wire key_exp_start_out;
   wire tx_start_out;
   wire [127:0] data_block;
   wire [127:0] aes_key;
	wire mem_key_rw; 

	block_encrypt BE(
		 	.clk(clk),
			.rst_n(rst_n), 
		 	.start(aes_start_out),
		 	.plaintext(data_block), 
		 	.roundkey(read_roundkey), 
			.ciphertext(CT),
			.key_address(read_key_address),
			.done(block_encryption_finish),
			.dec(dec)
		);
		
		
	aes_keyexpand keyexp (
	.clk(clk),
	.rst_n(rst_n),
	.init(key_exp_start_out),
	.og_key(aes_key),
	.store_key_mem(mem_round_key_en),
	.address(write_key_address),
	.round_key(gen_roundkey),
	.finish(key_expand_finish)
	);
	
	
	mem_round_keys keymem(.clock(clk), .address(key_address), .data(gen_roundkey), .wren(mem_round_key_en), .q(read_roundkey));
	mux2to1 #(4) amux (.in0(write_key_address), .in1(read_key_address), .sel(mem_key_rw), .out(key_address[3:0]));
	assign key_address[4] = 1'b0;
	
	
	
	


    // -----------------------
    // Instantiate main_fsm
    // -----------------------
    main_fsm u_main_fsm (
        .clk(clk),
        .reset(rst_n),
		  .start(init_accel),
        .rx_valid(rx_valid),
        .aes_done(block_encryption_finish),
        .tx_ready(tx_ready),
        .rx_byte(rx_byte),
        .out_block(CT),
        .tx_byte_out(tx_byte_out),
        .aes_start_out(aes_start_out),
        .key_exp_start_out(key_exp_start_out),
        .tx_start_out(tx_start_out),
        .data_block(data_block),
        .aes_key(aes_key),
		  .mem_key_rw_out(mem_key_rw)
    );
	 
	     uart_rx u_uart_rx (
        .clk(clk),
        .reset(rst_n),
        .uart_rx(),
        .rx_byte(rx_byte),
        .rx_valid(rx_valid)
    );

	    uart_tx u_uart_tx (
        .clk(clk),
        .reset(rst_n),
        .tx_start(tx_start_out),     
        .tx_byte(tx_byte_out),       
        .uart_tx(),      
        .tx_ready(tx_ready)          
    );
endmodule
