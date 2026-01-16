module aes_top #(
    parameter integer KEY_SIZE = 128
)(
    input               clk,
    input               rst_n,
    input               init,
    input  [127:0]      plaintext,
    input  [KEY_SIZE-1:0] key,
	 input 					 dec, 
    output [127:0]      ciphertext,
    output              done
);




	localparam  IDLE        = 3'b000,
					KEYEXP_INIT = 3'b001,
					KEYEXP_WAIT = 3'b010,
					ENC_INIT    = 3'b011,
					ENC_WAIT    = 3'b100,
					DONE        = 3'b101;
	
	


	wire [127:0] CT;
    // -----------------------------
    // Internal wires
    // -----------------------------
    wire [127:0] gen_roundkey;
    wire [127:0] read_roundkey;
    wire [3:0]   write_key_address;
    wire [3:0]   read_key_address;
    wire [4:0]   key_address;
    wire         mem_round_key_en;
    wire         key_expand_finish;
    wire         block_encryption_finish;
	
    reg  [2:0]   state, next_state;

    reg          key_exp_start_out;
    reg          aes_start_out;
    reg          mem_key_rw;
    reg          done_reg;

    assign done = done_reg;
    assign ciphertext = CT;
    

    // -----------------------------
    // Key Expansion
    // -----------------------------
    aes_keyexpand #(KEY_SIZE) keyexp (
        .clk(clk),
        .rst_n(rst_n),
        .init(key_exp_start_out),
        .og_key(key),
        .store_key_mem(mem_round_key_en),
        .address(write_key_address),
        .round_key(gen_roundkey),
        .finish(key_expand_finish)
    );

    // -----------------------------
    // Block Encrypt
    // -----------------------------
    

    block_encrypt #(KEY_SIZE) BE (
        .clk(clk),
        .rst_n(rst_n),
        .start(aes_start_out),
        .dec(dec),
        .plaintext(plaintext),
        .roundkey(read_roundkey),
        .ciphertext(CT),
        .key_address(read_key_address),
        .done(block_encryption_finish)
    );

    // -----------------------------
    // Round-key memory
    // -----------------------------
    mem_round_keys keymem (
        .clock(clk),
        .address(key_address),
        .data(gen_roundkey),
        .wren(mem_round_key_en),
        .q(read_roundkey)
    );

    mux2to1 #(4) addr_mux (
        .in0(write_key_address),
        .in1(read_key_address),
        .sel(mem_key_rw),
        .out(key_address[3:0])
    );
	assign key_address[4] = 1'b0;
	
	
    // -----------------------------
    // FSM: State register
    // -----------------------------
    always @(posedge clk) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // -----------------------------
    // FSM: Next-state logic
    // -----------------------------
    always @(*) begin
        next_state = state;

        case (state)
            IDLE:
                if (init) next_state = KEYEXP_INIT;

            KEYEXP_INIT:
                next_state = KEYEXP_WAIT;

            KEYEXP_WAIT:
                if (key_expand_finish)
                    next_state = ENC_INIT;

            ENC_INIT:
                next_state = ENC_WAIT;

            ENC_WAIT:
                if (block_encryption_finish)
                    next_state = DONE;

            DONE:
                next_state = IDLE;

            default:
                next_state = IDLE;
        endcase
    end

    // -----------------------------
    // FSM: Output logic
    // -----------------------------
    always @(*) begin
        key_exp_start_out = 1'b0;
        aes_start_out     = 1'b0;
        mem_key_rw        = 1'b0;
        done_reg          = 1'b0;

        case (state)
            IDLE: begin
                mem_key_rw = 1'b0;
            end

            KEYEXP_INIT: begin
                key_exp_start_out = 1'b1;
                mem_key_rw = 1'b0;
            end

            KEYEXP_WAIT: begin
                mem_key_rw = 1'b0;
            end

            ENC_INIT: begin
                aes_start_out = 1'b1;
                mem_key_rw = 1'b1;
            end

            ENC_WAIT: begin
                mem_key_rw = 1'b1;
					 if (block_encryption_finish)begin 
						done_reg = 1'b1;
					 end 
				end

            DONE: begin
                
            end
        endcase
    end

endmodule
