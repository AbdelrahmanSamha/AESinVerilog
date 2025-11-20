module aes_keyexpand (
    input      	      clk,
    input  		         rst_n,
	 input 					init,
    input  wire [127:0] og_key,
	 output reg store_key_mem,
	 output reg [3:0] address, 
    output wire  [127:0] round_key,
	 output wire finish
);
   
	//-------------------------------------------------------------------------
	//	Keyexpantion happens in parallel of the rounds, we are trying to  
	// generate keys as we go in the algorithm in a way such that we 
	// dont require a large array of registers to hold the 44 key words. 
	// and because processing the round keys does consume cycles, we want 
	// to hide this latency by doing the following schema : 
	// 
	//							keys to use 		keys in process 
	//	
	// initial round  	original key 		round 1 key 
	// round 1 				round 1 key 		round 2 key 
	// round 2 				round 2 key 		round 3 key 
	// .						.						.
	// .						.						.
	// .						.						.
	// round 9 				round 9 key 		final round key 
	// round 10 			round 10 key		IDLE
	//
	// This design is really good because by using 4-32bit registers 
	// we can simply forget about previous keys as we advance in the rounds. 
	// also we are hiding the latency of the dependence between each round and 
	// its required key, such that in round x we would be processing round x+1 
	// key, so whenever a round starts it can just find its keys ready to use. 
	// saving significant area (from 1,408b to 128b) while also being able 
	// to read the key values quickly because the 4 registers will be directly 
	// connected to the round processing core, instead of having to look up 
	// an address. 
	//-------------------------------------------------------------------------
	
	//-------------------------------------------------------------------------
	// DATAPATH. (schematic can be found in the documnetation.) 
	//-------------------------------------------------------------------------
	//data path wires and registers: 
	reg [31:0] a, b, c, temp; 

	
	reg a_l, b_l, c_l, temp_l;
	reg a_s, b_s, c_s, temp_s, xor2_s;

	wire[31:0] a_mux, b_mux,c_mux, temp_mux, xor2_mux;
	wire[31:0] rotation, sbox;
	wire[31:0] xor1, xor2; 
	wire[31:0] rcon;
	// statemachine wires and registers: 
    reg [2:0] state, next_state;
	 reg [2:0] counter, next_counter;
	 reg [3:0] r_counter, next_r_counter; 
	 reg [5:0]iter_counter,next_iter_counter;
	
	
	always @(posedge clk) begin 
		if (!rst_n) begin 
			a		<= 32'b0; 
			b		<= 32'b0; 
			c		<= 32'b0; 
			temp	<= 32'b0; 
 
		end 
		else begin 
			if (a_l) a    <= a_mux;
			if (b_l) b    <= b_mux;		
			if (c_l) c 	  <= c_mux;		
			if (temp_l) temp <= temp_mux;		
		end 

	end 
	
	assign rotation[7:0] = temp[31:24];
	assign rotation[15:8] = temp[7:0];
	assign rotation[23:16] = temp[15:8];
	assign rotation[31:24] = temp[23:16];
	
   sbox ak0 (.in(rotation[7:0]),    .out(sbox[7:0]));

   sbox ak1 (.in(rotation[15:8]),   .out(sbox[15:8]));

   sbox ak2 (.in(rotation[23:16]),  .out(sbox[23:16]));

   sbox ak3 (.in(rotation[31:24]),  .out(sbox[31:24]));
	
	aes_rcon u_rcon ( .round(r_counter), .rcon_out(rcon) );
	
	
	assign xor1 =  sbox ^ rcon; 
	assign xor2 = xor2_mux ^ a; 
	
	

	
	mux2to1 #(32) amux (.in0(og_key[127:96]), .in1(b), .sel(a_s), .out(a_mux));
	mux2to1 #(32) bmux (.in0(og_key[95:64]), .in1(c), .sel(b_s), .out(b_mux));
	mux2to1 #(32) cmux (.in0(og_key[63:32]), .in1(temp), .sel(c_s), .out(c_mux));
	mux2to1 #(32) tmux (.in0(og_key[31:0]), .in1(xor2), .sel(temp_s), .out(temp_mux));
	mux2to1 #(32) xor2mux (.in0(temp), .in1(xor1), .sel(xor2_s), .out(xor2_mux));

	assign round_key = {a, b, c, temp};
	//-------------------------------------------------------------------------
	// Statemachine to control the datapath and comunicate with the aescore. (schematic can be found in the documnetation.) 
	//-------------------------------------------------------------------------
	
    //------------------------------------
    // State encoding
    //------------------------------------
    parameter IDLE  = 3'b000,
              INIT  = 3'b001,
				  INITSTOREMEM = 3'b010,
              EVAL  = 3'b011,
              STORE = 3'b100;


    //------------------------------------
    // 1. State register (sequential logic)
    //------------------------------------
    always @(posedge clk) begin
        if (!rst_n)begin 
            state <= IDLE;
				counter <= 3'b0;
				r_counter <= 4'd1;
				iter_counter<= 6'd4; 		
        end
		  else begin 
            state <= next_state;
				counter <= next_counter;
				r_counter <= next_r_counter;
				iter_counter <= next_iter_counter;
		  end	
    end

    //------------------------------------
    // 2. Next-state logic (combinational)
    //------------------------------------
    always @* begin
		  finish = 1'b0; 
        next_state = state;

        case (state)
            IDLE:   if (init) next_state = INIT;

            INIT:   next_state = INITSTOREMEM;
				
				INITSTOREMEM: next_state= EVAL; 

            EVAL:   if (counter == 3'd4 && r_counter == 4'd10)
								next_state = IDLE;
								finish	= 1'b1;
							else 
								next_state = STORE;


            STORE:  next_state = EVAL;       // back to EVAL

            default: next_state = IDLE;
        endcase
    end

    //------------------------------------
    // 3. Output logic (combinational)
    //------------------------------------
    always @* begin
        // default outputs
        a_l			= 1'b0;
        b_l     	= 1'b0;
        c_l			= 1'b0;
        temp_l	   = 1'b0;
        a_s		   = 1'b0;
        b_s			= 1'b0;
        c_s			= 1'b0;
		  temp_s 	= 1'b0;
		  xor2_s		= 1'b0;
		  store_key_mem = 1'b0; 
		  next_counter = counter;
		  next_r_counter = r_counter;
		  next_iter_counter = iter_counter;
        case (state)
            IDLE: begin
               // reset all FSM registers
	
					next_counter       = 3'd0;
					next_r_counter     = 4'd1;
					next_iter_counter  = 6'd4;
	
					
					a_l    = 1'b0;
					b_l    = 1'b0;
					c_l    = 1'b0;
					temp_l = 1'b0;

	
					// select the original key (all zeros after reset)
					a_s    = 1'b0;
					b_s    = 1'b0;
					c_s    = 1'b0;
					temp_s = 1'b0;
	
					// force xor2 = temp (clears temp path)
					xor2_s = 1'b0;
            end

            INIT: begin
                a_l			= 1'b1;
					 b_l     	= 1'b1;
					 c_l			= 1'b1;
					 temp_l	   = 1'b1;
					 a_s		   = 1'b0;
					 b_s			= 1'b0;
					 c_s			= 1'b0;
					 temp_s 		= 1'b0;
            end
				
				INITSTOREMEM : begin 
					store_key_mem = 1'b1;
					address = 4'd0;
					
				end 

            EVAL: begin
                if (counter < 3'd4)begin 
						next_counter = counter + 1;   	
					 end 
					 else if (counter == 3'd4) begin 
						next_counter = 3'd1;
						next_r_counter = r_counter +1;
						store_key_mem = 1'b1;
						address = r_counter ;
						
					 end 
				end

            

            STORE: begin
                a_l			= 1'b1;
					 b_l     	= 1'b1;
					 c_l			= 1'b1;
					 temp_l	   = 1'b1;
					 a_s		   = 1'b1;
					 b_s			= 1'b1;
					 c_s			= 1'b1;
					 temp_s 		= 1'b1;
					 next_iter_counter = iter_counter +1;
					 if (iter_counter[1:0]== 2'b00) begin 
						xor2_s = 1'b1; 
					 end 
            end
        endcase
    end
	 
endmodule
