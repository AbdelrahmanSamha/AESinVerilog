module TRNG (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,        // start signal from controller
    input  wire        enable_osc,   // manual switch for oscillators
    output reg         done,         // signals completion
    output reg [255:0] random_data   // 256-bit output
);

    // ==============================
    // Ring oscillators (8 total)
    // ==============================
    wire ro_a, ro_b, ro_c, ro_d;
    wire ro_e, ro_f, ro_g, ro_h;
    wire random_bit;

    ring_oscillator #(.STAGES(5)) ro0 (
        .enable(enable_osc),
        .osc_out(ro_a)
    );

    ring_oscillator #(.STAGES(7)) ro1 (
        .enable(enable_osc),
        .osc_out(ro_b)
    );

    ring_oscillator #(.STAGES(9)) ro2 (
        .enable(enable_osc),
        .osc_out(ro_c)
    );

    ring_oscillator #(.STAGES(11)) ro3 (
        .enable(enable_osc),
        .osc_out(ro_d)
    );

    ring_oscillator #(.STAGES(5)) ro4 (
        .enable(enable_osc),
        .osc_out(ro_e)
    );

    ring_oscillator #(.STAGES(7)) ro5 (
        .enable(enable_osc),
        .osc_out(ro_f)
    );

    ring_oscillator #(.STAGES(9)) ro6 (
        .enable(enable_osc),
        .osc_out(ro_g)
    );

    ring_oscillator #(.STAGES(11)) ro7 (
        .enable(enable_osc),
        .osc_out(ro_h)
    );

    // XOR whitening of all oscillators
    assign random_bit =
        ro_a ^ ro_b ^ ro_c ^ ro_d ^
        ro_e ^ ro_f ^ ro_g ^ ro_h;

    // ==============================
    // FSM declarations
    // ==============================
    localparam IDLE   = 2'd0;
    localparam SAMPLE = 2'd1;
    localparam DONE   = 2'd2;

    reg [1:0] state, next_state;

    reg [8:0] bit_count;   // counts 0..255

    // ==============================
    // 1) Sequential block
    // ==============================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            bit_count    <= 9'd0;
            random_data  <= 256'd0;
        end else begin
            state <= next_state;

            // shift logic during SAMPLE
            if (state == SAMPLE) begin
                random_data <= {random_data[254:0], random_bit};
                bit_count   <= bit_count + 9'd1;
            end else if (state == IDLE) begin
                bit_count <= 9'd0;
            end
        end
    end

    // ==============================
    // 2) Next-state logic
    // ==============================
    always @(*) begin
        next_state = state;

        case (state)
            IDLE: begin
                if (start)
                    next_state = SAMPLE;
            end

            SAMPLE: begin
                if (bit_count == 9'd255)
                    next_state = DONE;
            end

            DONE: begin
                if (!start)
                    next_state = IDLE;
            end
        endcase
    end

    // ==============================
    // 3) Output / control logic
    // ==============================
    always @(*) begin
        done = 1'b0;

        case (state)
            DONE: done = 1'b1;
        endcase
    end

endmodule
