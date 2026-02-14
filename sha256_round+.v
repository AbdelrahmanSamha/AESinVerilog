// -----------------------------------------------------
// Created by Abdelrahman Samha
// The Hashemite University
// Project: [Choas-Image-Encryption]
// Date: [5/5/2025]
// -----------------------------------------------------
module sha256_round (
      
	 input  [31:0] a, b, c, d,e, f, g, h,
    input  [31:0] W,      // Message schedule word for this round
    input  [31:0] K,      // Round constant
    output [31:0] a_out, b_out, c_out, d_out,
    output [31:0] e_out, f_out, g_out, h_out
);

// Internal signals for intermediate calculations
wire [31:0] T1, T2;
wire [31:0] Ch, Maj, Sigma0, Sigma1;



//----------------------------------------------------------------
// Helper Functions (Combinational Logic)
//----------------------------------------------------------------

// Right rotation: x >> n | x << (32 - n)
function [31:0] rotr(input [4:0] n, input [31:0] x);
    rotr = (x >> n) | (x << (32 - n));
endfunction

// Choose(e,f,g)->
assign Ch = (e & f) ^ (~e & g);

// Majority: (a & b) ^ (a & c) ^ (b & c)
assign Maj = (a & b) | (a & c) | (b & c);

// Σ0: rotr(2, a) ^ rotr(13, a) ^ rotr(22, a)
assign Sigma0 = rotr(2, a) ^ rotr(13, a) ^ rotr(22, a);

// Σ1: rotr(6, e) ^ rotr(11, e) ^ rotr(25, e)
assign Sigma1 = rotr(6, e) ^ rotr(11, e) ^ rotr(25, e);

//----------------------------------------------------------------
// Compute T1 and T2 (Combinational)
//----------------------------------------------------------------
assign T1 = h + Sigma1 + Ch + K + W;  // All additions are mod 2^32
assign T2 = Sigma0 + Maj;

//----------------------------------------------------------------
// Update Working Variables (Combinational)
//----------------------------------------------------------------
assign a_out = T1 + T2;  // New a
assign b_out = a;     // New b (shift right)
assign c_out = b;     // New c (shift right)
assign d_out = c;     // New d (shift right)

assign e_out = d + T1; // New e
assign f_out = e;      // New f (shift right)
assign g_out = f;      // New g (shift right)
assign h_out = g;      // New h (shift right)

endmodule
