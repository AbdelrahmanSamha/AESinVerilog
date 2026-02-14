// ============================================================
// TX CONTROL FSM (DATA-ONLY)
// - No CMD / FLAGS / LENGTH are transmitted anymore.
// - On aes_done:
//    * Normal: send 16 bytes ciphertext (aes_result) MSB-first
//    * BLOCK_LAB (cmd_in==CMD_BLOCK_LAB): send (Nr+1)*16 bytes round states
//      from round_rd_data (sync 1-cycle latency), then send ciphertext 16 bytes
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

    // optional: keep cmd_in only for BLOCK_LAB behavior
    input  wire [7:0]  cmd_in,

    // round memory read
    output reg  [3:0]  round_rd_addr,
    input  wire [127:0] round_rd_data,

    // status
    output reg         tx_busy,
    output reg         tx_done,
	 
    input  wire        sha_done,      
    input  wire [255:0] sha_result,

	 input  wire        echo_tx_start
	 
);

    // ------------------------------------------------------------
    // constants
    // ------------------------------------------------------------
    localparam [7:0]  CMD_BLOCK_LAB = 8'h02;
	 localparam [7:0]  CMD_SHA       = 8'h03;

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
        S_R_ADDR = 3'b001,  // drive addr only (no tx)
        S_R_SEND = 3'b010,  // send 16 bytes from round_rd_data
        S_DATA   = 3'b011,  // send 16 bytes of ciphertext
		  S_SHA    = 3'b100,   // send 32 bytes of sha_result
		  S_ECHO  =  3'b101;

    reg [2:0] state, next_state;

    // ------------------------------------------------------------
    // latched data
    // ------------------------------------------------------------
    reg [127:0] data_lat;
    reg         lab_lat;        // 1 if BLOCK_LAB frame
	 
    reg [255:0] sha_lat;
    reg [5:0]   sha_idx, sha_idx_n; // 0..31

    // counters
    reg [4:0]  data_idx, data_idx_n;      // 0..15
    reg [3:0]  round_idx, round_idx_n;    // 0..Nr
    reg [4:0]  rbyte_idx, rbyte_idx_n;    // 0..15

    wire last_round = (round_idx == (NUM_ROUNDS_DUMP - 1));

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
	 
		  reg [7:0] sha_byte_sel;
		  always @(*) begin
		      sha_byte_sel = 8'h00;
		   	case (sha_idx)
		   		6'd0:  sha_byte_sel = sha_lat[255:248];
		   		6'd1:  sha_byte_sel = sha_lat[247:240];
		   		6'd2:  sha_byte_sel = sha_lat[239:232];
		   		6'd3:  sha_byte_sel = sha_lat[231:224];
		   		6'd4:  sha_byte_sel = sha_lat[223:216];
		   		6'd5:  sha_byte_sel = sha_lat[215:208];
		   		6'd6:  sha_byte_sel = sha_lat[207:200];
		   		6'd7:  sha_byte_sel = sha_lat[199:192];
		   		6'd8:  sha_byte_sel = sha_lat[191:184];
		   		6'd9:  sha_byte_sel = sha_lat[183:176];
		   		6'd10: sha_byte_sel = sha_lat[175:168];
		   		6'd11: sha_byte_sel = sha_lat[167:160];
		   		6'd12: sha_byte_sel = sha_lat[159:152];
		   		6'd13: sha_byte_sel = sha_lat[151:144];
		   		6'd14: sha_byte_sel = sha_lat[143:136];
		   		6'd15: sha_byte_sel = sha_lat[135:128];
		   		6'd16: sha_byte_sel = sha_lat[127:120];
		   		6'd17: sha_byte_sel = sha_lat[119:112];
		   		6'd18: sha_byte_sel = sha_lat[111:104];
		   		6'd19: sha_byte_sel = sha_lat[103:96];
		   		6'd20: sha_byte_sel = sha_lat[95:88];
		   		6'd21: sha_byte_sel = sha_lat[87:80];
		   		6'd22: sha_byte_sel = sha_lat[79:72];
		   		6'd23: sha_byte_sel = sha_lat[71:64];
		   		6'd24: sha_byte_sel = sha_lat[63:56];
		   		6'd25: sha_byte_sel = sha_lat[55:48];
		   		6'd26: sha_byte_sel = sha_lat[47:40];
		   		6'd27: sha_byte_sel = sha_lat[39:32];
		   		6'd28: sha_byte_sel = sha_lat[31:24];
		   		6'd29: sha_byte_sel = sha_lat[23:16];
		   		6'd30: sha_byte_sel = sha_lat[15:8];
		   		default: sha_byte_sel = sha_lat[7:0];
		   	endcase
		   end
		   

    // ============================================================
    // 1) State register + latching on aes_done
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;

            data_lat  <= 128'd0;
            lab_lat   <= 1'b0;
				
				sha_lat  <= 256'd0;
				sha_idx  <= 6'd0;
				
            data_idx  <= 5'd0;
            round_idx <= 4'd0;
            rbyte_idx <= 5'd0;
				

        end else begin
            state <= next_state;

            data_idx  <= data_idx_n;
            round_idx <= round_idx_n;
            rbyte_idx <= rbyte_idx_n;
			   sha_idx   <= sha_idx_n;

            if (aes_done) begin
                data_lat  <= aes_result;
                lab_lat   <= (cmd_in == CMD_BLOCK_LAB);				 
					 
                data_idx  <= 5'd0;
                round_idx <= 4'd0;
                rbyte_idx <= 5'd0;
            end
				
            if (sha_done) begin
                sha_lat <= sha_result;
                sha_idx <= 6'd0;
            end	
        end
    end

    // ============================================================
    // 2) Next-state logic
    // ============================================================
    always @(*) begin
        next_state = state;

        case (state)
            S_IDLE: begin
				    if (echo_tx_start) 
							next_state = S_ECHO;
                else if (aes_done) begin
                    // decide immediately using cmd_in (same cycle as aes_done pulse)
                    if (cmd_in == CMD_BLOCK_LAB) next_state = S_R_ADDR;
                    else                         next_state = S_DATA;
                end
					 else if (sha_done && (cmd_in == CMD_SHA)) begin
							 next_state = S_SHA;
					 end
            end
				
				S_ECHO: begin
					if (tx_ready) next_state = S_IDLE;
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

				S_SHA: begin
					if (tx_ready) begin
						if (sha_idx == 6'd31) next_state = S_IDLE;
						else                  next_state = S_SHA;
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
        tx_valid = 1'b0;
        tx_byte  = 8'h00;
		  tx_done = 1'b0;

        data_idx_n  = data_idx;
        round_idx_n = round_idx;
        rbyte_idx_n = rbyte_idx;
		  sha_idx_n = sha_idx;


        tx_busy = (state != S_IDLE);

        // always drive address from current round index
        round_rd_addr = round_idx;

        case (state)
		  
				S_ECHO: begin
					tx_valid = 1'b1;
					tx_byte  = 8'h05;
				end
				
            S_R_ADDR: begin
                // no tx, just address setup
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

				S_SHA: begin
					tx_valid = 1'b1;
					tx_byte  = sha_byte_sel;
				
					if (tx_ready) begin
						if (sha_idx != 6'd31)
								sha_idx_n = sha_idx + 6'd1;
						else
								sha_idx_n = 6'd0;
					end
				end
				
        endcase
		  
				if ((state == S_DATA) && (next_state == S_IDLE))
						tx_done = 1'b1;
						
				if ((state == S_SHA) && (next_state == S_IDLE))
						tx_done = 1'b1;
						
			   if ((state == S_ECHO) && (next_state == S_IDLE)) 
				      tx_done = 1'b1;

    end

endmodule
