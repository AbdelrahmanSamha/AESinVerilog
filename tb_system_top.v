`timescale 1ns/1ps

module tb_system_top;

    // ---------------------------------------------------------
    // Clock generation (10 ns period)
    // ---------------------------------------------------------
    reg clk = 0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // DUT inputs
    // ---------------------------------------------------------
    reg rst_n = 0;
    reg init_accel = 0;

    // ---------------------------------------------------------
    // DUT outputs
    // ---------------------------------------------------------
    wire done;
    wire [7:0] ciphertext;

    // ---------------------------------------------------------
    // Instantiate DUT
    // ---------------------------------------------------------
    system_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .init_accel(init_accel),
        .plaintext(),     // unused (internally fixed)
        .key(),           // unused (internally fixed)
        .done(done),
        .ciphertext(ciphertext),
		  .dec(1'b0)
    );

    initial begin
        $display("Starting system_top testbench...");

        // Initial conditions
        rst_n = 0;
        init_accel = 0;

        // Apply reset
        #20;
        rst_n = 1;

        // Give system a moment
        #20;

        // Pulse init_accel
        init_accel = 1;
        #10;
        init_accel = 0;

        // Wait until done asserted
        wait(done == 1'b1);

        // Display output
        $display("t=%0dns  DONE asserted!", $time);
        $display("Ciphertext = 0x%02h", ciphertext);

        // Let it settle a bit
        #1000;

        $display("Testbench finished.");
        $finish;
    end

endmodule
