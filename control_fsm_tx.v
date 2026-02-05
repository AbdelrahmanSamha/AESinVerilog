module control_fsm_tx (
    input  wire        clk,
    input  wire        rst_n,

    // UART TX interface
    input  wire        tx_ready,
    output reg         tx_valid,
    output reg [7:0]   tx_byte,

    // From AES core
    input  wire        aes_done,
    input  wire [127:0] aes_result,

    // Optional error input
    input  wire        error_flag
);

    //============================================================
    // CONSTANTS
    //============================================================
    localparam SOF = 8'hA5;
    localparam EOF = 8'h5A;
	 
    localparam FLAGS = 8'h77;

    localparam CMD_AES_RESULT = 8'h81;

    localparam DATA_LEN = 8'd16;

    //============================================================
    // STATES
    //============================================================
    localparam T_IDLE      = 3'd0;
    localparam T_SOF       = 3'd1;
    localparam T_CMD       = 3'd2;
    localparam T_FLAGS     = 3'd3;
    localparam T_LEN       = 3'd4;
    localparam T_PAYLOAD   = 3'd5;
    localparam T_EOF       = 3'd6;

    reg [2:0] state, next_state;

    //============================================================
    // REGISTERS
    //============================================================
    reg [3:0] data_cnt;
    reg [127:0] result_buf;

    //============================================================
    // STATE REGISTER
    //============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= T_IDLE;
            data_cnt  <= 4'd0;
            result_buf <= 128'd0;
        end else begin
            state <= next_state;

            // Latch AES result once
            if (aes_done) begin
                result_buf <= aes_result;
            end

            if (state == T_PAYLOAD && tx_ready)
                data_cnt <= data_cnt + 1'b1;
            else if (state == T_IDLE)
                data_cnt <= 4'd0;
        end
    end

    //============================================================
    // NEXT STATE LOGIC
    //============================================================
    always @(*) begin
        next_state = state;

        case (state)

        T_IDLE:
            if (aes_done)
                next_state = T_SOF;

        T_SOF:
            if (tx_ready)
                next_state = T_CMD;

        T_CMD:
            if (tx_ready)
                next_state = T_FLAGS;

        T_FLAGS:
            if (tx_ready)
                next_state = T_LEN;

        T_LEN:
            if (tx_ready)
                next_state = T_PAYLOAD;

        T_PAYLOAD:
            if (tx_ready && data_cnt == DATA_LEN - 1)
                next_state = T_EOF;

        T_EOF:
            if (tx_ready)
                next_state = T_IDLE;

        endcase
    end

    //============================================================
    // OUTPUT LOGIC
    //============================================================
    always @(*) begin
        tx_valid = 1'b0;
        tx_byte  = 8'h00;

        case (state)

        T_SOF: begin
            tx_valid = 1'b1;
            tx_byte  = SOF;
        end

        T_CMD: begin
            tx_valid = 1'b1;
            tx_byte  = CMD_AES_RESULT;
        end

        T_FLAGS: begin
            tx_valid = 1'b1;
            tx_byte  = FLAGS;
            // bit0 = SUCCESS, bit2 = ERROR
        end

        T_LEN: begin
            tx_valid = 1'b1;
            tx_byte  = DATA_LEN;
        end

        T_PAYLOAD: begin
            tx_valid = 1'b1;
            tx_byte  = result_buf[127 - (data_cnt * 8) -: 8];
        end

        T_EOF: begin
            tx_valid = 1'b1;
            tx_byte  = EOF;
        end

        endcase
    end

endmodule
