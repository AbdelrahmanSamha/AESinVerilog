//-------------------------------------------------------------------------
//------------------------DESCRIPTION OF MODULE----------------------------
// This Module is responsible of generating the round keys, each round key 
//is generated and stored in BLOCKRAM. The module is parametrized to 
//generate the needed round keys for AES 128, 192, 256 key lengths. 
// 
// The module is Asynchronus with the rest of the encryption system,
//meaning that it expects a Initialization signal denoted as (init) 
//and when its done generating the keys it responds with a done signal
//denoted as (finish). 
// The module is controlled by the main FSM, but it can be taken as is
//with the modules that are instantiated inside it to be used
//in any further implementations of AES. 
//The modules used by this are: 
// -aes_rcon
// -mux2to1
// -sbox
//
//
// for AES 256 the module finishs generating the keys 112 cycles after 
//receiving the init signal. 
//
// To integrate this module succefully, you need to have a block ram with 
//atleast 16 entries to support all key sizes, each entry being 128bits. 
//
// The datapath should be provided with the file containing this Module, 
//showcasing the registers and the wirings for each parameter used in 
//different colors.   
//
// The module (as code) is split in two halves, you will first see the 
//datapath, and later the statemachine controlling the datapath. 




module aes_keyexpand #(
    parameter integer KEY_SIZE = 128   // 128, 192, or 256
)(
    input               clk,
    input               rst_n,
    input               init,
    input  wire [KEY_SIZE-1:0] og_key,   // width adapts automatically
    output reg           store_key_mem,
    output wire [3:0]    address,
    output wire [127:0]  round_key,
    output reg           finish
);

    // derive Nk and Nr from the key size.
    localparam integer Nk =
        (KEY_SIZE == 128) ? 4 :
        (KEY_SIZE == 192) ? 6 :
        (KEY_SIZE == 256) ? 8 :
        0;   

    localparam integer Nr =
        (KEY_SIZE == 128) ? 10 :
        (KEY_SIZE == 192) ? 12 :
        (KEY_SIZE == 256) ? 14 :
        0;


    localparam [3:0] LAST_ADDR =
        (KEY_SIZE == 128) ? 4'd10 :
        (KEY_SIZE == 192) ? 4'd12 :
        (KEY_SIZE == 256) ? 4'd14 :
        4'd0;

    //-------------------------------------------------------------------------
    // DATAPATH. 
    //-------------------------------------------------------------------------

    reg  [31:0] w        [0:Nk-1];
    reg         load     [0:Nk-1];
    reg         mux_sel  [0:Nk-1];
    wire [31:0] w_mux    [0:Nk-1];

    wire [31:0] rotation, sbox;
    wire [31:0] xor1, xor2, xor2_mux;
    reg  [1:0]  xor2_s;
    wire [31:0] rcon;
    wire [31:0] Nk8_subword_only;

    // statemachine wires and registers:
    reg  [2:0] state, next_state;
    reg  [3:0] counter, next_counter;
    reg  [3:0] r_counter, next_r_counter;
    reg  [5:0] iter_counter, next_iter_counter;
    reg  [2:0] store_counter, next_store_counter;
    reg  [3:0] address_counter, next_address_counter;

    integer word_idx;
    always @(posedge clk) begin
        if (!rst_n) begin
            for (word_idx = 0; word_idx < Nk; word_idx = word_idx + 1)
                w[word_idx] <= 32'b0;
        end
        else begin
            for (word_idx = 0; word_idx < Nk; word_idx = word_idx + 1)
                if (load[word_idx])
                    w[word_idx] <= w_mux[word_idx];
        end
    end

    assign rotation[7:0]   = w[Nk-1][31:24];
    assign rotation[15:8]  = w[Nk-1][7:0];
    assign rotation[23:16] = w[Nk-1][15:8];
    assign rotation[31:24] = w[Nk-1][23:16];

    // normal path Sbox
    sbox ak0 (.in(rotation[7:0]),   .out(sbox[7:0]));
    sbox ak1 (.in(rotation[15:8]),  .out(sbox[15:8]));
    sbox ak2 (.in(rotation[23:16]), .out(sbox[23:16]));
    sbox ak3 (.in(rotation[31:24]), .out(sbox[31:24]));

    // We need this for Nk = 8, when iter_counter % 4 == 0
    sbox sk0 (.in(w[Nk-1][7:0]),   .out(Nk8_subword_only[7:0]));
    sbox sk1 (.in(w[Nk-1][15:8]),  .out(Nk8_subword_only[15:8]));
    sbox sk2 (.in(w[Nk-1][23:16]), .out(Nk8_subword_only[23:16]));
    sbox sk3 (.in(w[Nk-1][31:24]), .out(Nk8_subword_only[31:24]));

    aes_rcon u_rcon (
        .round    (r_counter),
        .rcon_out (rcon)
    );

    assign xor1 = sbox ^ rcon;
    assign xor2 = xor2_mux ^ w[0];

    assign xor2_mux =
        (xor2_s == 2'b10) ? xor1 :
        (xor2_s == 2'b01) ? Nk8_subword_only :
                            w[Nk-1];

    genvar mux_idx;
    generate
        for (mux_idx = 0; mux_idx < Nk-1; mux_idx = mux_idx + 1) begin : gen_key_word_mux
            mux2to1 #(32) key_word_mux (
                .in0 (og_key[32*(Nk-mux_idx)-1 -: 32]),
                .in1 (w[mux_idx+1]),
                .sel (mux_sel[mux_idx]),
                .out (w_mux[mux_idx])
            );
        end
    endgenerate

    mux2to1 #(32) tmux (
        .in0 (og_key[31:0]),
        .in1 (xor2),
        .sel (mux_sel[Nk-1]),
        .out (w_mux[Nk-1])
    );

    assign round_key = {w[0], w[1], w[2], w[3]};

    //-------------------------------------------------------------------------
    // State machine
    //-------------------------------------------------------------------------

    localparam IDLE         = 3'b000,
               INIT         = 3'b001,
               INITSTOREMEM = 3'b010,
               EVAL         = 3'b011,
               STORE        = 3'b100;

    always @(posedge clk) begin
        if (!rst_n) begin
            state            <= IDLE;
            counter          <= 4'b0;
            r_counter        <= 4'd1;
            iter_counter     <= Nk[5:0];
            store_counter    <= 3'b0;
            address_counter  = 4'd0;
        end
        else begin
            state            <= next_state;
            counter          <= next_counter;
            r_counter        <= next_r_counter;
            iter_counter     <= next_iter_counter;
            store_counter    <= next_store_counter;
            address_counter  <= next_address_counter;
        end
    end

    always @* begin
        finish     = 1'b0;
        next_state = state;

        case (state)
            IDLE:
                if (init)
                    next_state = INIT;

            INIT:
                next_state = INITSTOREMEM;

            INITSTOREMEM:
                next_state = EVAL;

            EVAL: begin
                if (counter == Nk[3:0] && address_counter == LAST_ADDR) begin
                    next_state = IDLE;
                    finish     = 1'b1;
                end
                else
                    next_state = STORE;
            end

            STORE:
                next_state = EVAL;

            default:
                next_state = IDLE;
        endcase
    end

    integer j;
    always @* begin
        for (j = 0; j < Nk; j = j + 1) begin
            load[j]    = 1'b0;
            mux_sel[j] = 1'b0;
        end

        xor2_s               = 2'b0;
        store_key_mem        = 1'b0;
        next_address_counter = address_counter;
        next_counter         = counter;
        next_r_counter       = r_counter;
        next_iter_counter    = iter_counter;
        next_store_counter   = store_counter;

        case (state)
            IDLE: begin
                next_counter      = 4'd0;
                next_r_counter    = 4'd1;
                next_iter_counter = Nk[5:0];
            end

            INIT: begin
                for (j = 0; j < Nk; j = j + 1) begin
                    load[j]    = 1'b1;
                    mux_sel[j] = 1'b0;
                end
            end

            INITSTOREMEM: begin
                store_key_mem        = 1'b1;
                next_address_counter = 4'd1;
            end

            EVAL: begin
                if (counter < Nk[3:0])
                    next_counter = counter + 4'd1;
                else if (counter == Nk[3:0]) begin
                    next_counter   = 4'd1;
                    next_r_counter = r_counter + 4'd1;
                end

                if (store_counter < 3'd4)
                    next_store_counter = store_counter + 3'd1;
                else begin
                    store_key_mem        = 1'b1;
                    next_store_counter   = 3'd1;
                    next_address_counter = address_counter + 4'd1;
                end
            end

            STORE: begin
                for (j = 0; j < Nk; j = j + 1) begin
                    load[j]    = 1'b1;
                    mux_sel[j] = 1'b1;
                end

                next_iter_counter = iter_counter + 6'd1;

                if (
                    (Nk == 4 && iter_counter[1:0] == 2'b00) ||
                    (Nk == 6 && iter_counter % 6 == 0)     ||
                    (Nk == 8 && iter_counter[2:0] == 3'b000)
                )
                    xor2_s = 2'b10;
                else if (Nk == 8 && (iter_counter % 4 == 0))
                    xor2_s = 2'b01;
            end
        endcase
    end

    assign address = address_counter;

endmodule
