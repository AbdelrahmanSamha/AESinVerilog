module system_top (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         init_accel,
	 input  wire         dec,
    input  wire [7:0] plaintext,
    input  wire [7:0] key,
    output  reg        done,
    output 	  [7:0] ciphertext
);


	wire [127:0] PT,CT, OGKEY;
	wire [3:0] read_key_address, write_key_address;
	wire [4:0] key_address;
	wire mem_round_key_en;
	wire [127:0] write_roundkey, read_roundkey; 
	
	//assign PT = 128'h3243F6A8885A308D313198A2E0370734;
	//assign PT = 128'h3925841d02dc09fbdc118597196a0b32;
	//assign OGKEY   = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
	
	 //------------------------------------
    // State encoding and definistions 
    //------------------------------------
	parameter IDLE  = 2'b00,
             GEN_KEYS  = 2'b01,
				 BLOCK_ENCRYPT = 2'b10;
	
	reg [1:0] state, next_state; 
	wire key_expand_finish;
	wire block_encryption_finish; 
	reg init_key_expantion, start_block_encryption;
	reg mem_key_rw;
	wire [127:0] gen_roundkey; 
    //------------------------------------
    // 1. State register (sequential logic)
    //------------------------------------	
	
	always @(posedge clk) begin
		if (!rst_n) begin 
			state <= 2'b0; 
		end 
		else begin 
			state <= next_state;

		end 
	
	end 
	
    //------------------------------------
    // 2. Next-state logic (combinational)
    //------------------------------------

	 always @* begin 
		next_state = state;
		done = 1'b0;	
		case (state)
			IDLE : begin 
				if (aes_start_out) begin 
					next_state = GEN_KEYS;
				end 
				else begin 
					next_state = IDLE; 
				end 
			end 
			
			GEN_KEYS: begin 
				if (key_expand_finish) begin 
					next_state = BLOCK_ENCRYPT; 
				end 
				else begin 
					next_state= GEN_KEYS;
				end 
			end
			
			BLOCK_ENCRYPT: begin 
				if (block_encryption_finish) begin 
					next_state = IDLE;
					done = 1'b1;
				end 
				else begin 
					next_state= BLOCK_ENCRYPT;
				end
			end 
		
		
		endcase 
	 
	 
	 end 
	 
    //------------------------------------
    // 3. Output logic (combinational)
    //------------------------------------

	always @* begin 
	 init_key_expantion = 1'b0;
	 start_block_encryption = 1'b0;
	 mem_key_rw = 1'b0; 
		case (state)
			IDLE : begin 
				
			end 
			
			GEN_KEYS: begin 
				init_key_expantion = 1'b1;
				mem_key_rw = 1'b0;
			end
			
			BLOCK_ENCRYPT: begin 
				start_block_encryption = 1'b1;
				mem_key_rw = 1'b1;
			end 
		endcase 
	 end 
	 
	 
	 

	block_encrypt BE(
		 	.clk(clk),
			.rst_n(rst_n), 
		 	.start(start_block_encryption),
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
        .aes_key(aes_key)
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
