module main_fsm (
	input  wire clk,
	input  wire reset,     // ACTIVE-low ASYNC RESET

	input wire start,
	
	input rx_valid,
	input aes_done,
	input tx_ready,
	input [7:0] rx_byte,
	input [127:0] out_block,
	output wire [7:0] tx_byte_out,
	
	output wire aes_start_out,
	output wire key_exp_start_out,
	output wire tx_start_out,
	
	output wire mem_key_rw_out,
	
	output wire [127:0] data_block,
	output wire [127:0] aes_key
);

    parameter IDLE        = 3'b000, 
              RECV_KEY    = 3'b001, 
              RECV_BLOCK   = 3'b010, 
              WAIT_AES    = 3'b011,
				  SEND_RESULT = 3'b100;


	 reg [2:0] curr_state, next_state;
	
    reg [7:0] key_buffer   [15:0];
    reg [7:0] Data_buffer [15:0];
    reg [7:0] out_block_internal [15:0];

    reg [3:0] key_count, key_count_reg;
    reg [3:0] Data_count, Data_count_reg;
    reg [3:0] send_count, send_count_reg;
	 
	 reg key_exp_start_reg;
	 reg aes_start_reg;
	 reg tx_start_reg;
	 
	 reg [7:0] tx_byte, tx_byte_reg;
				
	 reg aes_start; 
	 reg key_exp_start;
	 reg tx_start; 
	 
	 reg mem_key_rw;
	 reg we_out_block;
	 
	 assign key_exp_start_out = key_exp_start_reg;
	 assign aes_start_out = aes_start_reg; 
	 assign tx_start_out = tx_start_reg; 
	 
	 assign tx_byte_out = tx_byte_reg;
	 
	 assign mem_key_rw_out = mem_key_rw;
	 
	 
	 assign aes_key = {
		key_buffer[15], key_buffer[14], key_buffer[13], key_buffer[12],
		key_buffer[11], key_buffer[10], key_buffer[9],  key_buffer[8],
		key_buffer[7],  key_buffer[6],  key_buffer[5],  key_buffer[4],
		key_buffer[3],  key_buffer[2],  key_buffer[1],  key_buffer[0]
	};

	 assign data_block = {
		Data_buffer[15], Data_buffer[14], Data_buffer[13], Data_buffer[12],
		Data_buffer[11], Data_buffer[10], Data_buffer[9],  Data_buffer[8],
		Data_buffer[7],  Data_buffer[6],  Data_buffer[5],  Data_buffer[4],
		Data_buffer[3],  Data_buffer[2],  Data_buffer[1],  Data_buffer[0]
	};

	
	always @(posedge clk) begin
		 if (we_out_block) begin
			  out_block_internal[15] <= out_block[127:120];
			  out_block_internal[14] <= out_block[119:112];
			  out_block_internal[13] <= out_block[111:104];
			  out_block_internal[12] <= out_block[103:96];
			  out_block_internal[11] <= out_block[95:88];
			  out_block_internal[10] <= out_block[87:80];
			  out_block_internal[9]  <= out_block[79:72];
			  out_block_internal[8]  <= out_block[71:64];
			  out_block_internal[7]  <= out_block[63:56];
			  out_block_internal[6]  <= out_block[55:48];
			  out_block_internal[5]  <= out_block[47:40];
			  out_block_internal[4]  <= out_block[39:32];
			  out_block_internal[3]  <= out_block[31:24];
			  out_block_internal[2]  <= out_block[23:16];
			  out_block_internal[1]  <= out_block[15:8];
			  out_block_internal[0]  <= out_block[7:0];
		 end
	end

    // ------------------------------------
    // 1. State register
    // ------------------------------------
    always @(posedge clk) begin 
        if (!reset) begin
		  
				curr_state <= IDLE;
				
				key_count_reg <= 4'b0;
				Data_count_reg <= 4'b0; 
				send_count_reg <= 4'b0; 
				
				key_exp_start_reg <= 1'b0;
				aes_start_reg <= 1'b0;
				
				tx_start_reg <= 1'b0;
				tx_byte_reg <= 8'b0; 
        end 
        else begin 
		  
				curr_state <= next_state;
				
				key_count_reg <= key_count; 
				Data_count_reg <= Data_count; 
				send_count_reg <= send_count;
				
				key_exp_start_reg <= key_exp_start;	
				aes_start_reg <= aes_start;
				
				tx_start_reg <= tx_start;	
				tx_byte_reg <= tx_byte;	
        end 
    end 

    // ------------------------------------
    // 2. Next-state logic
    // ------------------------------------
    always @(*) begin 
        next_state = curr_state; 
        case (curr_state)  
            IDLE : begin
					if (start)
						next_state = RECV_KEY;
				end
                
            RECV_KEY: begin 
                if (rx_valid && key_count_reg == 4'b0)
                    next_state = RECV_BLOCK;
				end 
            
            RECV_BLOCK: begin 
                if (rx_valid && Data_count_reg == 4'b0)
                    next_state = WAIT_AES;
				end 
            
            WAIT_AES: begin 
					 if (aes_done)
                    next_state = SEND_RESULT;
				end
				
				SEND_RESULT: begin
				    if (tx_ready && send_count_reg == 4'd0)
                    next_state = IDLE;
				end

        endcase 
    end 

    // ------------------------------------
    // 3. Output logic
    // ------------------------------------
    always @(*) begin   
	 
				key_count = key_count_reg;
				Data_count = Data_count_reg; 
				send_count = send_count_reg; 
				
				aes_start = 1'b0;
				key_exp_start = key_exp_start_reg;
				tx_byte = tx_byte_reg;
				tx_start = 1'b0;
				mem_key_rw = 1'b0;
				we_out_block = 1'b0;
        case (curr_state)  
            IDLE : begin 
                key_count   = 4'd15;
                Data_count = 4'd15;
                send_count  = 4'd15;
					 
					 key_exp_start = 1'b0;
                aes_start = 1'b0;
                tx_start  = 1'b0;
				end 
            RECV_KEY: begin 
                if (rx_valid) begin
                    key_buffer[key_count] = rx_byte;
                    key_count = key_count - 4'b1;
						  if (key_count_reg == 4'b0)
								key_exp_start = 1'b1;
                end

            end
            RECV_BLOCK: begin 
                 if (rx_valid) begin
                    Data_buffer[Data_count] = rx_byte;
                    Data_count = Data_count - 4'b1;
						  if (Data_count_reg == 4'b0)
								aes_start = 1'b1;
					  end

            end
            WAIT_AES: begin 
				
				mem_key_rw = 1'b1;
				we_out_block = 1'b1;

				end
				SEND_RESULT: begin 
                if (tx_ready) begin
						tx_start = 1'b1; 
						tx_byte = out_block_internal[send_count];
						send_count = send_count - 4'b1;
                end
					 else 
						tx_start = 1'b0;
				end
        endcase
    end 

endmodule
