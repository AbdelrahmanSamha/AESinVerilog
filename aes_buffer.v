module aes_buffer #(
    parameter integer KEY_SIZE = 128   // 128 / 192 / 256
)(
    input  wire        clk,
    input  wire        rst_n,

    // ================= BYTE INPUT =================
    input  wire [7:0]  byte_in,

    // Header writes (1-cycle each)
    input  wire        cmd_we,
    input  wire        flags_we,
    input  wire        length_we,
    input  wire        sha_we,
    input  wire [31:0] length_in,

    // Payload writes (byte-by-byte)
    input  wire        key_we,     // byte write enable
    input  wire        iv_we,      // byte write enable
    input  wire        block_we,   // byte write enable

    // ================= AES OUTPUT =================
    input  wire        out_we,          // 1-cycle pulse
    input  wire [127:0] aes_out_block,  // full 128-bit block
	 
	 // ================= SHA OUTPUT =================
	 input  wire         sha_out_we,       // 1-cycle pulse (hash_valid)
	 input  wire [255:0] sha_out_hash,     // hash_out
	 
    // ================= STORED REGISTERS =================
    output reg [7:0]          cmd_reg,
    output reg [7:0]          flags_reg,
    output reg [31:0]         length_reg,

    output reg [KEY_SIZE-1:0] key_reg,
    output reg [127:0]        iv_reg,
    output reg [127:0]        block_reg,
    output reg [127:0]        out_block,
	 output reg [511:0]        sha_block_reg,

    // ================= STATUS =================
    output reg cmd_ready,      // 1-cycle pulse
    output reg flags_ready,    // 1-cycle pulse
    output reg length_ready,   // 1-cycle pulse

    output reg key_ready,      // sticky high until key starts writing again
    output reg iv_ready,       // sticky high until iv starts writing again
    output reg block_ready,    // sticky high until block starts writing again
    output reg sha_ready,       // sticky high until block starts writing again
	 
	 output reg sha_out_reg
	 
		
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
    reg [5:0] sha_cnt;

    // ====================================================
    // storage logic
    // ====================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_reg     <= 8'd0;
            flags_reg   <= 8'd0;
            length_reg  <= 32'd0;

            key_reg     <= {KEY_SIZE{1'b0}};
            iv_reg      <= 128'd0;
            block_reg   <= 128'd0;
            out_block   <= 128'd0;
            sha_block_reg <= 512'd0;
            sha_out_reg    <= 256'd0;

            key_cnt     <= 0;
            iv_cnt      <= 0;
            block_cnt   <= 0;
            sha_cnt   <= 0;

            cmd_ready   <= 1'b0;
            flags_ready <= 1'b0;
            length_ready<= 1'b0;

            key_ready   <= 1'b0;
            iv_ready    <= 1'b0;
            block_ready <= 1'b0;
				sha_ready <= 1'b0;

        end else begin
            // ----------------------------
            // default: 1-cycle pulses go low
            // ----------------------------
            cmd_ready    <= 1'b0;
            flags_ready  <= 1'b0;
            length_ready <= 1'b0;


            // ----------------------------
            // CMD (1 byte)
            // ----------------------------
            if (cmd_we) begin
                cmd_reg   <= byte_in;
                cmd_ready <= 1'b1;   // 1-cycle pulse
            end

            // ----------------------------
            // FLAGS (1 byte)
            // ----------------------------
            if (flags_we) begin
                flags_reg   <= byte_in;
                flags_ready <= 1'b1; // 1-cycle pulse
            end

            // ----------------------------
            // LENGTH (already assembled 32-bit)
            // ----------------------------
            if (length_we) begin
                length_reg   <= length_in;
                length_ready <= 1'b1; // 1-cycle pulse
            end

            // ================= KEY (byte-by-byte) =================
            if (key_we) begin
                // clear sticky ready when a NEW key starts arriving
                if (key_cnt == 0)
                    key_ready <= 1'b0;

                key_reg <= {key_reg[KEY_SIZE-9:0], byte_in};

                if (key_cnt == KEY_BYTES - 1) begin
                    key_ready <= 1'b1;  // sticky
                    key_cnt   <= 0;
                end else begin
                    key_cnt <= key_cnt + 1'b1;
                end
            end

            // ================= IV (128-bit, byte-by-byte) =================
            if (iv_we) begin
                // clear sticky ready when a NEW iv starts arriving
                if (iv_cnt == 0)
                    iv_ready <= 1'b0;

                iv_reg <= {iv_reg[119:0], byte_in};

                if (iv_cnt == 4'd15) begin
                    iv_ready <= 1'b1;  // sticky
                    iv_cnt   <= 0;
                end else begin
                    iv_cnt <= iv_cnt + 1'b1;
                end
            end

            // ================= DATA BLOCK (128-bit, byte-by-byte) =================
            if (block_we) begin
                // clear sticky ready when a NEW block starts arriving
                if (block_cnt == 0)
                    block_ready <= 1'b0;

                block_reg <= {block_reg[119:0], byte_in};

                if (block_cnt == 4'd15) begin
                    block_ready <= 1'b1; // sticky
                    block_cnt   <= 0;
                end else begin
                    block_cnt <= block_cnt + 1'b1;
                end
            end
	
				// ================= SHA BLOCK (512-bit, 64 bytes) =================
				if (sha_we) begin
					// clear sticky ready when a NEW sha block starts arriving
					if (sha_cnt == 6'd0)
						sha_ready <= 1'b0;
				
					sha_block_reg <= {sha_block_reg[503:0], byte_in};
				
					if (sha_cnt == 6'd63) begin
						sha_ready <= 1'b1;   // sticky high until next sha block starts
						sha_cnt   <= 6'd0;
					end else begin
						sha_cnt <= sha_cnt + 1'b1;
					end
				end


            // ================= AES OUTPUT (128-bit, one-shot) =================
            if (out_we) begin
                out_block <= aes_out_block;
            end
				
				// ================= SHA OUTPUT (256-bit, one-shot) =================
				if (sha_out_we) begin
					sha_out_reg   <= sha_out_hash;
				end
		  end
    end

endmodule
