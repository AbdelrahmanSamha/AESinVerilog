module mux2to1 #(
    parameter WIDTH = 32
)(
    input  wire [WIDTH-1:0] in0,   // input 0
    input  wire [WIDTH-1:0] in1,   // input 1
    input  wire              sel,// select line
    output wire [WIDTH-1:0] out    // output
);

    assign out = (sel) ? in1 : in0;

endmodule
