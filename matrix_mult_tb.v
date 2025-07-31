`timescale 1ns/1ps

module matrix_mult_tb;

    // Test parameters - small matrices for easy verification
    parameter DATA_WIDTH = 16;
    parameter FRAC_WIDTH = 8;
    parameter M = 4;  // Test with 4x3 * 3x2 = 4x2
    parameter N = 2;
    parameter K = 3;
    
    // Clock period
    parameter CLK_PERIOD = 10;
    
    // DUT signals
    reg clk;
    reg rst_n;
    reg start;
    
    reg signed [DATA_WIDTH-1:0] a_data;
    reg [$clog2(M)-1:0] a_row;
    reg [$clog2(K)-1:0] a_col;
    reg a_valid;
    
    reg signed [DATA_WIDTH-1:0] b_data;
    reg [$clog2(K)-1:0] b_row;
    reg [$clog2(N)-1:0] b_col;
    reg b_valid;
    
    wire signed [DATA_WIDTH-1:0] c_data;
    wire [$clog2(M)-1:0] c_row;
    wire [$clog2(N)-1:0] c_col;
    wire c_valid;
    wire done;
    
    // Test matrices storage
    reg signed [DATA_WIDTH-1:0] test_a [0:M-1][0:K-1];
    reg signed [DATA_WIDTH-1:0] test_b [0:K-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] expected_c [0:M-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] result_c [0:M-1][0:N-1];
    
    // Test variables
    integer i, j, k;
    reg signed [2*DATA_WIDTH+$clog2(K)-1:0] temp_sum;
    
    // Instantiate DUT
    matrix_mult #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .M(M),
        .N(N),
        .K(K)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .a_data(a_data),
        .a_row(a_row),
        .a_col(a_col),
        .a_valid(a_valid),
        .b_data(b_data),
        .b_row(b_row),
        .b_col(b_col),
        .b_valid(b_valid),
        .c_data(c_data),
        .c_row(c_row),
        .c_col(c_col),
        .c_valid(c_valid),
        .done(done)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Fixed-point conversion functions
    function signed [DATA_WIDTH-1:0] to_fixed;
        input real value;
        begin
            to_fixed = value * (1 << FRAC_WIDTH);
        end
    endfunction
    
    function real from_fixed;
        input signed [DATA_WIDTH-1:0] value;
        begin
            from_fixed = $itor(value) / (1 << FRAC_WIDTH);
        end
    endfunction
    
    // Initialize test case
    task init_test_case_1;
        begin
            $display("Test Case 1: Simple integer test (4x3 * 3x2)");
            // Matrix A (4x3)
            test_a[0][0] = to_fixed(1.0); test_a[0][1] = to_fixed(2.0); test_a[0][2] = to_fixed(3.0);
            test_a[1][0] = to_fixed(4.0); test_a[1][1] = to_fixed(5.0); test_a[1][2] = to_fixed(6.0);
            test_a[2][0] = to_fixed(7.0); test_a[2][1] = to_fixed(8.0); test_a[2][2] = to_fixed(9.0);
            test_a[3][0] = to_fixed(1.0); test_a[3][1] = to_fixed(0.0); test_a[3][2] = to_fixed(2.0);
            
            // Matrix B (3x2)
            test_b[0][0] = to_fixed(1.0); test_b[0][1] = to_fixed(0.0);
            test_b[1][0] = to_fixed(0.0); test_b[1][1] = to_fixed(1.0);
            test_b[2][0] = to_fixed(1.0); test_b[2][1] = to_fixed(1.0);
            
            // Expected C = A*B (4x2)
            // [1 2 3] * [1 0]   [1+0+3   0+2+3]   [4  5]
            // [4 5 6]   [0 1] = [4+0+6   0+5+6] = [10 11]
            // [7 8 9]   [1 1]   [7+0+9   0+8+9]   [16 17]
            // [1 0 2]           [1+0+2   0+0+2]   [3  2]
        end
    endtask
    
    task init_test_case_2;
        begin
            $display("Test Case 2: Fractional test (4x3 * 3x2)");
            // Matrix A with fractional values
            test_a[0][0] = to_fixed(0.5);  test_a[0][1] = to_fixed(1.5);  test_a[0][2] = to_fixed(0.25);
            test_a[1][0] = to_fixed(2.0);  test_a[1][1] = to_fixed(0.5);  test_a[1][2] = to_fixed(1.0);
            test_a[2][0] = to_fixed(0.25); test_a[2][1] = to_fixed(0.75); test_a[2][2] = to_fixed(1.25);
            test_a[3][0] = to_fixed(1.0);  test_a[3][1] = to_fixed(1.0);  test_a[3][2] = to_fixed(1.0);
            
            // Matrix B with fractional values
            test_b[0][0] = to_fixed(2.0);  test_b[0][1] = to_fixed(0.5);
            test_b[1][0] = to_fixed(1.0);  test_b[1][1] = to_fixed(2.0);
            test_b[2][0] = to_fixed(0.5);  test_b[2][1] = to_fixed(1.0);
        end
    endtask
    
    task init_test_case_3;
        begin
            $display("Test Case 3: Identity matrix test (3x3 * 3x2)");
            // For this test, we'll use M=3, K=3, N=2 conceptually
            // Matrix A is identity (using first 3x3 of our 4x3)
            test_a[0][0] = to_fixed(1.0); test_a[0][1] = to_fixed(0.0); test_a[0][2] = to_fixed(0.0);
            test_a[1][0] = to_fixed(0.0); test_a[1][1] = to_fixed(1.0); test_a[1][2] = to_fixed(0.0);
            test_a[2][0] = to_fixed(0.0); test_a[2][1] = to_fixed(0.0); test_a[2][2] = to_fixed(1.0);
            test_a[3][0] = to_fixed(0.0); test_a[3][1] = to_fixed(0.0); test_a[3][2] = to_fixed(0.0);
            
            // Matrix B - should appear unchanged in result
            test_b[0][0] = to_fixed(5.0); test_b[0][1] = to_fixed(3.0);
            test_b[1][0] = to_fixed(2.0); test_b[1][1] = to_fixed(7.0);
            test_b[2][0] = to_fixed(1.0); test_b[2][1] = to_fixed(4.0);
        end
    endtask
    
    // Test Case 4: Square matrix with negative values (3x3 * 3x2)
    task init_test_case_4;
        begin
            $display("Test Case 4: Square matrix with negative values");
            // Matrix A with negative values
            test_a[0][0] = to_fixed(-2.0); test_a[0][1] = to_fixed(3.0);  test_a[0][2] = to_fixed(-1.0);
            test_a[1][0] = to_fixed(4.0);  test_a[1][1] = to_fixed(-5.0); test_a[1][2] = to_fixed(2.0);
            test_a[2][0] = to_fixed(-1.0); test_a[2][1] = to_fixed(2.0);  test_a[2][2] = to_fixed(-3.0);
            test_a[3][0] = to_fixed(0.0);  test_a[3][1] = to_fixed(0.0);  test_a[3][2] = to_fixed(0.0);
            
            // Matrix B with mixed values
            test_b[0][0] = to_fixed(1.0);  test_b[0][1] = to_fixed(-2.0);
            test_b[1][0] = to_fixed(-3.0); test_b[1][1] = to_fixed(4.0);
            test_b[2][0] = to_fixed(2.0);  test_b[2][1] = to_fixed(-1.0);
        end
    endtask
    
    // Test Case 5: Single element matrices (1x1 * 1x1)
    task init_test_case_5;
        begin
            $display("Test Case 5: Single element matrices (1x1)");
            // Only use top-left corner for 1x1 multiplication
            test_a[0][0] = to_fixed(-3.5); test_a[0][1] = to_fixed(0.0); test_a[0][2] = to_fixed(0.0);
            test_a[1][0] = to_fixed(0.0);  test_a[1][1] = to_fixed(0.0); test_a[1][2] = to_fixed(0.0);
            test_a[2][0] = to_fixed(0.0);  test_a[2][1] = to_fixed(0.0); test_a[2][2] = to_fixed(0.0);
            test_a[3][0] = to_fixed(0.0);  test_a[3][1] = to_fixed(0.0); test_a[3][2] = to_fixed(0.0);
            
            test_b[0][0] = to_fixed(2.25); test_b[0][1] = to_fixed(0.0);
            test_b[1][0] = to_fixed(0.0);  test_b[1][1] = to_fixed(0.0);
            test_b[2][0] = to_fixed(0.0);  test_b[2][1] = to_fixed(0.0);
        end
    endtask
    
    // Test Case 6: Vector multiplication (1x3 * 3x1) = scalar
    task init_test_case_6;
        begin
            $display("Test Case 6: Vector multiplication (row x column)");
            // Row vector (1x3) stored in first row of A
            test_a[0][0] = to_fixed(2.0); test_a[0][1] = to_fixed(-1.5); test_a[0][2] = to_fixed(3.0);
            test_a[1][0] = to_fixed(0.0); test_a[1][1] = to_fixed(0.0);  test_a[1][2] = to_fixed(0.0);
            test_a[2][0] = to_fixed(0.0); test_a[2][1] = to_fixed(0.0);  test_a[2][2] = to_fixed(0.0);
            test_a[3][0] = to_fixed(0.0); test_a[3][1] = to_fixed(0.0);  test_a[3][2] = to_fixed(0.0);
            
            // Column vector (3x1) stored in first column of B
            test_b[0][0] = to_fixed(1.0);  test_b[0][1] = to_fixed(0.0);
            test_b[1][0] = to_fixed(4.0);  test_b[1][1] = to_fixed(0.0);
            test_b[2][0] = to_fixed(-2.0); test_b[2][1] = to_fixed(0.0);
        end
    endtask
    
    // Test Case 7: Large values near overflow boundary
    task init_test_case_7;
        begin
            $display("Test Case 7: Large values near overflow");
            // Using values that will test the accumulator width
            test_a[0][0] = to_fixed(15.0);  test_a[0][1] = to_fixed(16.0);  test_a[0][2] = to_fixed(14.0);
            test_a[1][0] = to_fixed(13.0);  test_a[1][1] = to_fixed(15.0);  test_a[1][2] = to_fixed(12.0);
            test_a[2][0] = to_fixed(14.0);  test_a[2][1] = to_fixed(13.0);  test_a[2][2] = to_fixed(15.0);
            test_a[3][0] = to_fixed(16.0);  test_a[3][1] = to_fixed(14.0);  test_a[3][2] = to_fixed(13.0);
            
            test_b[0][0] = to_fixed(15.0); test_b[0][1] = to_fixed(14.0);
            test_b[1][0] = to_fixed(16.0); test_b[1][1] = to_fixed(15.0);
            test_b[2][0] = to_fixed(14.0); test_b[2][1] = to_fixed(16.0);
        end
    endtask
    
    // Test Case 8: Mixed positive/negative with fractions
    task init_test_case_8;
        begin
            $display("Test Case 8: Mixed positive/negative with fractions");
            test_a[0][0] = to_fixed(2.75);  test_a[0][1] = to_fixed(-1.25); test_a[0][2] = to_fixed(0.5);
            test_a[1][0] = to_fixed(-3.5);  test_a[1][1] = to_fixed(2.25);  test_a[1][2] = to_fixed(-0.75);
            test_a[2][0] = to_fixed(1.125); test_a[2][1] = to_fixed(-2.5);  test_a[2][2] = to_fixed(3.375);
            test_a[3][0] = to_fixed(-0.625);test_a[3][1] = to_fixed(1.875); test_a[3][2] = to_fixed(-1.5);
            
            test_b[0][0] = to_fixed(-1.5);  test_b[0][1] = to_fixed(2.25);
            test_b[1][0] = to_fixed(3.125); test_b[1][1] = to_fixed(-1.75);
            test_b[2][0] = to_fixed(-2.5);  test_b[2][1] = to_fixed(1.625);
        end
    endtask
    
    // Compute expected result
    task compute_expected;
        begin
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    temp_sum = 0;
                    for (k = 0; k < K; k = k + 1) begin
                        temp_sum = temp_sum + (test_a[i][k] * test_b[k][j]);
                    end
                    expected_c[i][j] = temp_sum[DATA_WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
                end
            end
        end
    endtask
    
    // Load matrix A into DUT
    task load_matrix_a;
        integer a_i, a_j;
        begin
            for (a_i = 0; a_i < M; a_i = a_i + 1) begin
                for (a_j = 0; a_j < K; a_j = a_j + 1) begin
                    @(posedge clk);
                    a_data = test_a[a_i][a_j];
                    a_row = a_i;
                    a_col = a_j;
                    a_valid = 1;
                end
            end
            @(posedge clk);
            a_valid = 0;
        end
    endtask
    
    // Load matrix B into DUT
    task load_matrix_b;
        integer b_i, b_j;
        begin
            for (b_i = 0; b_i < K; b_i = b_i + 1) begin
                for (b_j = 0; b_j < N; b_j = b_j + 1) begin
                    @(posedge clk);
                    b_data = test_b[b_i][b_j];
                    b_row = b_i;
                    b_col = b_j;
                    b_valid = 1;
                end
            end
            @(posedge clk);
            b_valid = 0;
        end
    endtask
    
    // Collect output matrix C
    task collect_result;
        begin
            while (!done) begin
                @(posedge clk);
                if (c_valid) begin
                    result_c[c_row][c_col] = c_data;
                    $display("Output C[%0d][%0d] = %f", c_row, c_col, from_fixed(c_data));
                end
            end
        end
    endtask
    
    // Compare results
    task check_results;
        reg test_passed;
        begin
            test_passed = 1;
            $display("\nComparing results:");
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    if (result_c[i][j] !== expected_c[i][j]) begin
                        $display("ERROR: C[%0d][%0d] = %f (expected %f)", 
                            i, j, from_fixed(result_c[i][j]), from_fixed(expected_c[i][j]));
                        test_passed = 0;
                    end else begin
                        $display("PASS: C[%0d][%0d] = %f", i, j, from_fixed(result_c[i][j]));
                    end
                end
            end
            if (test_passed)
                $display("Test PASSED!\n");
            else
                $display("Test FAILED!\n");
        end
    endtask
    
    // Run a complete test
    task run_test;
        begin
            // Reset
            @(posedge clk);
            rst_n = 0;
            start = 0;
            a_valid = 0;
            b_valid = 0;
            @(posedge clk);
            @(posedge clk);
            rst_n = 1;
            @(posedge clk);
            
            // Start operation
            start = 1;
            @(posedge clk);
            start = 0;
            
            // Load matrices in parallel
            fork
                load_matrix_a();
                load_matrix_b();
            join
            
            // Wait for computation and collect results
            collect_result();
            
            // Check results
            check_results();
        end
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("matrix_mult_tb.vcd");
        $dumpvars(0, matrix_mult_tb);
        
        // Initialize
        rst_n = 0;
        start = 0;
        a_valid = 0;
        b_valid = 0;
        
        #100;
        
        // Test Case 1
        init_test_case_1();
        compute_expected();
        run_test();
        
        #100;
        
        // Test Case 2
        init_test_case_2();
        compute_expected();
        run_test();
        
        #100;
        
        // Test Case 3
        init_test_case_3();
        compute_expected();
        run_test();
        
        #100;
        
        // Test Case 4: Square matrix with negative values
        init_test_case_4();
        compute_expected();
        run_test();
        
        #100;
        
        // Test Case 5: Single element matrices (1x1)
        init_test_case_5();
        compute_expected();
        run_test();
        
        #100;
        
        // Test Case 6: Vector multiplication (row x column)
        init_test_case_6();
        compute_expected();
        run_test();
        
        #100;
        
        // Test Case 7: Large values near overflow
        init_test_case_7();
        compute_expected();
        run_test();
        
        #100;
        
        // Test Case 8: Mixed positive/negative with fractions
        init_test_case_8();
        compute_expected();
        run_test();
        
        #100;
        $display("All tests completed!");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #1000000;
        $display("ERROR: Test timeout!");
        $finish;
    end

endmodule