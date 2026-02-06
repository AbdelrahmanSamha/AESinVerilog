module core_fsm #(
    parameter integer MODE    = 0     // 0=ECB,1=CBC,2=CTR,3=OFB,4=CFB
)(
    input  wire        clk,
    input  wire        rst_n,

    // -------- from BUFFER (header pulses + stored regs) --------
    input  wire        cmd_ready,      // 1-cycle pulse
    input  wire        flags_ready,    // 1-cycle pulse
    input  wire        length_ready,   // 1-cycle pulse

    input  wire [7:0]  cmd_reg,
    input  wire [7:0]  flags_reg,
    input  wire [31:0] length_reg,

    // -------- from BUFFER (sticky payload ready) --------
    input  wire        key_ready,
    input  wire        iv_ready,
    input  wire        block_ready,

    // -------- from AES --------
    input  wire        key_expand_ready,  // high when key expansion finished
    input  wire        aes_done,          // indicates block finished

    // -------- to AES --------
    output reg         aes_start,         // 1-cycle pulse
    output reg         dec,               // stable dec bit
    output reg         valid_in_key_aes,   // 1-cycle pulse
    output reg         valid_in_block_aes,  // 1-cycle pulse (blk_sent protected)
	 
	 output reg			  aes_rst // rst after finish frame and operation 
	 
	 
	 

);

    // ============================================================
    // locals
    // ============================================================
    localparam integer ECB_MODE = 0;
	 localparam [7:0] CMD_AES = 8'h01;
    localparam BLOCK_LAB = 8'h02;
	 
	 
    wire iv_needed = (MODE != ECB_MODE);

    wire have_key = key_ready && (iv_needed ? iv_ready : 1'b1);

    // ============================================================
    // state encoding
    // ============================================================
    localparam [1:0]
        S_WAIT_HDR   = 2'b00,
        S_KEYEXP     = 2'b01,
        S_BLOCKS     = 2'b10,
        S_DONE       = 2'b11;

    reg [1:0] state, next_state;

    // ============================================================
    // header latch flags (because pulses are 1 cycle)
    // ============================================================
    reg got_cmd,   got_cmd_n;
    reg got_flags, got_flags_n;
    reg got_len,   got_len_n;

    wire hdr_done  = got_cmd & got_flags & got_len;
    wire cmd_is_aes = (cmd_reg == CMD_AES) || (cmd_reg == BLOCK_LAB);

    // ============================================================
    // block guard + key guard
    // ============================================================
    reg blk_sent, blk_sent_n;
    reg key_sent, key_sent_n;

    // ============================================================
    // block counting (based on length_reg bytes)
    // blocks_total = length_reg / 16 = length_reg[31:4]
    // ============================================================
    reg [31:0] blocks_total, blocks_total_n;
    reg [31:0] block_index,  block_index_n;

    wire [31:0] blocks_total_m1 =
        (blocks_total == 32'd0) ? 32'd0 : (blocks_total - 32'd1);

    wire last_block = (block_index == blocks_total_m1);

    // ============================================================
    // 1) State register + sequential regs
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_WAIT_HDR;

            got_cmd      <= 1'b0;
            got_flags    <= 1'b0;
            got_len      <= 1'b0;

            dec          <= 1'b0;

            blk_sent     <= 1'b0;
            key_sent     <= 1'b0;

            blocks_total <= 32'd0;
            block_index  <= 32'd0;
        end else begin
            state        <= next_state;

            got_cmd      <= got_cmd_n;
            got_flags    <= got_flags_n;
            got_len      <= got_len_n;

            blk_sent     <= blk_sent_n;
            key_sent     <= key_sent_n;

            blocks_total <= blocks_total_n;
            block_index  <= block_index_n;

            // latch dec bit when flags arrive
            if (flags_ready) begin
                dec <= flags_reg[3];
            end
        end
    end

    // ============================================================
    // 2) Next-state logic
    // ============================================================
    always @(*) begin
        next_state = state;

        case (state)
            S_WAIT_HDR: begin
                if (hdr_done && cmd_is_aes)
                    next_state = S_KEYEXP;
            end

            S_KEYEXP: begin
                if (key_expand_ready)
                    next_state = S_BLOCKS;
            end

            S_BLOCKS: begin
                if (aes_done && last_block)
                    next_state = S_DONE;
                else
                    next_state = S_BLOCKS;
            end

            S_DONE: begin
                next_state = S_WAIT_HDR;
            end

            default: begin
                next_state = S_WAIT_HDR;
            end
        endcase
    end

    // ============================================================
    // 3) Output logic + latch updates
    // ============================================================
    always @(*) begin
        // defaults
        aes_start          = 1'b0;
        valid_in_key_aes   = 1'b0;
        valid_in_block_aes = 1'b0;
        aes_rst      = 1'b1;  


        // hold regs by default
        got_cmd_n      = got_cmd;
        got_flags_n    = got_flags;
        got_len_n      = got_len;

        blk_sent_n     = blk_sent;
        key_sent_n     = key_sent;

        blocks_total_n = blocks_total;
        block_index_n  = block_index;

        // -------------------------
        // header latch updates
        // -------------------------
        if (cmd_ready)
            got_cmd_n = 1'b1;

        if (flags_ready)
            got_flags_n = 1'b1;

        if (length_ready) begin
            got_len_n = 1'b1;

            // blocks_total = length_reg / 16
            blocks_total_n = length_reg[31:4];
            block_index_n  = 32'd0;
        end

        // -------------------------
        // blk_sent clear when next block starts arriving
        // (buffer makes block_ready drop to 0 at start of new block)
        // -------------------------
        if (!block_ready)
            blk_sent_n = 1'b0;

        case (state)
            S_WAIT_HDR: begin
                // When header is complete and cmd is AES:
                // pulse init once and clear per-message guards.
                if (hdr_done && cmd_is_aes) begin
                    aes_start  = 1'b1;  // 1-cycle pulse (we leave this state next cycle)

                    // new message/session => clear guards
                    key_sent_n = 1'b0;
                    blk_sent_n = 1'b0;

                    // Also clear header latches on session start
                    // so next message must provide new header pulses
                    got_cmd_n   = 1'b0;
                    got_flags_n = 1'b0;
                    got_len_n   = 1'b0;


                end
            end

            S_KEYEXP: begin
                // Pulse look: only once when key material becomes available.
                if (have_key && !key_sent) begin
                    valid_in_key_aes = 1'b1;
                    key_sent_n        = 1'b1;
                end
            end

            S_BLOCKS: begin
                // Start a block only once per received block (blk_sent protected).
                if (block_ready && !blk_sent) begin
                    valid_in_block_aes = 1'b1;
                    blk_sent_n         = 1'b1;
                end

                // advance block counter when aes_done
                if (aes_done) begin
                    if (!last_block) begin
                        block_index_n = block_index + 32'd1;
                    end
                    // if last_block, next_state goes to DONE
                end
            end

            S_DONE: begin
                // nothing; will go back to WAIT_HDR and wait next header
						aes_rst = 1'b0;

            end
        endcase
    end

endmodule
