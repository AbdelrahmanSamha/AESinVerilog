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
	
	assign PT = 128'h3243F6A8885A308D313198A2E0370734;
	assign OGKEY   = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
	
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
				if (init_accel) begin 
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
		 	 .plaintext(PT), 
		 	 .roundkey(read_roundkey), 
			 .ciphertext(CT),
			 .key_address(read_key_address),
			 .done(block_encryption_finish),
			 .dec(dec)
		);
	aes_keyexpand keyexp (
	.clk(clk),
	.rst_n(rst_n),
	.init(init_key_expantion),
	.og_key(OGKEY),
	.store_key_mem(mem_round_key_en),
	.address(write_key_address),
	.round_key(gen_roundkey),
	.finish(key_expand_finish)
	);
	
	
	mem_round_keys keymem(.clock(clk), .address(key_address), .data(gen_roundkey), .wren(mem_round_key_en), .q(read_roundkey));
	mux2to1 #(4) amux (.in0(write_key_address), .in1(read_key_address), .sel(mem_key_rw), .out(key_address[3:0]));
	assign key_address[4] = 1'b0;
	
endmodule
