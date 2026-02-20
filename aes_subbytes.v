module subbytes(
    input              clk,          // NEW
    input  [127:0]     in,
    output [127:0]     out
);

    // -------------------------------------------------
    // 16 independent ROM outputs
    // -------------------------------------------------
    wire [7:0] q0,  q1,  q2,  q3;
    wire [7:0] q4,  q5,  q6,  q7;
    wire [7:0] q8,  q9,  q10, q11;
    wire [7:0] q12, q13, q14, q15;

    // -------------------------------------------------
    // 16 S-Box ROM instances (parallel)
    // -------------------------------------------------

    s_box_rom s0  (.address(in[7:0]),    .clock(clk), .q(q0));
    s_box_rom s1  (.address(in[15:8]),   .clock(clk), .q(q1));
    s_box_rom s2  (.address(in[23:16]),  .clock(clk), .q(q2));
    s_box_rom s3  (.address(in[31:24]),  .clock(clk), .q(q3));

    s_box_rom s4  (.address(in[39:32]),  .clock(clk), .q(q4));
    s_box_rom s5  (.address(in[47:40]),  .clock(clk), .q(q5));
    s_box_rom s6  (.address(in[55:48]),  .clock(clk), .q(q6));
    s_box_rom s7  (.address(in[63:56]),  .clock(clk), .q(q7));

    s_box_rom s8  (.address(in[71:64]),  .clock(clk), .q(q8));
    s_box_rom s9  (.address(in[79:72]),  .clock(clk), .q(q9));
    s_box_rom s10 (.address(in[87:80]),  .clock(clk), .q(q10));
    s_box_rom s11 (.address(in[95:88]),  .clock(clk), .q(q11));

    s_box_rom s12 (.address(in[103:96]), .clock(clk), .q(q12));
    s_box_rom s13 (.address(in[111:104]),.clock(clk), .q(q13));
    s_box_rom s14 (.address(in[119:112]),.clock(clk), .q(q14));
    s_box_rom s15 (.address(in[127:120]),.clock(clk), .q(q15));

    // -------------------------------------------------
    // Reassemble 128-bit output
    // -------------------------------------------------
    assign out = {
        q15, q14, q13, q12,
        q11, q10, q9,  q8,
        q7,  q6,  q5,  q4,
        q3,  q2,  q1,  q0
    };

endmodule
