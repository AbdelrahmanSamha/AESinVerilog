module ring_oscillator #(
    parameter integer STAGES = 5   // must be odd
)(
    input  wire enable,
    output wire osc_out
);

    wire [STAGES-1:0] ring;

    genvar i;
    generate
        for (i = 0; i < STAGES; i = i + 1) begin : ro
            if (i == 0) begin
                LCELL l0 (
                    .in  (~ring[STAGES-1] & enable),
                    .out (ring[0])
                );
            end else begin
                LCELL li (
                    .in  (~ring[i-1]),
                    .out (ring[i])
                );
            end
        end
    endgenerate

    assign osc_out = ring[STAGES-1];

endmodule