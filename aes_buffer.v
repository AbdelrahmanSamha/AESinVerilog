module aes_buffer #(
    parameter integer KEY_SIZE = 128   // 128 / 192 / 256
)(
    input  wire        clk,
    input  wire        rst_n,

    // ================= BYTE INPUT =================
    input  wire [7:0]  byte_in,

    input  wire        key_we,     // byte write enable
    input  wire        iv_we,      // byte write enable
    input  wire        block_we,   // byte write enable

    // ================= AES OUTPUT =================
    input  wire        out_we,          // 1-cycle pulse
    input  wire [127:0] aes_out_block,  // full 128-bit block

    // ================= STORED REGISTERS =================
    output reg [KEY_SIZE-1:0] key_reg,
    output reg [127:0]        iv_reg,
    output reg [127:0]        block_reg,
    output reg [127:0]        out_block,

    // ================= STATUS =================
    output reg key_ready,
    output reg iv_ready,
    output reg block_ready
);

    // ====================================================
    // local parameters
    // ====================================================
    localparam integer KEY_BYTES = KEY_SIZE / 8;

    // ====================================================
    // counters (ONLY for byte-based inputs)
    // ====================================================
    reg [$clog2(KEY_BYTES):0] key_cnt;
    reg [3:0] iv_cnt;
    reg [3:0] block_cnt;

    // ====================================================
    // storage logic
    // ====================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_reg     <= {KEY_SIZE{1'b0}};
            iv_reg      <= 128'd0;
            block_reg   <= 128'd0;
            out_block   <= 128'd0;

            key_cnt     <= 0;
            iv_cnt      <= 0;
            block_cnt   <= 0;

            key_ready   <= 1'b0;
            iv_ready    <= 1'b0;
            block_ready <= 1'b0;

        end else begin
            // default: clear ready pulses
        //    key_ready   <= 1'b0;
         //   iv_ready    <= 1'b0;
         //   block_ready <= 1'b0;

            // ================= KEY (byte-by-byte) =================
            if (key_we) begin
				
				    if (key_cnt == 0)
						key_ready <= 1'b0;
                
					 key_reg <= {key_reg[KEY_SIZE-9:0], byte_in};

                if (key_cnt == KEY_BYTES - 1) begin
                    key_ready <= 1'b1;
                    key_cnt   <= 0;
                end else begin
                    key_cnt <= key_cnt + 1'b1;
                end
            end

            // ================= IV (128-bit, byte-by-byte) =================
            if (iv_we) begin
				
					if (iv_cnt == 0)
						iv_ready <= 1'b0;
						
						
                iv_reg <= {iv_reg[119:0], byte_in};

                if (iv_cnt == 4'd15) begin
                    iv_ready <= 1'b1;
                    iv_cnt   <= 0;
                end else begin
                    iv_cnt <= iv_cnt + 1'b1;
                end
            end

            // ================= DATA BLOCK (128-bit, byte-by-byte) =================
            if (block_we) begin
                block_reg <= {block_reg[119:0], byte_in};
					 
					 if (block_cnt == 0)
							block_ready <= 1'b0;

                if (block_cnt == 4'd15) begin
                    block_ready <= 1'b1;
                    block_cnt   <= 0;
                end else begin
                    block_cnt <= block_cnt + 1'b1;
                end
            end

            // ================= AES OUTPUT (128-bit, one-shot) =================
            if (out_we) begin
                out_block <= aes_out_block;
            end
        end
    end

endmodule
