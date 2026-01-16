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
    output reg [3:0] key_address,
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
               SETUP      = 3'b001,
               INIT_ROUND = 3'b010,
               GET_KEY    = 3'b011,
               ITERATE    = 3'b100,
               FINAL      = 3'b101;

    reg [2:0]   state, next_state;
    reg [3:0]   round_counter, next_round_counter;
    reg [127:0] encstate, next_encstate;
    wire [127:0] round_encstate;
    reg          final_round_signal;
    reg          next_done;

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
                next_state = INIT_ROUND;

            INIT_ROUND:
                next_state = GET_KEY;

            GET_KEY:
                next_state = ITERATE;

            ITERATE: begin
                if (!dec && round_counter < (Nr - 1))
                    next_state = GET_KEY;
                else if (dec && round_counter > 1)
                    next_state = GET_KEY;
                else
                    next_state = FINAL;
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
        key_address        = 4'b0;
        next_done          = done;

        case (state)
            IDLE: begin
                next_encstate = 128'd0;
                next_done     = 1'b0;
                next_round_counter = dec ? LAST_KEY : 4'd0;
            end

            SETUP: begin
                key_address = dec ? LAST_KEY : 4'd0;
            end

            INIT_ROUND: begin
                next_encstate = plaintext ^ roundkey;
                next_round_counter =
                    dec ? round_counter - 4'd1 :
                          round_counter + 4'd1;
            end

            GET_KEY: begin
                key_address = round_counter;
            end

            ITERATE: begin
                next_encstate = round_encstate;
                next_round_counter =
                    dec ? round_counter - 4'd1 :
                          round_counter + 4'd1;

                if (!dec && round_counter == (Nr - 1))
                    key_address = LAST_KEY;
                else if (dec && round_counter == 4'd0)
                    key_address = 4'd0;
            end

            FINAL: begin
                final_round_signal = 1'b1;
                next_encstate = round_encstate;
                next_done = 1'b1;
            end
        endcase
    end

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
