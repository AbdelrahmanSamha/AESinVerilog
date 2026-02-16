module TRNG(
  input         clk,
  input         rst_n,
  input         start,
  output        enable_osc,
  output reg    done,
  output reg [255:0] random_data
);
/*
  parameter LATENCY = 20;

  assign enable_osc = 1'b1;

  reg start_d;
  reg busy;
  integer cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done        <= 1'b0;
      random_data <= 256'd0;
      start_d     <= 1'b0;
      busy        <= 1'b0;
      cnt         <= 0;
    end else begin
      done    <= 1'b0;
      start_d <= start;

      // rising edge detect
      if (!busy && start && !start_d) begin
        busy <= 1'b1;
        cnt  <= LATENCY;

        // random fallback
        random_data <= {
          $random,$random,$random,$random,
          $random,$random,$random,$random
        };
      end

      if (busy) begin
        if (cnt == 0) begin
          done <= 1'b1;
          busy <= 1'b0;
        end else begin
          cnt <= cnt - 1;
        end
      end
    end
  end
*/
endmodule
