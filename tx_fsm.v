// ============================================================
// TX CONTROL FSM (Option A frame)
//
// TX frame:  CMD_RESP , FLAGS_ECHO , LENGTH(1..4 bytes) , DATA (N bytes)
// - CMD_RESP = cmd_in | 8'h80
// - FLAGS_ECHO = flags_in (optionally OR error flag into [7])
// - LENGTH bytes count = flags_in[5:4] + 1
// - LENGTH value = OUT_LEN_BYTES (number of DATA bytes we will transmit)
// - DATA here is 128-bit (16 bytes) from aes_result
//
// BLOCK_LAB behavior:
// - LENGTH stays 16 (ciphertext length only)
// - After LEN: send (Nr+1) * 16 bytes (round states) from round_rd_data
// - Then send final ciphertext 16 bytes
//
// Handshake:
// - tx_valid asserted only when we have a byte to send
// - byte advances only when (tx_valid && tx_ready)
//
// Notes:
// - Assumes round memory is synchronous, 1-cycle latency:
//   address driven in S_R_ADDR, data valid in next cycle S_R_SEND.
// - We DO NOT register round_rd_data (no round_lat) to avoid shifting.
// ============================================================

module tx_fsm #(
    parameter [7:0]  CMD_RESP_OR   = 8'h80,
    parameter integer KEY_SIZE     = 128
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        tx_ready,
    output reg         tx_valid,
    output reg  [7:0]  tx_byte,

    // from AES
    input  wire        aes_done,          // 1-cycle pulse when result ready
    input  wire [127:0] aes_result,       // 128-bit result

    // from buffer (echo back)
    input  wire [7:0]  cmd_in,
    input  wire [7:0]  flags_in,
    input  wire        error_flag,

    // round memory read
    output reg  [3:0]  round_rd_addr,
    input  wire [127:0] round_rd_data,

    // status
    output reg         tx_busy
);

    // ------------------------------------------------------------
    // constants
    // ------------------------------------------------------------
    localparam [31:0] OUT_LEN_BYTES = 32'd16;
    localparam [7:0]  CMD_BLOCK_LAB = 8'h02;

    localparam integer Nr =
        (KEY_SIZE == 128) ? 10 :
        (KEY_SIZE == 192) ? 12 :
        (KEY_SIZE == 256) ? 14 : 0;

    localparam integer NUM_ROUNDS_DUMP = Nr + 1; // 0..Nr

    // ------------------------------------------------------------
    // states
    // ------------------------------------------------------------
    localparam [2:0]
        S_IDLE   = 3'b000,
        S_CMD    = 3'b001,
        S_FLAGS  = 3'b010,
        S_LEN    = 3'b011,
        S_R_ADDR = 3'b100,  // drive addr only (no tx)
        S_R_SEND = 3'b101,  // send 16 bytes from round_rd_data
        S_DATA   = 3'b110;  // send 16 bytes of ciphertext

    reg [2:0] state, next_state;

    // ------------------------------------------------------------
    // latched frame fields
    // ------------------------------------------------------------
    reg [7:0]   cmd_lat;
    reg [7:0]   flags_lat;
    reg [31:0]  len_lat;
    reg [127:0] data_lat;

    // length bytes count (1..4)
    reg [2:0] len_bytes;

    // counters
    reg [2:0]  len_idx,  len_idx_n;
    reg [4:0]  data_idx, data_idx_n;

    // rounds controls
    reg        lab_lat;
    reg [3:0]  round_idx, round_idx_n;   // 0..Nr
    reg [4:0]  rbyte_idx, rbyte_idx_n;   // 0..15

    wire last_round = (round_idx == (NUM_ROUNDS_DUMP - 1));

    // ------------------------------------------------------------
    // LENGTH byte select (big-endian)
    // ------------------------------------------------------------
    reg [7:0] len_byte_sel;
    always @(*) begin
        len_byte_sel = 8'h00;
        case (len_bytes)
            3'd1: begin
                len_byte_sel = len_lat[7:0];
            end
            3'd2: begin
                if (len_idx == 3'd0) len_byte_sel = len_lat[15:8];
                else                 len_byte_sel = len_lat[7:0];
            end
            3'd3: begin
                if (len_idx == 3'd0)      len_byte_sel = len_lat[23:16];
                else if (len_idx == 3'd1) len_byte_sel = len_lat[15:8];
                else                       len_byte_sel = len_lat[7:0];
            end
            default: begin
                if (len_idx == 3'd0)      len_byte_sel = len_lat[31:24];
                else if (len_idx == 3'd1) len_byte_sel = len_lat[23:16];
                else if (len_idx == 3'd2) len_byte_sel = len_lat[15:8];
                else                       len_byte_sel = len_lat[7:0];
            end
        endcase
    end

    // ------------------------------------------------------------
    // helper: select byte MSB-first
    // - in S_R_SEND: from round_rd_data using rbyte_idx (DIRECT!)
    // - in S_DATA  : from data_lat using data_idx
    // ------------------------------------------------------------
    reg [7:0] data_byte_sel;
    always @(*) begin
        data_byte_sel = 8'h00;

        if (state == S_R_SEND) begin
            case (rbyte_idx)
                5'd0:  data_byte_sel = round_rd_data[127:120];
                5'd1:  data_byte_sel = round_rd_data[119:112];
                5'd2:  data_byte_sel = round_rd_data[111:104];
                5'd3:  data_byte_sel = round_rd_data[103:96];
                5'd4:  data_byte_sel = round_rd_data[95:88];
                5'd5:  data_byte_sel = round_rd_data[87:80];
                5'd6:  data_byte_sel = round_rd_data[79:72];
                5'd7:  data_byte_sel = round_rd_data[71:64];
                5'd8:  data_byte_sel = round_rd_data[63:56];
                5'd9:  data_byte_sel = round_rd_data[55:48];
                5'd10: data_byte_sel = round_rd_data[47:40];
                5'd11: data_byte_sel = round_rd_data[39:32];
                5'd12: data_byte_sel = round_rd_data[31:24];
                5'd13: data_byte_sel = round_rd_data[23:16];
                5'd14: data_byte_sel = round_rd_data[15:8];
                default: data_byte_sel = round_rd_data[7:0];
            endcase
        end else begin
            case (data_idx)
                5'd0:  data_byte_sel = data_lat[127:120];
                5'd1:  data_byte_sel = data_lat[119:112];
                5'd2:  data_byte_sel = data_lat[111:104];
                5'd3:  data_byte_sel = data_lat[103:96];
                5'd4:  data_byte_sel = data_lat[95:88];
                5'd5:  data_byte_sel = data_lat[87:80];
                5'd6:  data_byte_sel = data_lat[79:72];
                5'd7:  data_byte_sel = data_lat[71:64];
                5'd8:  data_byte_sel = data_lat[63:56];
                5'd9:  data_byte_sel = data_lat[55:48];
                5'd10: data_byte_sel = data_lat[47:40];
                5'd11: data_byte_sel = data_lat[39:32];
                5'd12: data_byte_sel = data_lat[31:24];
                5'd13: data_byte_sel = data_lat[23:16];
                5'd14: data_byte_sel = data_lat[15:8];
                default: data_byte_sel = data_lat[7:0];
            endcase
        end
    end

    // ============================================================
    // 1) State register + latching on aes_done
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;

            cmd_lat   <= 8'd0;
            flags_lat <= 8'd0;
            len_lat   <= 32'd0;
            data_lat  <= 128'd0;

            len_bytes <= 3'd1;

            len_idx   <= 3'd0;
            data_idx  <= 5'd0;

            lab_lat   <= 1'b0;
            round_idx <= 4'd0;
            rbyte_idx <= 5'd0;

        end else begin
            state    <= next_state;

            len_idx  <= len_idx_n;
            data_idx <= data_idx_n;

            round_idx <= round_idx_n;
            rbyte_idx <= rbyte_idx_n;

            if (aes_done) begin
                cmd_lat   <= (cmd_in | CMD_RESP_OR);
                flags_lat <= (error_flag) ? (flags_in | 8'b1000_0000) : flags_in;
                len_lat   <= OUT_LEN_BYTES;
                data_lat  <= aes_result;

                len_bytes <= ({1'b0, flags_in[5:4]} + 3'd1);

                lab_lat   <= (cmd_in == CMD_BLOCK_LAB);

                len_idx   <= 3'd0;
                data_idx  <= 5'd0;
                round_idx <= 4'd0;
                rbyte_idx <= 5'd0;
            end
        end
    end

    // ============================================================
    // 2) Next-state logic
    // ============================================================
    always @(*) begin
        next_state = state;

        case (state)
            S_IDLE:   if (aes_done) next_state = S_CMD;

            S_CMD:    if (tx_ready) next_state = S_FLAGS;

            S_FLAGS:  if (tx_ready) next_state = S_LEN;

            S_LEN: begin
                if (tx_ready) begin
                    if (len_idx == (len_bytes - 3'd1)) begin
                        if (lab_lat) next_state = S_R_ADDR;
                        else         next_state = S_DATA;
                    end else begin
                        next_state = S_LEN;
                    end
                end
            end

            S_R_ADDR: begin
                // address setup cycle; data valid next cycle in S_R_SEND
                next_state = S_R_SEND;
            end

            S_R_SEND: begin
                if (tx_ready) begin
                    if (rbyte_idx == 5'd15) begin
                        if (last_round) next_state = S_DATA;
                        else            next_state = S_R_ADDR;
                    end else begin
                        next_state = S_R_SEND;
                    end
                end
            end

            S_DATA: begin
                if (tx_ready) begin
                    if (data_idx == 5'd15) next_state = S_IDLE;
                    else                   next_state = S_DATA;
                end
            end

            default: next_state = S_IDLE;
        endcase
    end

    // ============================================================
    // 3) Output logic + counter updates
    // ============================================================
    always @(*) begin
        // defaults
        tx_valid  = 1'b0;
        tx_byte   = 8'h00;

        len_idx_n   = len_idx;
        data_idx_n  = data_idx;

        round_idx_n = round_idx;
        rbyte_idx_n = rbyte_idx;

        tx_busy = (state != S_IDLE);

        // always drive address from current round index
        round_rd_addr = round_idx;

        case (state)
            S_CMD: begin
                tx_valid = 1'b0;
                tx_byte  = cmd_lat;
            end

            S_FLAGS: begin
                tx_valid = 1'b0;
                tx_byte  = flags_lat;
            end

            S_LEN: begin
                tx_valid = 1'b0;
                tx_byte  = len_byte_sel;

                if (tx_ready) begin
                    if (len_idx != (len_bytes - 3'd1))
                        len_idx_n = len_idx + 3'd1;
                    else
                        len_idx_n = 3'd0;
                end
            end

            S_R_ADDR: begin
                // no tx here, just address setup
            end

            S_R_SEND: begin
                tx_valid = 1'b1;
                tx_byte  = data_byte_sel;

                if (tx_ready) begin
                    if (rbyte_idx != 5'd15) begin
                        rbyte_idx_n = rbyte_idx + 5'd1;
                    end else begin
                        rbyte_idx_n = 5'd0;

                        if (!last_round)
                            round_idx_n = round_idx + 4'd1;
                        else
                            round_idx_n = 4'd0;
                    end
                end
            end

            S_DATA: begin
                tx_valid = 1'b1;
                tx_byte  = data_byte_sel;

                if (tx_ready) begin
                    if (data_idx != 5'd15)
                        data_idx_n = data_idx + 5'd1;
                    else
                        data_idx_n = 5'd0;
                end
            end
        endcase
    end

endmodule
