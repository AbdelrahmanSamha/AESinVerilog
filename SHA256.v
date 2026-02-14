// -----------------------------------------------------
// Created by Abdelrahman Samha
// The Hashemite University
// Project: [Choas-Image-Encryption]
// Date: [5/5/2025]
// -----------------------------------------------------
module SHA256(

	input clk,rst_n,go_i,
	input	[511:0] block,
	input first_round, 
	input [255:0] prev, 
	output reg[255:0] Digest,
	output sig_done
);


reg [31:0] a,b,c,d,e,f,g,h;
wire [31:0] a_next,b_next,c_next,d_next,e_next,f_next,g_next,h_next;
reg [31:0] W [15:0];


	//****************************************************************************
	// FSM sqnt state update and logic
	//****************************************************************************
	
	parameter IDLE =3'b000, INITIALISE= 3'b001, PROCESS= 3'b010,DIGEST = 3'b011, FINALIZE= 3'b100;
	reg [2:0]STATE;
	reg [5:0] iterator; 
	wire init ,ld_registers, sel_registers, ld_digest;
	
	assign init = (STATE == INITIALISE)? 1'b1:1'b0;
	assign ld_registers = ((STATE == INITIALISE) | (STATE == PROCESS)) ? 1'b1:1'b0;
	assign sel_registers = (STATE == INITIALISE)? 1'b0 : 1'b1 ; 
	assign sig_done = (STATE == FINALIZE)? 1'b1 : 1'b0; 
	assign ld_digest = (STATE == DIGEST)? 1'b1:1'b0;
	always @(posedge clk, negedge rst_n)begin 
		if (!rst_n) begin 
			STATE = IDLE; 
			iterator <= 6'b0; 
			
		
		end 
		else begin 
			case (STATE) 
				IDLE: begin 
					
					if (go_i) STATE <= INITIALISE;
				end 
				INITIALISE: begin 
					STATE <= PROCESS;	
				end
				PROCESS : begin 
					if (iterator < 63) begin
						iterator <= iterator + 6'b1;
					end else begin
						iterator <= 6'b0;
						STATE <= DIGEST;				
					end
				end
				DIGEST: begin 
					
					STATE <= FINALIZE;
				end 
				
				FINALIZE: begin
			
					
					STATE<= IDLE;
				
				end 
		
			endcase
		
		end
	
	end 
	
	
	
	
	// SHA-256 Round Constants (K[0..63]) as a function
	function [31:0] get_K;
	input [5:0] index;  // 0-63
	begin
		case (index)
			0 : get_K = 32'h428a2f98;
			1 : get_K = 32'h71374491;
			2 : get_K = 32'hb5c0fbcf;
			3 : get_K = 32'he9b5dba5;
			4 : get_K = 32'h3956c25b;
			5 : get_K = 32'h59f111f1;
			6 : get_K = 32'h923f82a4;
			7 : get_K = 32'hab1c5ed5;
			8 : get_K = 32'hd807aa98;
			9 : get_K = 32'h12835b01;
			10: get_K = 32'h243185be;
			11: get_K = 32'h550c7dc3;
			12: get_K = 32'h72be5d74;
			13: get_K = 32'h80deb1fe;
			14: get_K = 32'h9bdc06a7;
			15: get_K = 32'hc19bf174;
			16: get_K = 32'he49b69c1;
			17: get_K = 32'hefbe4786;
			18: get_K = 32'h0fc19dc6;
			19: get_K = 32'h240ca1cc;
			20: get_K = 32'h2de92c6f;
			21: get_K = 32'h4a7484aa;
			22: get_K = 32'h5cb0a9dc;
			23: get_K = 32'h76f988da;
			24: get_K = 32'h983e5152;
			25: get_K = 32'ha831c66d;
			26: get_K = 32'hb00327c8;
			27: get_K = 32'hbf597fc7;
			28: get_K = 32'hc6e00bf3;
			29: get_K = 32'hd5a79147;
			30: get_K = 32'h06ca6351;
			31: get_K = 32'h14292967;
			32: get_K = 32'h27b70a85;
			33: get_K = 32'h2e1b2138;
			34: get_K = 32'h4d2c6dfc;
			35: get_K = 32'h53380d13;
			36: get_K = 32'h650a7354;
			37: get_K = 32'h766a0abb;
			38: get_K = 32'h81c2c92e;
			39: get_K = 32'h92722c85;
			40: get_K = 32'ha2bfe8a1;
			41: get_K = 32'ha81a664b;
			42: get_K = 32'hc24b8b70;
			43: get_K = 32'hc76c51a3;
			44: get_K = 32'hd192e819;
			45: get_K = 32'hd6990624;
			46: get_K = 32'hf40e3585;
			47: get_K = 32'h106aa070;
			48: get_K = 32'h19a4c116;
			49: get_K = 32'h1e376c08;
			50: get_K = 32'h2748774c;
			51: get_K = 32'h34b0bcb5;
			52: get_K = 32'h391c0cb3;
			53: get_K = 32'h4ed8aa4a;
			54: get_K = 32'h5b9cca4f;
			55: get_K = 32'h682e6ff3;
			56: get_K = 32'h748f82ee;
			57: get_K = 32'h78a5636f;
			58: get_K = 32'h84c87814;
			59: get_K = 32'h8cc70208;
			60: get_K = 32'h90befffa;
			61: get_K = 32'ha4506ceb;
			62: get_K = 32'hbef9a3f7;
			63: get_K = 32'hc67178f2;
			default: get_K = 32'h0;  // Guard against invalid indices
		endcase
	end
	endfunction
	
	
	
	
	
	//****************************************************************************
	// ROUND FUNCTION UPDATE 
	//****************************************************************************
		//initiale parameters...
	parameter H0=32'h6a09e667, H1=32'hbb67ae85, H2=32'h3c6ef372,
		H3=32'ha54ff53a,H4=32'h510e527f,H5 = 32'h9b05688c, H6=32'h1f83d9ab, H7=32'h5be0cd19;


	
	wire [31:0] H_prev0;
	wire [31:0] H_prev1;
	wire [31:0] H_prev2;
	wire [31:0] H_prev3;
	wire [31:0] H_prev4;
	wire [31:0] H_prev5;
	wire [31:0] H_prev6;
	wire [31:0] H_prev7;

	wire [31:0] H0_init;
	wire [31:0] H1_init;
	wire [31:0] H2_init;
	wire [31:0] H3_init;
	wire [31:0] H4_init;
	wire [31:0] H5_init;
	wire [31:0] H6_init;
	wire [31:0] H7_init;
	
	
	assign H_prev0 = prev[255:224];
	assign H_prev1 = prev[223:192];
	assign H_prev2 = prev[191:160];
	assign H_prev3 = prev[159:128];
	assign H_prev4 = prev[127:96];
	assign H_prev5 = prev[95:64];
	assign H_prev6 = prev[63:32];
	assign H_prev7 = prev[31:0];

	assign H0_init = first_round ? H0 : H_prev0;
	assign H1_init = first_round ? H1 : H_prev1;
	assign H2_init = first_round ? H2 : H_prev2;
	assign H3_init = first_round ? H3 : H_prev3;
	assign H4_init = first_round ? H4 : H_prev4;
	assign H5_init = first_round ? H5 : H_prev5;
	assign H6_init = first_round ? H6 : H_prev6;
	assign H7_init = first_round ? H7 : H_prev7;
	
	// Output wires
	wire [31:0] out_muxa, out_muxb, out_muxc, out_muxd, out_muxe, out_muxf, out_muxg, out_muxh;
	// Mux instances with H0-H7 on in0 ports
	mux2to1 muxa (.sel(sel_registers), .in0(H0_init), .in1(a_next), .out(out_muxa));
	mux2to1 muxb (.sel(sel_registers), .in0(H1_init), .in1(b_next), .out(out_muxb));
	mux2to1 muxc (.sel(sel_registers), .in0(H2_init), .in1(c_next), .out(out_muxc));
	mux2to1 muxd (.sel(sel_registers), .in0(H3_init), .in1(d_next), .out(out_muxd));
	mux2to1 muxe (.sel(sel_registers), .in0(H4_init), .in1(e_next), .out(out_muxe));
	mux2to1 muxf (.sel(sel_registers), .in0(H5_init), .in1(f_next), .out(out_muxf));
	mux2to1 muxg (.sel(sel_registers), .in0(H6_init), .in1(g_next), .out(out_muxg));
	mux2to1 muxh (.sel(sel_registers), .in0(H7_init), .in1(h_next), .out(out_muxh));
		
		always @(posedge clk, negedge rst_n) begin
			if (!rst_n)begin 
			a <= 32'b0;	
			b <= 32'b0;
			c <= 32'b0;
			d <= 32'b0;
			e <= 32'b0;
			f <= 32'b0;
			g <= 32'b0;
			h <= 32'b0;
			end 
			else if(ld_registers) begin
				a <= out_muxa;
				b <= out_muxb;
				c <= out_muxc;
				d <= out_muxd;
				e <= out_muxe;
				f <= out_muxf;
				g <= out_muxg;
				h <= out_muxh;
			end
		end
		
		
		
	//****************************************************************************
	// MESSAGE SCHEDULER BLOCK 
	//****************************************************************************
		// Right rotation function
		function [31:0] rotr(input [5:0] n, input [31:0] x);
			rotr = (x >> n) | (x << (32 - n));
		endfunction
		
		// SHA-256 ?0 function
		function [31:0] small_sigma0(input [31:0] x);
			small_sigma0 = rotr(7, x) ^ rotr(18, x) ^ (x >> 3);
		endfunction
		
		// SHA-256 ?1 function
		function [31:0] small_sigma1(input [31:0] x);
			small_sigma1 = rotr(17, x) ^ rotr(19, x) ^ (x >> 10);
		endfunction
		
			// Individual term wires
		wire [31:0] w_term0;
		wire [31:0] w_term1;
		wire [31:0] w_term2;
		wire [31:0] w_term3;
		
		// Result wire
		wire [31:0] w15_next;
		
		always @(posedge clk , negedge rst_n) begin
		if (!rst_n)begin 
			W[0]  <=32'b0;
			W[1]  <=32'b0;
			W[2]  <=32'b0;
			W[3]  <=32'b0;
			W[4]  <=32'b0;
			W[5]  <=32'b0;
			W[6]  <=32'b0;
			W[7]  <=32'b0;
			W[8]  <=32'b0;
			W[9]  <=32'b0;
			W[10] <=32'b0;
			W[11] <=32'b0;
			W[12] <=32'b0;
			W[13] <=32'b0;
			W[14] <=32'b0;
			W[15] <=32'b0;
		end
		else if (init) begin
			// W[0] = first 32 bits (big-endian), W[15] = last 32 bits
			W[0]  <= block[511:480]; 
			W[1]  <= block[479:448]; 
			W[2]  <= block[447:416]; 
			W[3]  <= block[415:384]; 
			W[4]  <= block[383:352]; 
			W[5]  <= block[351:320]; 
			W[6]  <= block[319:288]; 
			W[7]  <= block[287:256]; 
			W[8]  <= block[255:224]; 
			W[9]  <= block[223:192]; 
			W[10] <= block[191:160]; 
			W[11] <= block[159:128]; 
			W[12] <= block[127:96];  
			W[13] <= block[95:64];   
			W[14] <= block[63:32];   
			W[15] <= block[31:0];    
		end
		else begin
			//using a shift register saves hardware space and cost of registers, instead of having to calculate all 64 words initially we calculate them on the fly as we progress. 
			if ((iterator >= 15)) begin
					// Shift left by one position (W[0] discarded)
					W[0]  <= W[1];
					W[1]  <= W[2];
					W[2]  <= W[3];
					W[3]  <= W[4];
					W[4]  <= W[5];
					W[5]  <= W[6];
					W[6]  <= W[7];
					W[7]  <= W[8];
					W[8]  <= W[9];
					W[9]  <= W[10];
					W[10] <= W[11];
					W[11] <= W[12];
					W[12] <= W[13];
					W[13] <= W[14];
					W[14] <= W[15];
					
					// Compute new W[15] using small sigma0 and 1  functions
					W[15] <= w15_next;
			end
		end
	end
	
	
	
	
	
	wire [31:0] wt, kt; 
	assign wt = (iterator < 16) ? W[iterator] : W[15];
	
	assign kt = get_K(iterator);
	
	

	
	// Assign each part
	assign w_term0 = small_sigma1(W[14]);
	assign w_term1 = W[9];
	assign w_term2 = small_sigma0(W[1]);
	assign w_term3 = W[0];
	
	// Sum them together
	assign w15_next = w_term0 + w_term1 + w_term2 + w_term3;
	
	
	
	//****************************************************************************
	// ROUND FUNCTION 
	//****************************************************************************
	
		sha256_round round(
			.a    (a),  // Input: Current a value
			.b    (b),  // Input: Current b value
			.c    (c),  // Input: Current c value
			.d    (d),  // Input: Current d value
			.e    (e),  // Input: Current e value
			.f    (f),  // Input: Current f value
			.g    (g),  // Input: Current g value
			.h    (h),  // Input: Current h value
			.W    (wt),  // Input: Message schedule word W[t]
			.K    (kt),  // Input: Round constant K[t]
			.a_out(a_next),  // Output: Updated a value
			.b_out(b_next),  // Output: Updated b value
			.c_out(c_next),  // Output: Updated c value
			.d_out(d_next),  // Output: Updated d value
			.e_out(e_next),  // Output: Updated e value
			.f_out(f_next),  // Output: Updated f value
			.g_out(g_next),  // Output: Updated g value
			.h_out(h_next)   // Output: Updated h value
		);
	
	//****************************************************************************
	// Final addition of a,b,c,d,e,f,g,h with the inital vector. 
	//****************************************************************************
		wire [31:0] a_plus_h0, b_plus_h1, c_plus_h2, d_plus_h3, e_plus_h4, f_plus_h5, g_plus_h6, h_plus_h7;
		assign a_plus_h0 = a + H0_init;
		assign b_plus_h1 = b + H1_init;
		assign c_plus_h2 = c + H2_init;
		assign d_plus_h3 = d + H3_init;
		assign e_plus_h4 = e + H4_init;
		assign f_plus_h5 = f + H5_init;
		assign g_plus_h6 = g + H6_init;
		assign h_plus_h7 = h + H7_init;
		
		always @(posedge clk, negedge rst_n) begin 
			if (!rst_n)begin 
				Digest <= 256'H0;
			end 
			else if (ld_digest)begin 
				Digest <= {a_plus_h0,b_plus_h1,c_plus_h2,d_plus_h3, e_plus_h4, f_plus_h5, g_plus_h6, h_plus_h7};
			end 
		end 
	
	
	
	
	endmodule
	