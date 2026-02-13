module rx_fsm #(
    parameter integer KEY_SIZE = 128,
    parameter integer MODE     = 0,   // 0=ECB, 1=CBC, 2=CTR, 3=OFB, 4=CFB
    parameter integer FIXED_VARKEY_MODE     = 0   // 0=ECB, 1=CBC, 2=CTR, 3=OFB, 4=CFB

)(
    input  wire        clk,
    input  wire        reset_n,     // ACTIVE-low reset

    input  wire        rx_valid,
    input  wire [7:0]  rx_byte,
	 
	 input [2:0] mode_sel,

    // ---- to BUFFER ----
    output reg         buf_cmd_we,
    output reg         buf_flags_we,
    output reg         buf_len_we_out,

    output reg         buf_key_we,
    output reg         buf_iv_we,
    output reg         buf_data_we,
    output reg         buf_sha_we,

    output reg  [31:0] buf_data_addr,
    output reg  [7:0]  buf_wbyte,

    output reg  [7:0]  cmd_out,
    output reg  [7:0]  flags_out,
    output reg  [31:0] length_out,

    output reg         buf_commit,
    output reg         rx_done
);

    // ----------------------------
    // Derived constants
    // ----------------------------
    localparam integer KEY_BYTES =
        (KEY_SIZE == 128) ? 16 :
        (KEY_SIZE == 192) ? 24 : 32;

    localparam integer ECB = 0;
    localparam integer VAR_MODES = 5;
    localparam integer VAR_KEYS = 6;
    localparam integer FULL = 7;
	 
	 
	 localparam [7:0] CMD_SHA = 8'h03;
	
	 wire is_sha_cmd = (cmd_out == CMD_SHA);
	 

    wire iv_needed;
	 
	 assign iv_needed = !((MODE == ECB) || (MODE == VAR_MODES && mode_sel == 3'b000)
							 || (MODE == VAR_KEYS && FIXED_VARKEY_MODE == 0) || (MODE == FULL && mode_sel == 3'b000));

    // ----------------------------
    // States
    // ----------------------------
    localparam [2:0]
        IDLE       = 3'b000,
        RECV_FLAGS = 3'b001,
        RECV_LEN   = 3'b010,
        RECV_KEY   = 3'b011,
        RECV_IV    = 3'b100,
        RECV_DATA  = 3'b101;

    reg [2:0] curr_state, next_state;

    // ----------------------------
    // Counters / regs
    // ----------------------------
    reg [2:0]  len_bytes;           // 1..4 (flags[5:4] + 1)
    reg [2:0]  len_cnt,  len_cnt_n;
    reg [31:0] len_acc,  len_acc_n;

    reg [7:0]  key_cnt,  key_cnt_n; // counts remaining bytes
    reg [4:0]  iv_cnt,   iv_cnt_n;  // counts remaining bytes
    reg [31:0] data_cnt, data_cnt_n;// counts remaining bytes
    reg buf_len_we ;

    // ============================================================
    // 1) State register + sequential regs
    // ============================================================
    always @(posedge clk) begin
        if (!reset_n) begin
            curr_state    <= IDLE;

            cmd_out       <= 8'd0;
            flags_out     <= 8'd0;
            length_out    <= 32'd0;

            len_bytes     <= 3'd1;
            len_cnt       <= 3'd0;
            len_acc       <= 32'd0;

            key_cnt       <= 8'd0;
            iv_cnt        <= 5'd0;
            data_cnt      <= 32'd0;

            buf_data_addr <= 32'd0;
				
            buf_len_we_out <= 1'd0;
        end else begin
            curr_state <= next_state;

            len_cnt    <= len_cnt_n;
            len_acc    <= len_acc_n;

            key_cnt    <= key_cnt_n;
            iv_cnt     <= iv_cnt_n;
            data_cnt   <= data_cnt_n;
				
				buf_len_we_out <= buf_len_we;

            // CMD captured in IDLE on first rx_valid
            if (buf_cmd_we) begin
                cmd_out <= rx_byte;
            end

            // FLAGS captured
            if (buf_flags_we) begin
                flags_out <= rx_byte;
                len_bytes <= {1'b0, rx_byte[5:4]} + 3'd1;
            end

            // latch final length_out when done receiving LENGTH
            if (curr_state == RECV_LEN && rx_valid && (len_cnt == (len_bytes - 3'd1))) begin
                length_out <= len_acc_n; // includes last byte
            end

            // reset data address at start of data receive
            if ((curr_state == RECV_IV  && next_state == RECV_DATA) ||
                (curr_state == RECV_KEY && next_state == RECV_DATA)) begin
                buf_data_addr <= 32'd0;
            end

            // increment data addr on each data byte written
            if (buf_data_we) begin
                buf_data_addr <= buf_data_addr + 32'd1;
            end
        end
    end

    // ============================================================
    // 2) Next-state logic
    // ============================================================
    always @(*) begin
        next_state = curr_state;

        case (curr_state)
            IDLE: begin
                if (rx_valid)
                    next_state = RECV_FLAGS;
            end

            RECV_FLAGS: begin
                if (rx_valid)
                    next_state = RECV_LEN;
            end

            RECV_LEN: begin
                if (rx_valid && (len_cnt == (len_bytes - 3'd1))) begin 
							if (is_sha_cmd)
								next_state = RECV_DATA;   // SHA: LEN -> DATA
							else
								next_state = RECV_KEY;
					end
            end

            RECV_KEY: begin
                if (rx_valid && (key_cnt == 8'd1)) begin
                    if (iv_needed)
                        next_state = RECV_IV;
                    else
                        next_state = RECV_DATA;
                end
            end

            RECV_IV: begin
                if (rx_valid && (iv_cnt == 5'd1))
                    next_state = RECV_DATA;
            end

            RECV_DATA: begin
                if (rx_valid && (data_cnt == 32'd1))
                    next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // ============================================================
    // 3) Output / counter update logic
    // ============================================================
    always @(*) begin
        // defaults (avoid latches)
        buf_cmd_we   = 1'b0;
        buf_flags_we = 1'b0;
        buf_len_we   = 1'b0;

        buf_key_we   = 1'b0;
        buf_iv_we    = 1'b0;
        buf_data_we  = 1'b0;
        buf_sha_we  = 1'b0;

        buf_wbyte    = rx_byte;

        buf_commit   = 1'b0;
        rx_done      = 1'b0;

        // counter defaults (hold)
        len_cnt_n   = len_cnt;
        len_acc_n   = len_acc;

        key_cnt_n   = key_cnt;
        iv_cnt_n    = iv_cnt;
        data_cnt_n  = data_cnt;

        case (curr_state)
            IDLE: begin
                if (rx_valid) begin
                    buf_cmd_we = 1'b1;

                    len_cnt_n  = 3'd0;
                    len_acc_n  = 32'd0;

                    key_cnt_n  = KEY_BYTES[7:0];
                    iv_cnt_n   = 5'd16;
                    data_cnt_n = 32'd0; // will be loaded after LEN done
                end
            end

            RECV_FLAGS: begin
                if (rx_valid) begin
                    buf_flags_we = 1'b1;
                end
            end

            RECV_LEN: begin
                if (rx_valid) begin
                    // Only pulse len_we on the LAST length byte (1-cycle ready in buffer)
                    if (len_cnt == (len_bytes - 3'd1))
                        buf_len_we = 1'b1;

                    // big-endian accumulate
                    len_acc_n = {len_acc[23:0], rx_byte};
                    len_cnt_n = len_cnt + 3'd1;

                    // load DATA byte counter at end of LEN
                    if (len_cnt == (len_bytes - 3'd1)) begin
                        data_cnt_n = {len_acc[23:0], rx_byte};
                    end
                end
            end

            RECV_KEY: begin
                if (rx_valid) begin
                    buf_key_we = 1'b1;
                    key_cnt_n  = key_cnt - 8'd1;
                end
            end

            RECV_IV: begin
                if (rx_valid) begin
                    buf_iv_we = 1'b1;
                    iv_cnt_n  = iv_cnt - 5'd1;
                end
            end

            RECV_DATA: begin
                if (rx_valid) begin
						  if (is_sha_cmd) 
								buf_sha_we = 1'b1;
						  else
								buf_data_we = 1'b1;
					     end
                    
						  data_cnt_n  = data_cnt - 32'd1;

                    if (data_cnt == 32'd1) begin
                        buf_commit = 1'b1;
                        rx_done    = 1'b1;
                    end
                end
            end
        endcase
    end

endmodule
