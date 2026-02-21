module ECDH (
    input clk, 
    input rst_n, 
    input pll_locked,
    input start,                    
    input [255:0] scalar,
    input [255:0] u_coordinate, 
    
    output [255:0] result, 
    output reg done                 // ← Changed to reg
); 

    // State Encoding
    localparam IDLE        = 3'd0;
    localparam INITIALIZER = 3'd1;
    localparam MAINLOOP    = 3'd2;    
    localparam FINALIZER   = 3'd3;
    localparam DONE_STATE  = 3'd4; 

    //=========================================================================
    // Wire Declarations
    //=========================================================================
    
    // MAU wires 
    wire [255:0] mau_result; 
    wire mau_done;
    reg mau_start;                  // ← Changed to reg (assigned in always)
    reg [1:0] mau_operation;        // ← Changed to reg
    
    // Memory wires 
    wire [255:0] mem_q;
    reg [255:0] mem_d;              // ← Changed to reg
    reg memwren;                    // ← Changed to reg
    reg [4:0] mem_address;          // ← Changed to reg
    
    // Initializer wires
    wire [255:0] init_d;
    wire [4:0] init_address;
    wire start_initializer;
    wire done_initializer;
	 wire init_memwren;
    
    // Main Loop wires
    wire [255:0] loop_d;
    wire [4:0] loop_address;
    wire loop_memwren;
    wire start_main_loop;
    wire done_main_loop;
    wire loop_mau_start;            // ← Added
    wire [1:0] loop_mau_operation;  // ← Added
    wire loop_helper_start;         // ← Added
    wire [4:0] loop_adrs1;          // ← Added
    wire [4:0] loop_adrs2;          // ← Added
    wire loop_r_swap;               // ← Added
    
    // Finalizer wires
    wire [255:0] final_d;
    wire [4:0] final_address;
    wire final_memwren;             // ← Added
    wire start_finalizer;
    wire done_finalizer;            // ← Fixed typo
    wire final_mau_start;           // ← Added
    wire [1:0] final_mau_operation; // ← Added
    wire final_helper_start;        // ← Added
    wire [4:0] final_adrs1;         // ← Added
    wire [4:0] final_adrs2;         // ← Added
    
    // Helper wires
    reg helper_start;               // ← Changed to reg
    wire helper_done; 
    reg [4:0] helper_adrs1;         // ← Changed to reg
    reg [4:0] helper_adrs2;         // ← Changed to reg
    wire [255:0] helper_w1;
    wire [255:0] helper_w2; 
    wire [4:0] helper_mem_address; 
    
    // State registers
    reg [2:0] r_state, w_next_state;
    
    //=========================================================================
    // Always Block 1: Sequential Logic (State Register Update)
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state <= 3'd0;
        end
        else begin
            r_state <= w_next_state;
        end
    end
    
    //=========================================================================
    // Always Block 2: Next State Logic
    //=========================================================================
    always @(*) begin
        w_next_state = r_state;  // Default: hold current state
    
        case (r_state)
            IDLE: begin
                if (start && pll_locked) w_next_state = INITIALIZER; 
            end
            
            INITIALIZER: begin
                if (done_initializer) w_next_state = MAINLOOP; 
            end
            
            MAINLOOP: begin
                if (done_main_loop) w_next_state = FINALIZER; 
            end
            
            FINALIZER: begin 
                if (done_finalizer) w_next_state = DONE_STATE;  // ← Fixed typo
            end 
            
            DONE_STATE: begin 
                w_next_state = IDLE; 
            end 
            
            default: w_next_state = IDLE;
        endcase
    end
    
    //=========================================================================
    // Always Block 3: Output Logic
    //=========================================================================
    always @(*) begin
        // Default assignments
        mem_d = 256'b0;              // ← Fixed typo from memd
        mem_address = 5'b0;
        helper_start = 1'b0;
        helper_adrs1 = 5'd0;
        helper_adrs2 = 5'd0;
        memwren = 1'b0;
        mau_operation = 2'b00; 
        mau_start = 1'b0;
        done = 1'b0;
        
        case (r_state)
            IDLE: begin
                // All defaults
            end
            
            INITIALIZER: begin
                mem_d = init_d;          // ← Fixed typo
                mem_address = init_address;
                memwren = init_memwren;          
            end
            
            MAINLOOP: begin
                mem_d = loop_d;          // ← Fixed typo
                mau_operation = loop_mau_operation; 
                mau_start = loop_mau_start; 
                helper_start = loop_helper_start;
                helper_adrs1 = loop_adrs1;
                helper_adrs2 = loop_adrs2;
                memwren = loop_memwren;
                
                // Mux memory address: loop writes OR helper reads
                if (loop_memwren) 
                    mem_address = loop_address; 
                else 
                    mem_address = helper_mem_address; 
            end
            
            FINALIZER: begin
                mau_start = final_mau_start;
                mau_operation = final_mau_operation; 
                mem_d = final_d;         // ← Fixed typo
                helper_start = final_helper_start; 
                helper_adrs1 = final_adrs1;
                helper_adrs2 = final_adrs2;
                memwren = final_memwren; // ← Added
                
                // Mux memory address: finalizer writes OR helper reads
                if (final_memwren) 
                    mem_address = final_address; 
                else 
                    mem_address = helper_mem_address;
            end
            
            DONE_STATE: begin
                done = 1'b1;
            end
            
            default: begin
                // All defaults
            end
        endcase
    end    
    
    //=========================================================================
    // Module Instantiations
    //=========================================================================
    
    // INITIALIZER INSTANCE 
    ECDH_initializer ECDHinit(
        .clk(clk), 
        .rst_n(rst_n), 
        .start(start_initializer), 
        .scalar(scalar), 
        .u_coordinate(u_coordinate),
        .memdata(init_d),
        .memaddress(init_address),
		  .memwren(init_memwren),
        .done(done_initializer)
    ); 
    
    // Initializer starts in INITIALIZER state
    assign start_initializer = (r_state == INITIALIZER);
    
    // MAIN LOOP INSTANCE
    ECDH_MAIN_LOOP ecdh_main_loop (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_main_loop),
        .done(done_main_loop),
        
        // MAU interface
        .mau_done(mau_done),
        .mau_start(loop_mau_start),
        .mau_operation(loop_mau_operation),
        .mau_result(mau_result),
        
        // Memory interface
        .mem_data(loop_d),
        .mem_address(loop_address),
        .memwren(loop_memwren),
        
        // Helper interface
        .helper_done(helper_done),
        .helper_start(loop_helper_start),
        .w1(helper_w1),
        .w2(helper_w2),
        .adrs1(loop_adrs1),
        .adrs2(loop_adrs2),
        
        // Finalizer interface
        .r_swap(loop_r_swap)
    );
    
    // Main loop starts in MAINLOOP state
    assign start_main_loop = (r_state == MAINLOOP);
    
    // HELPER INSTANCE
    // Reads two locations from memory, places them into Working register 1 and 2
    ECDH_helper ECDH_helper_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(helper_start),
        .adrs1(helper_adrs1),
        .adrs2(helper_adrs2),
        .w1(helper_w1),
        .w2(helper_w2),
        .memaddress(helper_mem_address),
        .mem_q(mem_q),
        .done(helper_done)
    );
    
    // FINALIZER INSTANCE
    ECDH_FINALIZER ECDH_FINALIZER_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_finalizer),
        
        // MAU interface
        .mau_done(mau_done),
        .mau_start(final_mau_start),
        .mau_operation(final_mau_operation),
        .mau_result(mau_result),
        
        // Memory interface
        .mem_data(final_d),
        .mem_address(final_address),
        .memwren(final_memwren),
        
        // Helper interface
        .helper_done(helper_done),
        .helper_start(final_helper_start),
        .w1(helper_w1),
        .w2(helper_w2),
        .adrs1(final_adrs1),
        .adrs2(final_adrs2),
        
        // Loop interface
        .r_swap(loop_r_swap),
        .final_result(result),  // The actual final result leaving the entire module
        .done(done_finalizer)
    );
    
    // Finalizer starts in FINALIZER state
    assign start_finalizer = (r_state == FINALIZER);
    
    // MAU INSTANCE
    MAU u_mau(
        .clk(clk),
        .rst_n(rst_n),            // ← MAU expects active-high reset
        .start(mau_start),
        .operation(mau_operation),
        .a(helper_w1),
        .b(helper_w2),
        .result(mau_result),
        .done(mau_done)
    );
    
    // MEMORY INSTANCE
    ECDH_mem ecdhram (
        .clock(clk),
        .address(mem_address),   // 5 bits
        .data(mem_d),            // 256 bits
        .wren(memwren),
        .q(mem_q)
    );
/*
	 wire [255:0] mem_q_mirror;
	 ECDH_mem_mirror ecdhram_mirror (
    .clock(clk),
    .address(mem_address),   // Same inputs
    .data(mem_d),            // Same inputs
    .wren(memwren),          // Same inputs
    .q(mem_q_mirror)         // Different output (not connected)
);
	*/ 
endmodule



module ECDH_initializer (
	input clk, 
	input rst_n, 
	
	input start, 
	input [255:0] scalar, 
	input [255:0] u_coordinate,
	output reg [255:0] memdata,
	output reg [4:0] memaddress,
	output reg memwren, 
	output reg done

); 

	reg [2:0] r_state, w_next_state;
	reg [255:0] scalar_modified; 
	
	
	//=========================================================================
	// Always Block 1: Sequential Logic (State Register Update)
	//=========================================================================
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			r_state <= 3'd0;
		end
		else begin
			r_state <= w_next_state;
		end
	end
    
	//=========================================================================
	// Always Block 2: Next State Logic
	//=========================================================================
	always @(*) begin
		w_next_state = r_state;  // Default: hold current state
	
		case (r_state)
			3'd0: begin
				if (start) w_next_state = 4'd1; 
			end
            
			3'd1: begin
				w_next_state = 4'd2;
			end
            
			3'd2: begin
				w_next_state = 4'd3;
			end
            
			3'd3: begin
				w_next_state = 4'd4;
			end
			
			3'd4: begin
				w_next_state = 4'd5;
			end
			3'd5: begin
				w_next_state = 4'd6;
			end
			3'd6: begin
				w_next_state = 4'd7;
			end
			3'd7: begin
				w_next_state = 4'd0;
			end

		
		endcase
	end
    
	//=========================================================================
	// Always Block 3: Output Logic
	//=========================================================================
	always @(*) begin
	scalar_modified = scalar;
	done = 1'b0; 
	memaddress = 5'd0; 
	memdata = 256'd0;
	memwren = 1'b0;
		case (r_state)
			3'd0: begin
				
			end
            
			3'd1: begin
				scalar_modified[2:0] = 3'b0; 
				scalar_modified[254] = 3'b1;
				scalar_modified[255] = 3'b0;
				memdata = scalar_modified; 
				memaddress = 5'd0; 
				memwren = 1'b1;
			end
            
			3'd2: begin
				memdata = u_coordinate; 
				memaddress = 5'd1; 
				memwren = 1'b1;
			end
            
			3'd3: begin
				memdata = 256'b1; 
				memaddress = 5'd2;
				memwren = 1'b1;	
			end
			
			3'd4: begin
				memdata = 256'b0; 
				memaddress = 5'd3;
				memwren = 1'b1;
			end
			3'd5: begin
				memdata = u_coordinate; 
				memaddress = 5'd4;
				memwren = 1'b1;
			end
			3'd6: begin
				memdata = 256'b1; 
				memaddress = 5'd5;
				memwren = 1'b1;
			end
			3'd7: begin
				done = 4'd1;
			end

		endcase
	end	


endmodule 


module ECDH_MAIN_LOOP (
    input  wire clk,
    input  wire rst_n,
  
    input  start,
	 
 

	 
	 //mau interface
	 input  mau_done,
	 output reg mau_start, 
	 output reg [1:0] mau_operation, 
	 input [255:0] mau_result, 
	 
	 //memory interface
	 output reg [255:0] mem_data, 
	 output reg [4:0] mem_address, 
	 output reg memwren, 
	 
	 //helper 
	 input helper_done, 
	 output reg helper_start, 
	 input [255:0] w1, w2, 
	 output reg [4:0] adrs1,adrs2,
	 
	 //finalizer interface 
	 output reg r_swap, 
	 
    output reg done
);



    //=========================================================================
    // Registers and Wires
    //=========================================================================
    reg [5:0] r_state, w_next_state;
	 reg  w_swap, w_k_t; 
    reg [7:0] r_counter, w_counter;  
    //=========================================================================
    // Always Block 1: Sequential Logic (State Register Update)
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state <= 6'd0;
				r_swap	<= 1'b0;
				r_counter <= 8'd254; 
        end
        else begin
            r_state <= w_next_state;
				r_swap <= w_swap;
				r_counter <= w_counter;
        end
    end
    
	//=========================================================================
	// Always Block 2: Next State Logic
	//=========================================================================
	always @(*) begin
		w_next_state = r_state;  
		
		case (r_state)
			6'd0: begin
				if(start) w_next_state = 6'd1; 
			end
			
			6'd1: begin
				if (helper_done) w_next_state = 6'd2; 
			end
			
			6'd2: begin
					if (r_swap ^ w_k_t) w_next_state = 6'd41;
					else w_next_state = 6'd42; //skip swap if the xor is 0. 

			end
			
			6'd41: begin 
					if (helper_done) w_next_state = 6'd3;
			
			end 
			
			6'd42: begin 
					if (helper_done) w_next_state = 6'd7;
			
			end 
			
			6'd3: begin
					w_next_state = 6'd4;
			end
			
			6'd4: begin
					w_next_state = 6'd43;
			end
			
			
			6'd43:begin 
				if (helper_done) w_next_state = 6'd5;
			end 
			6'd5: begin
					w_next_state = 6'd6;
			end
			
			6'd6: begin
					w_next_state = 6'd42;
			end
			
			6'd7: begin
					if (mau_done) w_next_state = 6'd8;
			end
			
			6'd8: begin
					if (mau_done) w_next_state = 6'd9;
			end
			
			6'd9: begin
					if (helper_done) w_next_state = 6'd10;
			end
			
			6'd10: begin
					if (mau_done) w_next_state = 6'd11;
			end
			
			6'd11: begin
					if (mau_done) w_next_state = 6'd12;
			end
			
			6'd12: begin
					if (helper_done) w_next_state = 6'd13;
			end
			
			6'd13: begin
					if (mau_done) w_next_state = 6'd14;
			end
			
			6'd14: begin
					if (helper_done) w_next_state = 6'd15;
			end
			
			6'd15: begin
					if (mau_done) w_next_state = 6'd16;
			end
			
			6'd16: begin
					if (helper_done)w_next_state = 6'd17;
			end
			
			6'd17: begin
					if (mau_done)w_next_state = 6'd18;
			end
			
			6'd18: begin
					if (helper_done) w_next_state = 6'd19;
			end
			
			6'd19: begin
					 if (mau_done) w_next_state = 6'd20;
			end
			
			6'd20: begin
					if (helper_done) w_next_state = 6'd21;
			end
			
			6'd21: begin
					if (mau_done) w_next_state = 6'd22;
			end
			
			6'd22: begin
					if (helper_done) w_next_state = 6'd23;
			end
			
			6'd23: begin
					if (mau_done) w_next_state = 6'd24;
			end
			
			6'd24: begin
					if (helper_done) w_next_state = 6'd25;
			end
			
			6'd25: begin
					if (mau_done) w_next_state = 6'd26;
			end
			
			6'd26: begin
					if (helper_done) w_next_state = 6'd27;
			end
			
			6'd27: begin
					if (mau_done) w_next_state = 6'd28;
			end
			
			6'd28: begin
					if (helper_done) w_next_state = 6'd29;
			end
			
			6'd29: begin
					if (mau_done) w_next_state = 6'd30;
			end
			
			6'd30: begin
					if (helper_done) w_next_state = 6'd31;
			end
			
			6'd31: begin
					if (mau_done) w_next_state = 6'd32;
			end
			
			6'd32: begin
					if (helper_done)w_next_state = 6'd33;
			end
			
			6'd33: begin
					if (mau_done) w_next_state = 6'd34;
			end
			
			6'd34: begin
					if (helper_done) w_next_state = 6'd35;
			end
			
			6'd35: begin
					if (mau_done) w_next_state = 6'd36;
			end
			
			6'd36: begin
					if (helper_done) w_next_state = 6'd37;
			end
			
			6'd37: begin
					if (mau_done) w_next_state = 6'd38;
			end
			
			6'd38: begin
					if (helper_done) w_next_state = 6'd39;
			end
			
			6'd39: begin
					if (mau_done)w_next_state = 6'd40;
			end
			
			6'd40: begin 
				if (r_counter > 8'd0) w_next_state = 6'd1;
				else if (r_counter == 8'd0) w_next_state = 6'd0;
			end
		endcase
	end
    
	//=========================================================================
	// Always Block 3: Output Logic
	//=========================================================================
	always @(*) begin
		w_swap = r_swap;
		w_counter = r_counter;
		adrs1 = 5'd0; 
		adrs2 = 5'd0; 
		helper_start = 1'b0;  
		w_k_t = 1'b0; 
		memwren = 1'b0; 
		mem_data = 256'b0; 
		mem_address = 5'd0; 
		
		mau_operation = 2'b00; 
		mau_start = 1'b0; 
		done = 1'b0; 
		case (r_state)
			6'd0: begin
					w_counter = 8'd254;
					w_swap = 1'b0; 
			end
			
			6'd1: begin
					adrs1 = 5'd0;
					adrs2 = 5'd0;
					helper_start = 1'b1; 
			end
			
			6'd2: begin
					w_k_t = w1[r_counter]; 
					w_swap = w_k_t; 

			end
			
			6'd41: begin 
				adrs1 = 5'd2;
				adrs2 = 5'd4; 
				helper_start = 1'b1; 
			
			end 
			
			6'd42: begin 
				adrs1 = 5'd2;
				adrs2 = 5'd3; 
				helper_start = 1'b1; 
			
			end 
			
			
			
			6'd3: begin
					mem_data = w1; 
					mem_address = 5'd4; 
					memwren = 1'b1; 
			end
			
			6'd4: begin
					mem_data = w2; 
					mem_address = 5'd2; 
					memwren = 1'b1; 
			end
			
			6'd43:begin 
					adrs1 = 5'd3; 
					adrs2 = 5'd5; 
					helper_start = 1'b1;
			end 
			
			6'd5: begin
					mem_data = w1; 
					mem_address = 5'd5; 
					memwren = 1'b1;
			end
			
			6'd6: begin
					mem_data = w2; 
					mem_address = 5'd3; 
					memwren = 1'b1;

			end
			
			6'd7: begin
					mau_operation = 2'b00; //add
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd9;
						mau_start = 1'b0; 	
					end
			end
			
			6'd8: begin
					mau_operation = 2'b01; //sub
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd10;
						mau_start = 1'b0;
					end
			end
			
			6'd9: begin
					adrs1 = 5'd4; 
					adrs2 = 5'd5; 
					helper_start = 1'b1;    
			end
			
			6'd10: begin
					mau_operation = 2'b00; //add
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd11;
						mau_start = 1'b0;
					end
			end
			
			6'd11: begin
					mau_operation = 2'b01; //sub
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd12;
						mau_start = 1'b0;
					end
			end
			
			6'd12: begin
					adrs1 = 5'd9; 
					adrs2 = 5'd9; 
					helper_start = 1'b1;   
			end
			
			6'd13: begin
					mau_operation = 2'b10; //MULTTT
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd13;
						mau_start = 1'b0;
					end
			end
			
			6'd14: begin
					adrs1 = 5'd10; 
					adrs2 = 5'd10; 
					helper_start = 1'b1;  
			end
			
			6'd15: begin
					mau_operation = 2'b10; //MULTTT
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd14;
						mau_start = 1'b0;
					end
			end
			
			6'd16: begin
					adrs1 = 5'd13; 
					adrs2 = 5'd14; 
					helper_start = 1'b1;  
			end
			
			6'd17: begin
					mau_operation = 2'b01; //sub
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd15;
						mau_start = 1'b0;
					end
			end
			
			6'd18: begin
					adrs1 = 5'd9; 
					adrs2 = 5'd12; 
					helper_start = 1'b1; 
			end
			
			6'd19: begin
					mau_operation = 2'b10; //MULTTT
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd16;
						mau_start = 1'b0;
					end
			end
			
			6'd20: begin
					adrs1 = 5'd10; 
					adrs2 = 5'd11; 
					helper_start = 1'b1;  
			end
			
			6'd21: begin
					mau_operation = 2'b10; //MULTTT
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd17;
						mau_start = 1'b0;
					end
			end
			
			6'd22: begin
					adrs1 = 5'd16; 
					adrs2 = 5'd17; 
					helper_start = 1'b1;  
			end
			
			6'd23: begin
					mau_operation = 2'b00; //add
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd18;
						mau_start = 1'b0;
					end
			end
			
			6'd24: begin
					adrs1 = 5'd18; 
					adrs2 = 5'd18; 
					helper_start = 1'b1;    
			end
			
			6'd25: begin
					mau_operation = 2'b10; //MULTTT
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd4;
						mau_start = 1'b0;
					end
			end
			
			6'd26: begin
					adrs1 = 5'd16; 
					adrs2 = 5'd17; 
					helper_start = 1'b1;   
			end
			
			6'd27: begin
					mau_operation = 2'b01; //sub
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd20;
						mau_start = 1'b0;
					end
			end
			
			6'd28: begin
					adrs1 = 5'd20; 
					adrs2 = 5'd20; 
					helper_start = 1'b1;
			end
			
			6'd29: begin
					mau_operation = 2'b10; //MULTTT
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd21;
						mau_start = 1'b0;
					end
			end
			
			6'd30: begin
					adrs1 = 5'd1; 
					adrs2 = 5'd21; 
					helper_start = 1'b1;
			end
			
			6'd31: begin
					mau_operation = 2'b10; //MULTT
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd5;
						mau_start = 1'b0;
					end
			end
			
			6'd32: begin
					adrs1 = 5'd13; 
					adrs2 = 5'd14; 
					helper_start = 1'b1;
			end
			
			6'd33: begin
					mau_operation = 2'b10; //MULTTT
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd2;
						mau_start = 1'b0;
					end
			end
			
			6'd34: begin
					adrs1 = 5'd25; 
					adrs2 = 5'd15; 
					helper_start = 1'b1;  
			end
			
			6'd35: begin
					mau_operation = 2'b10; //MULTTT
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd22;
						mau_start = 1'b0;
					end
			end
			
			6'd36: begin
					adrs1 = 5'd13; 
					adrs2 = 5'd22; 
					helper_start = 1'b1;  
			end
			
			6'd37: begin
					mau_operation = 2'b00; //add
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd18;
						mau_start = 1'b0;
					end
			end
			
			6'd38: begin
					adrs1 = 5'd15; 
					adrs2 = 5'd18; 
					helper_start = 1'b1;  
			end
			
			6'd39: begin
					mau_operation = 2'b10; //MULTTT
					mau_start = 1'b1; 
					if (mau_done) begin
						mem_data = mau_result; 
						memwren = 1'b1; 
						mem_address = 5'd3;
						mau_start = 1'b0;
					end
			end
			
			6'd40: begin
					w_counter = w_counter - 8'd1; 
					if (r_counter == 8'd0) done = 1'b1;
			end
		endcase
	end

endmodule

module ECDH_helper(
	input clk, 
	input rst_n, 
	
	input start, 
	input [4:0] adrs1, adrs2, 
	output reg [255:0] w1,w2,
	
	//mem interface 
	output reg [4:0] memaddress,
	input [255:0] mem_q, 
	
	output reg done

); 

	reg [2:0] r_state, w_next_state;
	reg [255:0] w_w1, w_w2; 
	
	
	//=========================================================================
	// Always Block 1: Sequential Logic (State Register Update)
	//=========================================================================
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			r_state <= 3'd0;
			w1 <= 256'd0; 
			w2 <= 256'd0; 
		end
		else begin
			r_state <= w_next_state;
			w1 <= w_w1; 
			w2 <= w_w2; 
		end
	end
    
	//=========================================================================
	// Always Block 2: Next State Logic
	//=========================================================================
	always @(*) begin
		w_next_state = r_state;  // Default: hold current state
	
		case (r_state)
			3'd0: begin
				if (start) w_next_state = 4'd1; 
			end
            
			3'd1: begin
				w_next_state = 4'd2;
			end
            
			3'd2: begin
				w_next_state = 4'd3;
			end
            
			3'd3: begin
				w_next_state = 4'd4;
			end
			
			3'd4: begin
				w_next_state = 4'd0;
			end


		
		endcase
	end
    
	//=========================================================================
	// Always Block 3: Output Logic
	//=========================================================================
	always @(*) begin
	w_w1 = w1; 
	w_w2 = w2;
	memaddress	= 5'd0;
	done	= 1'b0; 
		case (r_state)
			3'd0: begin
				
			end
            
			3'd1: begin
				memaddress = adrs1; 
			end
            
			3'd2: begin
				memaddress = adrs2;
				w_w1 = mem_q; 
			end
            
			3'd3: begin
				w_w2 = mem_q; 
			end
			
			3'd4: begin
				done = 1'b1; 
			end


		endcase
	end	


endmodule 


module ECDH_FINALIZER (
    input  wire clk,
    input  wire rst_n,
  
    input  start,
	 
 

	 
	 //mau interface
	 input  mau_done,
	 output reg mau_start, 
	 output reg [1:0] mau_operation, 
	 input [255:0] mau_result, 
	 
	 //memory interface
	 output reg [255:0] mem_data, 
	 output reg [4:0] mem_address, 
	 output reg memwren, 
	 
	 //helper 
	 input helper_done, 
	 output reg helper_start, 
	 input [255:0] w1, w2, 
	 output reg [4:0] adrs1,adrs2,
	 
	 //loop interface 
	 input r_swap, 
	 output [255:0] final_result,
    output reg done
);

	assign final_result = w1; 

   //=========================================================================
    // Registers and Wires
    //=========================================================================
    reg [3:0] r_state, w_next_state;
    
    //=========================================================================
    // Always Block 1: Sequential Logic (State Register Update)
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state <= 4'd0;
        end
        else begin
            r_state <= w_next_state;
        end
    end
    
    //=========================================================================
    // Always Block 2: Next State Logic
    //=========================================================================
    always @(*) begin
        w_next_state = r_state;  // Default: hold current state
        
        case (r_state)
            4'd0: begin
                if(start) w_next_state = 4'd1;
            end
            
            4'd1: begin
				if(helper_done) begin 
					if (r_swap) w_next_state = 6'd2;
					else  w_next_state = 6'd6; 
				end 
			end
            
            4'd2: begin
                w_next_state = 4'd3;
            end
            
            4'd3: begin
                if (helper_done) w_next_state = 4'd4;
            end
            
            4'd4: begin
                w_next_state = 4'd5;
            end
            
            4'd5: begin
                if (helper_done) w_next_state = 4'd6;
            end
            
            4'd6: begin
                if (mau_done) w_next_state = 4'd7;
            end
            
            4'd7: begin
                if (helper_done) w_next_state = 4'd8;
            end
            
            4'd8: begin
                if (mau_done) w_next_state = 4'd9;
            end
				4'd9: begin
                if (helper_done) w_next_state = 4'd10;
            end
				4'd10: begin 
					w_next_state = 4'd0;
				end 
        endcase
    end
    
    //=========================================================================
    // Always Block 3: Output Logic
    //=========================================================================
    always @(*) begin
		  adrs1 = 5'd0; 
		  adrs2 = 5'd0; 
		  helper_start = 1'b0; 
  
		  memwren = 1'b0; 
		  mem_data = 256'b0; 
		  mem_address = 5'd0; 
		  
		  mau_operation = 2'b00; 
		  mau_start = 1'b0; 
		  done = 1'b0; 
        
        case (r_state)
            4'd0: begin
                
            end
            
            4'd1: begin
					if (r_swap) begin 
						adrs1 = 5'd2; adrs2 = 5'd4; 
					end 
					else begin 
						adrs1 = 5'd3; adrs2 = 5'd3;
					end 
					helper_start = 1'b1; 
            end
            
            4'd2: begin
                mem_data = w1; 
					 mem_address = 5'd4; 
					 memwren = 1'b1; 
            end
            
            4'd3: begin
                mem_data = w2; 
					 mem_address = 5'd2; 
					 memwren = 1'b1;
					 adrs1 = 5'd3; 
					 adrs2 = 5'd5; 
					 helper_start = 1'b1;
            end
            
            4'd4: begin
                mem_data = w1; 
					 mem_address = 5'd5; 
					 memwren = 1'b1;
            end
            
            4'd5: begin
                mem_data = w2; 
					 mem_address = 5'd3; 
					 memwren = 1'b1;
					 adrs1 = 5'd3; 
					 adrs2 = 5'd3; 
					 helper_start = 1'b1;  
            end
            
            4'd6: begin
					 mau_operation = 2'b11; //INVV
					 mau_start = 1'b1; 
                mem_data = mau_result; 
					 memwren = 1'b1; 
					 mem_address = 5'd23; 
            end
            
            4'd7: begin
					 adrs1 = 5'd2; 
					 adrs2 = 5'd23; 
					 helper_start = 1'b1;  
            end
            
            4'd8: begin
					 mau_operation = 2'b10; //MULTTT
					 mau_start = 1'b1; 
                mem_data = mau_result; 
					 memwren = 1'b1; 
					 mem_address = 5'd24; 
            end
				4'd9: begin
					 adrs1 = 5'd24; 
					 adrs2 = 5'd24; 
					 helper_start = 1'b1; 
            end
				
				4'd10: begin 
					done = 1'b1; 
				end 
				
        endcase
    end

endmodule