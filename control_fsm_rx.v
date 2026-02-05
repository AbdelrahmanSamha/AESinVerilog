module control_fsm_rx #(
    parameter integer KEY_SIZE  = 128,
    parameter integer MODE      = 0)
	(
    input  wire        clk,
    input  wire        rst_n,

    // UART RX
    input  wire        rx_valid,
    input  wire [7:0]  rx_byte,
	 
	
	 input  key_ready,
    input  iv_ready,  
    input  block_ready,
	
	 input key_expand_ready,
    // AES
    output reg         aes_start_out,
    output reg  [7:0]  aes_data_in,
	 
	
	output reg key_we,
	output reg	 iv_we,
	output reg block_we,
	
	output reg valid_in_key_aes,
	output reg valid_in_block_aes,
	
	output dec

);

    //============================================================
    // CONSTANTS
    //============================================================
    localparam SOF = 8'hA5;
    localparam EOF = 8'h5A;

    localparam CMD_AES = 8'h01;

    localparam ST_SENDING_KEY = 8'hA1;
    localparam ST_SENDING_IV  = 8'hA2;
	 
	 localparam integer KEY_BYTES =
        (KEY_SIZE == 128) ? 16 :
        (KEY_SIZE == 192) ? 24 :
        (KEY_SIZE == 256) ? 32 : 16;

    //============================================================
    // STATES
    //============================================================
    localparam S_WAIT_SOF = 3'd0;
    localparam S_CMD      = 3'd1;
    localparam S_FLAGS    = 3'd2;
    localparam S_LENGTH   = 3'd3;
    localparam S_PAYLOAD  = 3'd4;
    localparam S_WAIT_EOF = 3'd5;

    reg [2:0] state, next_state;

    //============================================================
    // REGISTERS
    //============================================================
    reg [7:0]  cmd, flags;
    reg [31:0] total_length;
    reg [2:0]  length_cnt;
	 
	 reg [3:0] iv_cnt;
    reg [31:0] data_cnt;
	 reg [4:0] key_cnt;
	 
	 
    reg [31:0] data_len;
    reg [4:0] iv_len;
	 
    reg aes_start;



    localparam PH_KEY  = 2'd0;
    localparam PH_IV   = 2'd1;
    localparam PH_DATA = 2'd2;

    reg [1:0] payload_phase;

    //============================================================
    // 1) STATE & REGISTER UPDATE (CLOCKED)
    //============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_WAIT_SOF;
            cmd           <= 0;
            flags         <= 0;
            total_length  <= 0;
            length_cnt    <= 0;
            key_cnt       <= 0;
            iv_cnt        <= 0;
            data_cnt      <= 0;
            data_len      <= 0;
            iv_len        <= 0;
            aes_start_out <= 0;
				valid_in_key_aes <=1'b0;
				valid_in_block_aes <=1'b0;
				
				
            payload_phase <= PH_KEY;
        end else begin
            state <= next_state;
				aes_start_out <= aes_start;
				
				
			if (next_state == S_WAIT_SOF) begin
            length_cnt   <= 0;
            key_cnt      <= 0;
            iv_cnt       <= 0;
            data_cnt     <= 0;
            aes_start_out <= 0;

        end else if (rx_valid) begin
                case (state)

                S_CMD:
                    cmd <= rx_byte;

                S_FLAGS: begin
                    flags       <= rx_byte;
                    total_length <= 0;

                    // -------- length format decode (NO FUNCTION) --------
                    case (rx_byte[5:4])
                        2'b00: length_cnt <= 3'd1;
                        2'b01: length_cnt <= 3'd2;
                        2'b10: length_cnt <= 3'd3;
                        2'b11: length_cnt <= 3'd4;
                    endcase
                end

                S_LENGTH: begin
                    total_length <= (total_length << 8) | rx_byte;
                    length_cnt   <= length_cnt - 1'b1;


                      payload_phase <= (KEY_BYTES != 0) ? PH_KEY :
                                         (iv_len  != 0) ? PH_IV  : PH_DATA;
                end

                S_PAYLOAD: begin
							
						 data_len <= total_length - KEY_BYTES - iv_len;

                    case (payload_phase)

                    PH_KEY: begin
                        key_cnt <= key_cnt + 1;
                        if (key_cnt + 1 == KEY_BYTES)
                            payload_phase <= (iv_len != 0) ? PH_IV : PH_DATA;
                    end

                    PH_IV: begin
                        iv_cnt <= iv_cnt + 1;
                        if (iv_cnt + 1 == iv_len)
                            payload_phase <= PH_DATA;
                    end

                    PH_DATA:
                        data_cnt <= data_cnt + 1;

                    endcase
                end

                endcase
            end
				
		  if (key_ready) begin      // later when adding other modes you need to check also when iv is ready then make the valid 1 
			//if (iv_ready) begin  
				valid_in_key_aes = 1'b1;
		  end 
		  
		  if (block_ready && key_expand_ready && !(next_state == S_WAIT_SOF)) begin 
				valid_in_block_aes = 1'b1;
		  end 
        end
    end

    //============================================================
    // 2) NEXT-STATE LOGIC (COMBINATIONAL)
    //============================================================
    always @(*) begin
        next_state = state;

        case (state)

        S_WAIT_SOF:
            if (rx_valid && rx_byte == SOF)
                next_state = S_CMD;

        S_CMD:
            if (rx_valid)
                next_state = S_FLAGS;

        S_FLAGS:
            if (rx_valid)
                next_state = S_LENGTH;

        S_LENGTH:
            if (rx_valid && length_cnt == 1)
                next_state = S_PAYLOAD;

        S_PAYLOAD:
            if (payload_phase == PH_DATA && data_cnt  == data_len)
                next_state = S_WAIT_EOF;

        S_WAIT_EOF:
            if (rx_valid && (rx_byte == EOF))
                next_state = S_WAIT_SOF;


        endcase
    end

    //============================================================
    // 3) OUTPUT / CONTROL LOGIC (COMBINATIONAL)
    //============================================================
    always @(*) begin
        aes_start      = 1'b0;
        aes_data_in    = rx_byte;
		key_we = 1'b0;
		iv_we = 1'b0;
		block_we = 1'b0;


        if (state == S_CMD) begin
		  aes_start = 1'b1;
		  end
        if (state == S_PAYLOAD && rx_valid) begin
            if (payload_phase == PH_KEY) begin
				key_we = 1'b1;
            end

            if (payload_phase == PH_IV) begin
				iv_we = 1'b1;
            end

            if (payload_phase == PH_DATA) begin
                block_we = 1'b1;
         //       if (data_cnt + 1  == data_len)
          //          aes_start = 1'b1;
            end
        end	  
    end
	
	assign dec = cmd[0] ;

endmodule
