module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 921600
)(
    input  wire clk,
    input  wire reset,       // ACTIVE-low ASYNC RESET
    input  wire tx_start,    // user asserts for one cycle to send
    input  wire [7:0] tx_byte,
    output wire uart_tx,
    output wire tx_ready
);

    localparam WINDOW = CLK_FREQ / BAUD;

    parameter TX_IDLE  = 3'b000,
              TX_START = 3'b001,
              TX_DATA  = 3'b010,
              TX_STOP  = 3'b011,
				  TX_CYCLE = 3'b100;

    reg [2:0] tx_state, next_tx_state;
    reg [8:0] tx_count, tx_count_next;
    reg [3:0] tx_bits,  tx_bits_next;

    reg [7:0] tx_shift, tx_shift_next;

    reg       tx_reg, tx_reg_next;
    reg       tx_ready_reg, tx_ready_next;

    assign uart_tx   = tx_reg;
    assign tx_ready  = tx_ready_reg;

    // ------------------------------------------------------------
    // 1. State register
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (!reset) begin
            tx_state <= TX_IDLE;
            tx_count <= 9'd0;
            tx_bits  <= 4'd0;
            tx_shift <= 8'd0;

            tx_reg   <= 1'b1;
            tx_ready_reg <= 1'b1;
        end 
        else begin
            tx_state <= next_tx_state;
            tx_count <= tx_count_next;
            tx_bits  <= tx_bits_next;
            tx_shift <= tx_shift_next;

            tx_reg   <= tx_reg_next;
            tx_ready_reg <= tx_ready_next;
        end
    end

    // ------------------------------------------------------------
    // 2. Next-state logic
    // ------------------------------------------------------------
    always @(*) begin
        next_tx_state = tx_state;

        case (tx_state)

            TX_IDLE: begin
                if (tx_start)
                    next_tx_state = TX_START;
                else
                    next_tx_state = TX_IDLE;
            end

            TX_START:
                if (tx_count == 9'd0)
                    next_tx_state = TX_DATA;

            TX_DATA:
                if (tx_bits == 4'd8)
                    next_tx_state = TX_STOP;

            TX_STOP:
                if (tx_count == 9'd0)
                    next_tx_state = TX_CYCLE;
				
				TX_CYCLE: 
							next_tx_state = TX_IDLE; 

        endcase
    end

    // ------------------------------------------------------------
    // 3. Output logic
    // ------------------------------------------------------------
    always @(*) begin
        tx_count_next = tx_count;
        tx_bits_next  = tx_bits;
        tx_shift_next = tx_shift;

        tx_reg_next     = tx_reg;
        tx_ready_next   = tx_ready_reg;

        case (tx_state)

            TX_IDLE: begin
                tx_reg_next   = 1'b1;
                tx_ready_next = 1'b1;

                if (tx_start) begin
                    tx_ready_next = 1'b0;
                    tx_shift_next = tx_byte;
                    tx_bits_next  = 4'd0;
                    tx_count_next = WINDOW;

                    tx_reg_next   = 1'b0;  // start bit
                end
            end

            TX_START: begin
                tx_ready_next = 1'b0;
                tx_reg_next   = 1'b0;

                if (tx_count == 9'd0)
                    tx_count_next = WINDOW;
                else
                    tx_count_next = tx_count - 9'd1;
            end

            TX_DATA: begin
                tx_ready_next = 1'b0;
                tx_reg_next   = tx_shift_next[0];

                if (tx_count == 9'd0) begin
                    tx_shift_next = {1'b0, tx_shift_next[7:1]};
                    tx_bits_next  = tx_bits_next + 4'd1;
                    tx_count_next = WINDOW;
                end else
                    tx_count_next = tx_count - 9'd1;
            end

            TX_STOP: begin
                tx_ready_next = 1'b0;
                tx_reg_next   = 1'b1;

                if (tx_count == 9'd0)
                    tx_count_next = WINDOW;
                else
                    tx_count_next = tx_count - 9'd1;
            end
				
				TX_CYCLE: 
					tx_ready_next = 1'b1;

        endcase
    end

endmodule
