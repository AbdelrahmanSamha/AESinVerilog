//=====================================================
// AES Round Constant (Rcon) Module
// Generates the round constant for AES key expansion
//=====================================================
module aes_rcon (
    input  wire [3:0] round,      // round number (1–10 for AES-128)
    output reg  [31:0] rcon_out   // round constant (word)
);

always @(*) begin
    case (round)
        4'd1:  rcon_out = 32'h01000000;
        4'd2:  rcon_out = 32'h02000000;
        4'd3:  rcon_out = 32'h04000000;
        4'd4:  rcon_out = 32'h08000000;
        4'd5:  rcon_out = 32'h10000000;
        4'd6:  rcon_out = 32'h20000000;
        4'd7:  rcon_out = 32'h40000000;
        4'd8:  rcon_out = 32'h80000000;
        4'd9:  rcon_out = 32'h1B000000;
        4'd10: rcon_out = 32'h36000000;
        default:rcon_out= 32'h00000000;  // for safety
    endcase
end

endmodule
