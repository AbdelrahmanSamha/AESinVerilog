module block_encrypt #(
    parameter integer KEY_SIZE = 128   // 128, 192, 256
)(
    input           clk,
    input           rst_n,
    input           start,
    input           dec,
    input  [127:0]  plaintext,
    input  [127:0]  roundkey,
    output [127:0]  ciphertext,
    output [3:0] key_address,
    output reg      done
);

    // -------------------------------------------------
    // AES parameters derived from KEY_SIZE
    // -------------------------------------------------
    localparam integer Nk =
        (KEY_SIZE == 128) ? 4 :
        (KEY_SIZE == 192) ? 6 :
        (KEY_SIZE == 256) ? 8 : 0;

    localparam integer Nr =
        (KEY_SIZE == 128) ? 10 :
        (KEY_SIZE == 192) ? 12 :
        (KEY_SIZE == 256) ? 14 : 0;

    localparam [3:0] LAST_KEY = Nr[3:0];

    // -------------------------------------------------
    // FSM state encoding
    // -------------------------------------------------
    localparam IDLE       = 3'b000,
               SETUP    = 3'b001,
               ITERATE    = 3'b010,
               FINAL      = 3'b011;

    reg [2:0]   state, next_state;
    reg [3:0]   round_counter, next_round_counter;
    reg [127:0] encstate, next_encstate;
    wire [127:0] round_encstate;
    reg          final_round_signal;
    reg          next_done;
	 wire 		  last_round_signal;
	 
	 assign last_round_signal = ((!dec && round_counter == (Nr - 1))|| (dec && round_counter == 1)); 


    // -------------------------------------------------
    // 1. State register
    // -------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            done  <= 1'b0;
            encstate <= 128'b0;
            round_counter <= dec ? LAST_KEY : 4'd0;
        end else begin
            state <= next_state;
            encstate <= next_encstate;
            round_counter <= next_round_counter;
            done <= next_done;
        end
    end
	 
	 

    // -------------------------------------------------
    // 2. Next-state logic
    // -------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:
                if (start) next_state = SETUP;
					 
            SETUP:
                next_state = ITERATE;

            ITERATE: begin
                if (last_round_signal)
                    next_state = FINAL;
					 else 
						  next_state = ITERATE;
            end

            FINAL:
                next_state = IDLE;
        endcase
    end

    // -------------------------------------------------
    // 3. Output logic
    // -------------------------------------------------
    always @(*) begin
        next_round_counter = round_counter;
        next_encstate      = encstate;
        final_round_signal = 1'b0;
        next_done          = done;

        case (state)
            IDLE: begin
                next_done     = 1'b0;
                next_round_counter = dec ? LAST_KEY : 4'd0;  // key = 0 / 10 
            end

            SETUP: begin
                next_encstate = plaintext ^ roundkey;
                next_round_counter =
                    dec ? round_counter - 4'd1 :
                          round_counter + 4'd1;
								 
            end

            ITERATE: begin
                next_encstate = round_encstate;
                next_round_counter =
                    dec ? round_counter - 4'd1 :
                          round_counter + 4'd1;
            end

            FINAL: begin
                final_round_signal = 1'b1;
                next_encstate = round_encstate;
                next_done = 1'b1;
            end
        endcase
    end

	assign key_address = next_round_counter;
    // -------------------------------------------------
    // AES round function (combinational)
    // -------------------------------------------------
    aes_round round_trans (
        .state_in(encstate),
        .round_key(roundkey),
        .final_round(final_round_signal),
        .state_out(round_encstate),
        .dec(dec)
    );

    assign ciphertext = encstate;

endmodule
