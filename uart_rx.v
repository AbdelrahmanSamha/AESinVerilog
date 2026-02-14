module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 921600
)(
    input  wire clk,
    input  wire reset,     // ACTIVE-low ASYNC RESET
    input  wire uart_rx,
    output wire [7:0] rx_byte,
    output wire        rx_valid
);

    localparam RX_IDLE  = 2'b00, 
              RX_START = 2'b01, 
              RX_DATA  = 2'b10, 
              RX_STOP  = 2'b11; 

    localparam WINDOW = CLK_FREQ / BAUD;

    reg [1:0] rx_state, next_rx_state; 
    reg [8:0] rx_count, rx_count_next; 
    reg [3:0] rx_bits , rx_bits_next; 

    reg [7:0] rx_shift, rx_shift_next;
    reg [7:0] rx_byte_reg, rx_byte_next;
    reg       rx_valid_reg, rx_valid_next;

    assign rx_byte  = rx_byte_reg;
    assign rx_valid = rx_valid_reg;

    // ------------------------------------
    // 1. State register
    // ------------------------------------
    always @(posedge clk) begin 
        if (!reset) begin 
            rx_state <= 2'b00; 
            rx_count <= 9'd0;
            rx_bits  <= 4'd0;
            rx_shift <= 8'd0; 
            rx_byte_reg <= 8'd0;
            rx_valid_reg <= 1'b0; 
        end 
        else begin 
            rx_state <= next_rx_state; 
            rx_count <= rx_count_next; 
            rx_bits  <= rx_bits_next;
            rx_shift <= rx_shift_next; 
            rx_byte_reg  <= rx_byte_next; 
            rx_valid_reg <= rx_valid_next; 
        end 
    end 

    // ------------------------------------
    // 2. Next-state logic
    // ------------------------------------
    always @(*) begin 
        next_rx_state = rx_state; 
        case (rx_state)  
            RX_IDLE :
                if (uart_rx == 1'b0)
                    next_rx_state = RX_START; 
                else
                    next_rx_state = RX_IDLE; 
                
            RX_START: begin 
                if ((rx_count == 9'd0) && (uart_rx == 1'b0))
                    next_rx_state= RX_DATA; 
                else if (uart_rx == 1'b1)
                    next_rx_state = RX_IDLE; 
                else 
                    next_rx_state = RX_START;
            end 
            
            RX_DATA : begin 
                if (rx_bits == 4'd8)
                    next_rx_state = RX_STOP;
            end 
            
            RX_STOP :
                if (rx_count == 9'd0)
                    next_rx_state = RX_IDLE; 
        endcase 
    end 
        
    // ------------------------------------
    // 3. Output logic
    // ------------------------------------
    always @(*) begin    
        rx_count_next = rx_count; 
        rx_shift_next = rx_shift; 
        rx_bits_next  = rx_bits;
        rx_valid_next = rx_valid_reg;
        rx_byte_next  = rx_byte_reg; 
        
        case (rx_state) 
            RX_IDLE : begin 
                rx_count_next = WINDOW/2;
                rx_valid_next = 1'b0;
                rx_shift_next = 8'd0;
                rx_bits_next  = 4'd0;
                rx_byte_next  = rx_byte_reg;
            end 
                        
            RX_START: begin
                if ((rx_count == 9'd0) && (uart_rx == 1'b0))
                    rx_count_next = WINDOW; 
                else 
                    rx_count_next = rx_count_next - 9'd1; 
            end 
                
            RX_DATA : begin
                if (rx_count == 9'd0) begin 
                    rx_count_next = WINDOW; 
                    rx_shift_next = {uart_rx, rx_shift_next[7:1]};
                    rx_bits_next  = rx_bits_next + 4'd1;
                end 
                else 
                    rx_count_next = rx_count_next - 9'd1; 
            end 
                
            RX_STOP : begin 
                if (rx_count == 9'd0) begin 
                    rx_count_next = WINDOW; 
                    rx_byte_next  = rx_shift;
                    rx_valid_next = 1'b1; 
                end 
                else 
                    rx_count_next = rx_count_next - 9'd1; 
            end 
        endcase
    end 

endmodule
