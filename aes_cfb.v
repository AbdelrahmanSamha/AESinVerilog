module aes_cfb #(
     parameter integer KEY_SIZE = 128   // 128, 192, 256
)(
     input  wire                  clk,
     input  wire                  rst_n,

     input  wire                  init,
     input  wire                  dec,                 // 0=ENC, 1=DEC (CFB uses AES-ENC for both; dec affects chaining only)
     input  wire [KEY_SIZE-1:0]   og_key,
     input  wire [127:0]          iv,

     input  wire [127:0]          text_in,
     input  wire                  terminate_session,

     input  wire                  key_sel,
     input  wire                  valid_in_key_aes,
     input  wire                  valid_in_block_aes,

     output reg  [127:0]          text_out,
     output wire                  done,

     output reg                   key_expand_ready,

     output wire [127:0]          next_encstate_out,
     output wire [3:0]            round_counter_out,
     output wire                  round_mem_we
);

     // ------------------------------------------------
     // FSM states
     // ------------------------------------------------
     localparam IDLE        = 3'b000,
                KEYEXP_INIT = 3'b001,
                KEYEXP_WAIT = 3'b010,
                CIPHER_HOLD = 3'b011,
                CIPHER_WAIT = 3'b100;

     reg [2:0] state, next_state;

     reg mem_key_rw, mem_key_rw_next;
     reg cipher_start;

     reg done_reg, done_reg_next;
     assign done = done_reg;

     reg key_exp_start;

     // chaining (CFB: feedback is IV then ciphertext)
     reg  [127:0] chain_reg;
     wire [127:0] text_out_internal;
     reg          first_block;

     // ------------------------------------------------
     // Wires
     // ------------------------------------------------
     wire         key_expand_finish;
     wire         block_done;

     wire [3:0]   read_key_address;
     wire [3:0]   write_key_address;
     wire [4:0]   key_address;

     wire         mem_round_key_en;
     wire [127:0] gen_roundkey;

     wire [127:0] chain_val     = first_block ? iv : chain_reg;

     // ---------------- CFB core equations ----------------
     // AES input is always chain_val (IV / previous ciphertext)
     wire [127:0] aes_in_block  = chain_val;
     wire [127:0] aes_raw_out;                 // AES_ENC(chain_val)
     assign text_out_internal   = text_in ^ aes_raw_out;  // ENC: C=P^E(feedback), DEC: P=C^E(feedback)
     // ----------------------------------------------------

     // roundkey output from memory (DECLARE ONCE!)
     wire [127:0] roundkey_out;

     // ------------------------------------------------
     // Block Encrypt (FORCED ENCRYPT for CFB)
     // ------------------------------------------------
     block_encrypt BE (
          .clk           (clk),
          .rst_n         (rst_n),
          .start         (cipher_start),
          .dec           (1'b0),         // CFB always uses AES encryption
          .plaintext     (aes_in_block),
          .roundkey      (roundkey_out),
          .ciphertext    (aes_raw_out),
          .key_address   (read_key_address),
          .done          (block_done),

          .next_encstate (next_encstate_out),
          .round_counter (round_counter_out),
          .round_mem_we  (round_mem_we)
     );

     // ------------------------------------------------
     // Key Expansion
     // ------------------------------------------------
     aes_keyexpand #(KEY_SIZE) keyexp (
          .clk           (clk),
          .rst_n         (rst_n),
          .init          (key_exp_start),
          .og_key        (og_key),
          .store_key_mem (mem_round_key_en),
          .address       (write_key_address),
          .round_key     (gen_roundkey),
          .finish        (key_expand_finish)
     );

     // ------------------------------------------------
     // Round-key memory
     // ------------------------------------------------
     mem_round_keys keymem (
          .clock   (clk),
          .address (key_address),
          .data    (gen_roundkey),
          .wren    (mem_round_key_en),
          .q       (roundkey_out)
     );

     mux2to1 #(4) addr_mux (
          .in0 (read_key_address),
          .in1 (write_key_address),
          .sel (mem_key_rw),
          .out (key_address[3:0])
     );
     assign key_address[4] = 1'b0;

     // ------------------------------------------------
     // Sequential: state + regs
     // ------------------------------------------------
     always @(posedge clk) begin
          if (!rst_n) begin
                state            <= IDLE;
                mem_key_rw       <= 1'b0;
                done_reg         <= 1'b0;
                key_expand_ready <= 1'b0;

                chain_reg        <= 128'd0;
                text_out         <= 128'd0;
                first_block      <= 1'b1;
          end else begin
                state    <= next_state;
                done_reg <= done_reg_next;

                // mem mux control
                if (key_expand_finish)
                     mem_key_rw <= 1'b0;
                else
                     mem_key_rw <= mem_key_rw_next;

                // key_expand_ready
                if (key_exp_start)
                     key_expand_ready <= 1'b0;

                if (key_expand_finish)
                     key_expand_ready <= 1'b1;

                if (terminate_session)
                     key_expand_ready <= 1'b0;

                if (next_state == IDLE)
                     key_expand_ready <= 1'b0;

                // latch output when block finishes
                if (block_done)
                     text_out <= text_out_internal;

                // ---------------- CFB chaining update ----------------
                // Feedback is ciphertext each block.
                // ENC: feedback = produced ciphertext = text_out_internal
                // DEC: feedback = received ciphertext = text_in
                if (block_done) begin
                     if (dec)
                          chain_reg <= text_in;            // DEC feedback is ciphertext input
                     else
                          chain_reg <= text_out_internal;  // ENC feedback is ciphertext output

                     first_block <= 1'b0;
                end
                // -----------------------------------------------------

                // reset chaining at new session start
                if (state == IDLE && next_state == KEYEXP_INIT) begin
                     chain_reg   <= 128'd0;
                     first_block <= 1'b1;
                end

                if (terminate_session) begin
                     chain_reg   <= 128'd0;
                     first_block <= 1'b1;
                end
          end
     end

     // ------------------------------------------------
     // Next-state logic
     // ------------------------------------------------
     always @(*) begin
          next_state = state;

          case (state)
                IDLE:
                     if (init) next_state = KEYEXP_INIT;

                KEYEXP_INIT:
                     if (valid_in_key_aes) next_state = KEYEXP_WAIT;

                KEYEXP_WAIT:
                     if (key_expand_finish) next_state = CIPHER_HOLD;

                CIPHER_HOLD:
                     if (valid_in_block_aes) next_state = CIPHER_WAIT;
                     else if (terminate_session) next_state = IDLE;

                CIPHER_WAIT:
                     if (block_done) next_state = CIPHER_HOLD;

                default:
                     next_state = IDLE;
          endcase
     end

     // ------------------------------------------------
     // Output logic
     // ------------------------------------------------
     always @(*) begin
          key_exp_start   = 1'b0;
          cipher_start    = 1'b0;
          mem_key_rw_next = mem_key_rw;
          done_reg_next   = 1'b0; // 1-cycle pulse

          case (state)
                IDLE: begin
                     mem_key_rw_next = 1'b0;
                end

                KEYEXP_INIT: begin
                     if (valid_in_key_aes) begin
                          key_exp_start   = 1'b1;
                          mem_key_rw_next = 1'b1; // write keys
                     end
                end

                KEYEXP_WAIT: begin
                     // wait
                end

                CIPHER_HOLD: begin
                     if (valid_in_block_aes) begin
                          cipher_start    = 1'b1;
                          mem_key_rw_next = 1'b0; // read keys
                     end
                end

                CIPHER_WAIT: begin
                     if (block_done) begin
                          done_reg_next = 1'b1;
                     end
                end
          endcase
     end

endmodule
