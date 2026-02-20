//=============================================================================
// MAU.v - Modular Arithmetic Unit (Top Level)
// Supports: ADD, SUB, MUL, INV
//=============================================================================

module MAU(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] operation,  // 00=ADD, 01=SUB, 10=MUL, 11=INV
    input wire [255:0] a,
    input wire [255:0] b,        // Not used for INV operation
    output reg [255:0] result,
    output reg done
);

    // Operation codes
    parameter OP_ADD = 2'b00;
    parameter OP_SUB = 2'b01;
    parameter OP_MUL = 2'b10;
    parameter OP_INV = 2'b11;
    
    // ========== mod_add ==========
    wire [255:0] add_result;
    wire add_done;
    
    mod_add u_mod_add(
        .clk(clk),
        .rst_n(rst_n),
        .start(start && (operation == OP_ADD)),
        .a(a),
        .b(b),
        .result(add_result),
        .done(add_done)
    );
    
    // ========== mod_sub ==========
    wire [255:0] sub_result;
    wire sub_done;
    
    mod_sub u_mod_sub(
        .clk(clk),
        .rst_n(rst_n),
        .start(start && (operation == OP_SUB)),
        .a(a),
        .b(b),
        .result(sub_result),
        .done(sub_done)
    );
    
    // ========== mod_mul (shared resource) ==========
    // mod_mul is used by both direct MUL operation and mod_inv
    wire mul_start_direct;      // Start signal from direct MUL operation
    wire mul_start_inv;         // Start signal from mod_inv
    wire mul_start_actual;      // Actual start signal to mod_mul
    wire [255:0] mul_a_direct;  // Inputs from direct MUL
    wire [255:0] mul_b_direct;
    wire [255:0] mul_a_inv;     // Inputs from mod_inv
    wire [255:0] mul_b_inv;
    wire [255:0] mul_a_actual;  // Actual inputs to mod_mul
    wire [255:0] mul_b_actual;
    wire [255:0] mul_result;    // Output from mod_mul (shared)
    wire mul_done;              // Done signal from mod_mul (shared)
    
    // Direct MUL operation inputs
    assign mul_start_direct = start && (operation == OP_MUL);
    assign mul_a_direct = a;
    assign mul_b_direct = b;
    
    // Multiplex mod_mul inputs based on whether INV is active
    assign mul_start_actual = (operation == OP_INV) ? mul_start_inv : mul_start_direct;
    assign mul_a_actual = (operation == OP_INV) ? mul_a_inv : mul_a_direct;
    assign mul_b_actual = (operation == OP_INV) ? mul_b_inv : mul_b_direct;
    
    mod_mul u_mod_mul(
        .clk(clk),
        .rst_n(rst_n),
        .start(mul_start_actual),
        .a(mul_a_actual),
        .b(mul_b_actual),
        .result(mul_result),
        .done(mul_done)
    );
    
    // ========== mod_inv ==========
    wire [255:0] inv_result;
    wire inv_done;
    
    mod_inv u_mod_inv(
        .clk(clk),
        .rst_n(rst_n),
        .start(start && (operation == OP_INV)),
        .a(a),
        .result(inv_result),
        .done(inv_done),
        // Connections to shared mod_mul
        .mul_start(mul_start_inv),
        .mul_a(mul_a_inv),
        .mul_b(mul_b_inv),
        .mul_result(mul_result),
        .mul_done(mul_done)
    );
    
    // ========== Output Multiplexer ==========
    always @(*) begin
        case (operation)
            OP_ADD: begin
                result = add_result;
                done = add_done;
            end
            OP_SUB: begin
                result = sub_result;
                done = sub_done;
            end
            OP_MUL: begin
                result = mul_result;
                done = mul_done;
            end
            OP_INV: begin
                result = inv_result;
                done = inv_done;
            end
            default: begin
                result = 256'd0;
                done = 1'b0;
            end
        endcase
    end

endmodule

//=============================================================================
// mod_add.v - Modular Addition
// Computes (a + b) mod p, where p = 2^255 - 19
//=============================================================================

module mod_add(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] a,
    input wire [255:0] b,
    output reg [255:0] result,
    output reg done
);

    // p = 2^255 - 19
    // In hex: 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFED
    parameter [255:0] P = 256'h7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFED;
    
    // Internal registers
    reg [256:0] sum;           // 257 bits to catch overflow
    reg [256:0] sum_minus_p;
    
    // State machine
    reg [1:0] state;
    parameter IDLE   = 2'd0;
    parameter ADD    = 2'd1;
    parameter REDUCE = 2'd2;
    parameter DONE   = 2'd3;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 256'd0;
            done <= 1'b0;
            state <= IDLE;
            sum <= 257'd0;
            sum_minus_p <= 257'd0;
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= ADD;
                    end
                end
                
                ADD: begin
                    // Compute a + b (with carry bit)
                    sum <= {1'b0, a} + {1'b0, b};
                    state <= REDUCE;
                end
                
                REDUCE: begin
                    // Compute sum - p
                    sum_minus_p = sum - {1'b0, P};
                    
                    // If sum >= p, use (sum - p), otherwise use sum
                    if (sum >= {1'b0, P}) begin
                        result <= sum_minus_p[255:0];
                    end
                    else begin
                        result <= sum[255:0];
                    end
                    
                    state <= DONE;
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule


//=============================================================================
// mod_sub.v - Modular Subtraction
// Computes (a - b) mod p, where p = 2^255 - 19
//=============================================================================

module mod_sub(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] a,
    input wire [255:0] b,
    output wire [255:0] result,
    output wire done
);

    // p = 2^255 - 19
    parameter [255:0] P = 256'h7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFED;
    
    // State encoding
    parameter [1:0] IDLE   = 2'd0;
    parameter [1:0] SUB    = 2'd1;
    parameter [1:0] REDUCE = 2'd2;
    parameter [1:0] DONE_ST = 2'd3;
    
    //=========================================================================
    // Registers (r_ prefix)
    //=========================================================================
    reg [1:0]   r_state;
    reg [256:0] r_diff;
    reg [256:0] r_diff_plus_p;
    reg         r_need_adjust;   // ← NEW: stores whether a < b
    reg [255:0] r_result;
    reg         r_done;
    
    //=========================================================================
    // Wires (w_ prefix)
    //=========================================================================
    reg [1:0]   w_next_state;
    reg [256:0] w_diff;
    reg [256:0] w_diff_plus_p;
    reg         w_need_adjust;
    reg [255:0] w_result;
    reg         w_done;
    
    //=========================================================================
    // Outputs
    //=========================================================================
    assign result = r_result;
    assign done   = r_done;
    
    //=========================================================================
    // Always Block 1: Register updates
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            r_state        <= IDLE;
            r_diff         <= 257'd0;
            r_diff_plus_p  <= 257'd0;
            r_need_adjust  <= 1'b0;
            r_result       <= 256'd0;
            r_done         <= 1'b0;
        end
        else begin
            r_state        <= w_next_state;
            r_diff         <= w_diff;
            r_diff_plus_p  <= w_diff_plus_p;
            r_need_adjust  <= w_need_adjust;
            r_result       <= w_result;
            r_done         <= w_done;
        end
    end
    
    //=========================================================================
    // Always Block 2: Next state logic
    //=========================================================================
    always @(*) begin
        w_next_state = r_state;  // Default: hold current state
        
        case (r_state)
            IDLE: begin
                if (start)
                    w_next_state = SUB;
            end
            
            SUB: begin
                w_next_state = REDUCE;
            end
            
            REDUCE: begin
                w_next_state = DONE_ST;
            end
            
            DONE_ST: begin
                w_next_state = IDLE;
            end
            
            default: w_next_state = IDLE;
        endcase
    end
    
    //=========================================================================
    // Always Block 3: Datapath logic
    //=========================================================================
    always @(*) begin
        // Defaults: hold values
        w_diff        = r_diff;
        w_diff_plus_p = r_diff_plus_p;
        w_need_adjust = r_need_adjust;
        w_result      = r_result;
        w_done        = 1'b0;
        
        case (r_state)
            
            IDLE: begin
                w_done = 1'b0;
            end
            
            SUB: begin
                // Compute a - b with extra bit for borrow detection
                w_diff = {1'b0, a} - {1'b0, b};
                
                // Store comparison result for next state
                // ← KEY OPTIMIZATION: compute once, use in next state
                w_need_adjust = (a < b);
            end
            
            REDUCE: begin
                // Use stored comparison result
                if (r_need_adjust) begin
                    // a < b: add p to correct the result
                    w_diff_plus_p = r_diff + {1'b0, P};
                    w_result = w_diff_plus_p[255:0];
                end
                else begin
                    // a >= b: result is already correct
                    w_result = r_diff[255:0];
                end
            end
            
            DONE_ST: begin
                w_done = 1'b1;
            end
            
            default: begin
                w_done = 1'b0;
            end
        endcase
    end

endmodule

module mod_mul(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [255:0] a,
    input  wire [255:0] b,
    output wire [255:0] result,
    output wire         done
);

    // p = 2^255 - 19
    parameter [255:0] P = 256'h7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFED;

    // State encoding
    parameter [2:0] IDLE        = 3'd0;
    parameter [2:0] MULTIPLY    = 3'd1;
    parameter [2:0] REDUCE_1    = 3'd2;
    parameter [2:0] REDUCE_2    = 3'd3;
    parameter [2:0] FINAL_CHECK = 3'd4;
    parameter [2:0] DONE_ST     = 3'd5;

    //=========================================================================
    // Registers (r_ prefix)
    //=========================================================================
    reg [2:0]   r_state;
    reg [511:0] r_product;
    reg [511:0] r_multiplicand;  // ✅ NOW 512 bits! (was 256)
    reg [255:0] r_multiplier;
    reg [8:0]   r_bit_counter;
    reg [511:0] r_temp;
    reg [511:0] r_high_times_19;
    reg [255:0] r_result;
    reg         r_done;

    //=========================================================================
    // Wires (w_ prefix)
    //=========================================================================
    reg [2:0]   w_next_state;
    reg [511:0] w_product;
    reg [511:0] w_multiplicand;
    reg [255:0] w_multiplier;
    reg [8:0]   w_bit_counter;
    reg [511:0] w_temp;
    reg [511:0] w_high_times_19;
    reg [255:0] w_result;
    reg         w_done;

    //=========================================================================
    // Outputs
    //=========================================================================
    assign result = r_result;
    assign done   = r_done;

    //=========================================================================
    // Always Block 1: Register updates
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            r_state         <= IDLE;
            r_product       <= 512'd0;
            r_multiplicand  <= 512'd0;
            r_multiplier    <= 256'd0;
            r_bit_counter   <= 9'd0;
            r_temp          <= 512'd0;
            r_high_times_19 <= 512'd0;
            r_result        <= 256'd0;
            r_done          <= 1'b0;
        end
        else begin
            r_state         <= w_next_state;
            r_product       <= w_product;
            r_multiplicand  <= w_multiplicand;
            r_multiplier    <= w_multiplier;
            r_bit_counter   <= w_bit_counter;
            r_temp          <= w_temp;
            r_high_times_19 <= w_high_times_19;
            r_result        <= w_result;
            r_done          <= w_done;
        end
    end

    //=========================================================================
    // Always Block 2: Next state logic
    //=========================================================================
    always @(*) begin
        w_next_state = r_state;

        case (r_state)
            IDLE: begin
                if (start)
                    w_next_state = MULTIPLY;
            end

            MULTIPLY: begin
                if (r_bit_counter == 9'd255)
                    w_next_state = REDUCE_1;
            end

            REDUCE_1: begin
                w_next_state = REDUCE_2;
            end

            REDUCE_2: begin
                w_next_state = FINAL_CHECK;
            end

            FINAL_CHECK: begin
                if (r_temp[511:255] != 257'd0)
                    w_next_state = REDUCE_2;  // Need another reduction
                else
                    w_next_state = DONE_ST;
            end

            DONE_ST: begin
                w_next_state = IDLE;  // Return immediately
            end

            default: w_next_state = IDLE;
        endcase
    end

    //=========================================================================
    // Always Block 3: Datapath logic
    //=========================================================================
    always @(*) begin
        // Defaults: hold values
        w_product       = r_product;
        w_multiplicand  = r_multiplicand;
        w_multiplier    = r_multiplier;
        w_bit_counter   = r_bit_counter;
        w_temp          = r_temp;
        w_high_times_19 = r_high_times_19;
        w_result        = r_result;
        w_done          = 1'b0;

        case (r_state)

            IDLE: begin
                w_done = 1'b0;
                if (start) begin
                    // Initialize
                    w_product       = 512'd0;
                    w_multiplicand  = {256'd0, a};  // ✅ Pad to 512 bits
                    w_multiplier    = b;
                    w_bit_counter   = 9'd0;
                end
            end

            MULTIPLY: begin
                // Shift-and-add: one bit per clock
                if (r_multiplier[0]) begin
                    w_product = r_product + r_multiplicand;
                end

                // ✅ Shift within 512 bits - no bits lost!
                w_multiplicand = r_multiplicand << 1;
                w_multiplier   = r_multiplier >> 1;
                w_bit_counter  = r_bit_counter + 9'd1;
            end

            REDUCE_1: begin
                // Compute high * 19
                // high = product[511:255] (257 bits)
                // 19 = 16 + 2 + 1
                w_high_times_19 = ({255'd0, r_product[511:255]} << 4) +
                                  ({255'd0, r_product[511:255]} << 1) +
                                   {255'd0, r_product[511:255]};
            end

            REDUCE_2: begin
                // temp = high * 19 + low
                w_temp = r_high_times_19 + {257'd0, r_product[254:0]};
            end

            FINAL_CHECK: begin
                if (r_temp[511:255] != 257'd0) begin
                    // Still >= 2^255, reduce again
                    w_high_times_19 = ({255'd0, r_temp[511:255]} << 4) +
                                      ({255'd0, r_temp[511:255]} << 1) +
                                       {255'd0, r_temp[511:255]};
                    w_product = r_temp;
                end
                else begin
                    // Result in range [0, 2^255)
                    // Final check: if >= p, subtract p
                    if (r_temp[255:0] >= P) begin
                        w_result = r_temp[255:0] - P;
                    end
                    else begin
                        w_result = r_temp[255:0];
                    end
                end
            end

            DONE_ST: begin
                w_done = 1'b1;
            end

            default: begin
                w_done = 1'b0;
            end
        endcase
    end

endmodule



//=============================================================================
// mod_inv.v - Modular Inverse using Fermat's Little Theorem
// Computes a^(-1) mod p = a^(p-2) mod p
// Uses binary exponentiation with mod_mul
//=============================================================================

module mod_inv(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [255:0] a,
    output wire [255:0] result,
    output wire         done,

    // Interface to mod_mul (shared resource in MAU)
    output wire         mul_start,
    output wire [255:0] mul_a,
    output wire [255:0] mul_b,
    input  wire [255:0] mul_result,
    input  wire         mul_done
);

    // p - 2 = 2^255 - 21
    parameter [255:0] P_MINUS_2 = 256'h7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEB;

    // State encoding
    parameter [2:0] IDLE            = 3'd0;
    parameter [2:0] INIT            = 3'd1;
    parameter [2:0] CHECK_BIT       = 3'd2;
    parameter [2:0] MUL_RESULT      = 3'd3;
    parameter [2:0] WAIT_MUL_RESULT = 3'd4;
    parameter [2:0] SQ_BASE         = 3'd5;
    parameter [2:0] WAIT_SQ_BASE    = 3'd6;
    parameter [2:0] DONE_ST         = 3'd7;

    //=========================================================================
    // Registers (r_ prefix)
    //=========================================================================
    reg [2:0]   r_state;
    reg [255:0] r_result;
    reg [255:0] r_base;
    reg [255:0] r_exp;
    reg [8:0]   r_bit_counter;
    reg         r_done;
    reg         r_mul_start;
    reg [255:0] r_mul_a;
    reg [255:0] r_mul_b;

    //=========================================================================
    // Combinational wires (w_ prefix)
    //=========================================================================
    reg [2:0]   w_next_state;
    reg [255:0] w_result;
    reg [255:0] w_base;
    reg [255:0] w_exp;
    reg [8:0]   w_bit_counter;
    reg         w_done;
    reg         w_mul_start;
    reg [255:0] w_mul_a;
    reg [255:0] w_mul_b;

    //=========================================================================
    // Output assignments (driven from registers)
    //=========================================================================
    assign result    = r_result;
    assign done      = r_done;
    assign mul_start = r_mul_start;
    assign mul_a     = r_mul_a;
    assign mul_b     = r_mul_b;

    //=========================================================================
    // Always Block 1: Clocked register updates
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            r_state       <= IDLE;
            r_result      <= 256'd0;
            r_base        <= 256'd0;
            r_exp         <= 256'd0;
            r_bit_counter <= 9'd0;
            r_done        <= 1'b0;
            r_mul_start   <= 1'b0;
            r_mul_a       <= 256'd0;
            r_mul_b       <= 256'd0;
        end
        else begin
            r_state       <= w_next_state;
            r_result      <= w_result;
            r_base        <= w_base;
            r_exp         <= w_exp;
            r_bit_counter <= w_bit_counter;
            r_done        <= w_done;
            r_mul_start   <= w_mul_start;
            r_mul_a       <= w_mul_a;
            r_mul_b       <= w_mul_b;
        end
    end

    //=========================================================================
    // Always Block 2: Next state logic
    //=========================================================================
    always @(*) begin
        w_next_state = r_state; // Default: hold current state

        case (r_state)
            IDLE: begin
                if (start)
                    w_next_state = INIT;
            end

            INIT: begin
                w_next_state = CHECK_BIT;
            end

            CHECK_BIT: begin
                if (r_exp[0])
                    w_next_state = MUL_RESULT;   // Bit is 1: multiply
                else
                    w_next_state = SQ_BASE;       // Bit is 0: skip to square
            end

            MUL_RESULT: begin
                // Just issued mul_start, go wait
                w_next_state = WAIT_MUL_RESULT;
            end

            WAIT_MUL_RESULT: begin
                if (mul_done)
                    w_next_state = SQ_BASE;       // Multiply done, now square
            end

            SQ_BASE: begin
                // Just issued mul_start for squaring, go wait
                w_next_state = WAIT_SQ_BASE;
            end

            WAIT_SQ_BASE: begin
                if (mul_done) begin
                    if (r_bit_counter == 9'd255)
                        w_next_state = DONE_ST;   // Processed all 256 bits
                    else
                        w_next_state = CHECK_BIT; // Next bit
                end
            end

            DONE_ST: begin
                if (!start)
                    w_next_state = IDLE;
            end

            default: w_next_state = IDLE;
        endcase
    end

    //=========================================================================
    // Always Block 3: Output and signal logic
    //=========================================================================
    always @(*) begin
        // Defaults: hold all register values
        w_result      = r_result;
        w_base        = r_base;
        w_exp         = r_exp;
        w_bit_counter = r_bit_counter;
        w_done        = 1'b0;
        w_mul_start   = 1'b0;
        w_mul_a       = r_mul_a;
        w_mul_b       = r_mul_b;

        case (r_state)

            IDLE: begin
                w_done = 1'b0;
            end

            INIT: begin
                // Load initial values
                // These get registered on the next clock edge
                // CHECK_BIT will see them correctly
                w_result      = 256'd1;
                w_base        = a;
                w_exp         = P_MINUS_2;
                w_bit_counter = 9'd0;
            end

            CHECK_BIT: begin
                // No outputs needed here
                // Just checking r_exp[0] for state transition
            end

            MUL_RESULT: begin
                // Issue: result = result * base
                // Use current r_result and r_base (OLD base, before squaring)
                w_mul_a     = r_result;
                w_mul_b     = r_base;
                w_mul_start = 1'b1;
            end

            WAIT_MUL_RESULT: begin
                // Wait for mod_mul to finish
                // When done, capture result
                if (mul_done) begin
                    w_result = mul_result;
                end
            end

            SQ_BASE: begin
                // Issue: base = base * base
                // Use current r_base (still old value, not yet squared)
                w_mul_a     = r_base;
                w_mul_b     = r_base;
                w_mul_start = 1'b1;
            end

            WAIT_SQ_BASE: begin
                // Wait for mod_mul to finish squaring
                // When done: update base, shift exp, increment counter
                if (mul_done) begin
                    w_base        = mul_result;
                    w_exp         = {1'b0, r_exp[255:1]};
                    w_bit_counter = r_bit_counter + 9'd1;
                end
            end

            DONE_ST: begin
                w_done = 1'b1;
            end

            default: begin
                w_done = 1'b0;
            end
        endcase
    end

endmodule

