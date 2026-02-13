`timescale 1ns/1ps

module tb_toplevel_hash;

    // ----------------------
    // Signals
    // ----------------------
    reg clk;
    reg rst_n;
    reg sys_start;
    reg [31:0] length;
    reg valid_data;
    reg [511:0] data;
    
    wire [255:0] hash_out;
    wire hash_valid;
    
    // ----------------------
    // Clock generation
    // ----------------------
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz clock

    // ----------------------
    // Instantiate DUT
    // ----------------------
    toplevel_hash dut (
        .clk(clk),
        .rst_n(rst_n),
        .sys_start(sys_start),
        .length(length),
        .valid_data(valid_data),
        .data(data),
        .hash_out(hash_out),
        .hash_valid(hash_valid)
    );

    // ----------------------
    // Test sequence
    // ----------------------
    initial begin
        // Initialize signals
        rst_n = 0;
        sys_start = 0;
        length = 0;
        valid_data = 0;
        data = 512'b0;

        // Apply reset
        #20;
        rst_n = 1;
        #20;

        // Send start and length
        sys_start = 1;
        length = 32'd3;  // we will hash 3 blocks
        #10;
        sys_start = 0;

        // Wait a few cycles
        #50;

        // Send first data block
        valid_data = 1;
        //data = 512'h0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef;
          data = 512'h23b4213b4b234b234b23492347982308947908789787989789789789789788978779878978791273213543512367452136752345116567512334887878716266;
		  #50;
        valid_data = 0;

        // Wait "long long" time (simulate processing)
        #5000;

        // Send second data block
        valid_data = 1;
        //data = 512'h80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200;
          data = 512'habdbdbbdb12821793128973897214980987897432879423891476856abdbdbdbbdbd129831892738291738921748972314589712389982198237489723489231;
		  #50;
        valid_data = 0;
		  // Wait "long long" time (simulate processing)
        #5000;
		  
		  valid_data = 1;
			 data = 512'h80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400;
		  #50;
        valid_data = 0;
        // Wait more time for SHA256 to finish
        

        // Wait until hash_valid is high
        wait(hash_valid == 1);
        $display("Final hash: %h", hash_out);

        // Stop simulation
        #20;
        $stop;
    end

endmodule
