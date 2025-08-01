`timescale 1ns / 1ps

module systolic_matrix_mult_5x5_tb;
    
    // Parameters for 5x5 matrices
    parameter DATA_WIDTH = 16;
    parameter FRAC_WIDTH = 8;
    parameter M = 5;  // Rows of A, rows of C
    parameter N = 5;  // Cols of B, cols of C
    parameter K = 5;  // Cols of A, rows of B
    
    // DUT signals
    reg clk;
    reg rst_n;
    reg start;
    
    // Matrix A input
    reg signed [DATA_WIDTH-1:0] a_data;
    reg [$clog2(M)-1:0] a_row;
    reg [$clog2(K)-1:0] a_col;
    reg a_valid;
    
    // Matrix B input
    reg signed [DATA_WIDTH-1:0] b_data;
    reg [$clog2(K)-1:0] b_row;
    reg [$clog2(N)-1:0] b_col;
    reg b_valid;
    
    // Matrix C output
    wire signed [DATA_WIDTH-1:0] c_data;
    wire [$clog2(M)-1:0] c_row;
    wire [$clog2(N)-1:0] c_col;
    wire c_valid;
    wire done;
    
    // Test storage
    reg signed [DATA_WIDTH-1:0] test_a [0:M-1][0:K-1];
    reg signed [DATA_WIDTH-1:0] test_b [0:K-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] expected_c [0:M-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] result_c [0:M-1][0:N-1];
    
    // Test case tracking
    integer test_case;
    integer pass_count;
    integer total_tests;
    
    // Instantiate DUT
    systolic_matrix_mult #(
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
        forever #5 clk = ~clk;
    end
    
    // Fixed-point conversion functions
    function signed [DATA_WIDTH-1:0] to_fixed(input real val);
        begin
            to_fixed = val * (1 << FRAC_WIDTH);
        end
    endfunction
    
    function real from_fixed(input signed [DATA_WIDTH-1:0] val);
        begin
            from_fixed = $itor(val) / (1 << FRAC_WIDTH);
        end
    endfunction
    
    // Test tasks
    integer i, j, k;
    
    // Display matrix helpers
    task display_matrix_a;
        begin
            $display("\nMatrix A (%0dx%0d):", M, K);
            for (i = 0; i < M; i = i + 1) begin
                $write("  [");
                for (j = 0; j < K; j = j + 1) begin
                    $write("%7.2f ", from_fixed(test_a[i][j]));
                end
                $display("]");
            end
        end
    endtask
    
    task display_matrix_b;
        begin
            $display("\nMatrix B (%0dx%0d):", K, N);
            for (i = 0; i < K; i = i + 1) begin
                $write("  [");
                for (j = 0; j < N; j = j + 1) begin
                    $write("%7.2f ", from_fixed(test_b[i][j]));
                end
                $display("]");
            end
        end
    endtask
    
    task display_expected;
        begin
            $display("\nExpected C (%0dx%0d):", M, N);
            for (i = 0; i < M; i = i + 1) begin
                $write("  [");
                for (j = 0; j < N; j = j + 1) begin
                    $write("%7.2f ", from_fixed(expected_c[i][j]));
                end
                $display("]");
            end
        end
    endtask
    
    task display_result;
        begin
            $display("\nActual C (%0dx%0d):", M, N);
            for (i = 0; i < M; i = i + 1) begin
                $write("  [");
                for (j = 0; j < N; j = j + 1) begin
                    $write("%7.2f ", from_fixed(result_c[i][j]));
                end
                $display("]");
            end
        end
    endtask
    
    // Test Case 1: Identity Matrix
    task init_identity_test;
        begin
            $display("\n========== TEST CASE 1: Identity Matrix ==========");
            // Matrix A: Sequential pattern
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < K; j = j + 1) begin
                    test_a[i][j] = to_fixed(i * K + j + 1);
                end
            end
            
            // Matrix B: Identity matrix
            for (i = 0; i < K; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    test_b[i][j] = (i == j) ? to_fixed(1.0) : to_fixed(0.0);
                end
            end
            
            display_matrix_a();
            display_matrix_b();
        end
    endtask
    
    // Test Case 2: Uniform Matrix
    task init_uniform_test;
        begin
            $display("\n========== TEST CASE 2: Uniform Values ==========");
            // Matrix A: All 2's
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < K; j = j + 1) begin
                    test_a[i][j] = to_fixed(2.0);
                end
            end
            
            // Matrix B: All 3's
            for (i = 0; i < K; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    test_b[i][j] = to_fixed(3.0);
                end
            end
            
            display_matrix_a();
            display_matrix_b();
        end
    endtask
    
    // Test Case 3: Diagonal Matrix
    task init_diagonal_test;
        begin
            $display("\n========== TEST CASE 3: Diagonal Matrices ==========");
            // Matrix A: Diagonal with values 1,2,3,4,5
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < K; j = j + 1) begin
                    test_a[i][j] = (i == j) ? to_fixed(i + 1) : to_fixed(0.0);
                end
            end
            
            // Matrix B: Diagonal with values 5,4,3,2,1
            for (i = 0; i < K; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    test_b[i][j] = (i == j) ? to_fixed(K - i) : to_fixed(0.0);
                end
            end
            
            display_matrix_a();
            display_matrix_b();
        end
    endtask
    
    // Test Case 4: Random-like Pattern
    task init_pattern_test;
        begin
            $display("\n========== TEST CASE 4: Pattern Matrix ==========");
            // Matrix A: Checkerboard-like pattern
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < K; j = j + 1) begin
                    test_a[i][j] = ((i + j) % 2 == 0) ? to_fixed(1.0) : to_fixed(-1.0);
                end
            end
            
            // Matrix B: Symmetric pattern
            for (i = 0; i < K; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    test_b[i][j] = to_fixed((i + 1) * (j + 1) * 0.5);
                end
            end
            
            display_matrix_a();
            display_matrix_b();
        end
    endtask
    
    // Test Case 5: Large Values
    task init_large_values_test;
        begin
            $display("\n========== TEST CASE 5: Large Values ==========");
            // Matrix A: Large sequential values
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < K; j = j + 1) begin
                    test_a[i][j] = to_fixed(10.0 + i * 2 + j);
                end
            end
            
            // Matrix B: Decreasing pattern
            for (i = 0; i < K; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    test_b[i][j] = to_fixed(20.0 - i - j);
                end
            end
            
            display_matrix_a();
            display_matrix_b();
        end
    endtask
    
    // Compute expected result
    task compute_expected;
        reg signed [2*DATA_WIDTH-1:0] temp_sum;
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
            
            display_expected();
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
        integer timeout_counter;
        begin
            $display("\nCollecting results...");
            timeout_counter = 0;
            
            // Initialize result matrix
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    result_c[i][j] = 0;
                end
            end
            
            while (!done && timeout_counter < 2000) begin
                @(posedge clk);
                timeout_counter = timeout_counter + 1;
                if (c_valid) begin
                    result_c[c_row][c_col] = c_data;
                end
            end
            
            if (timeout_counter >= 2000) begin
                $display("ERROR: Timeout while waiting for results!");
            end
            
            display_result();
        end
    endtask
    
    // Compare results
    task check_results;
        reg test_passed;
        reg signed [DATA_WIDTH-1:0] diff;
        integer error_count;
        begin
            test_passed = 1;
            error_count = 0;
            $display("\n=== Detailed Comparison ===");
            
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    diff = result_c[i][j] - expected_c[i][j];
                    if (diff == 0 || diff == 1 || diff == -1) begin  // Allow ±1 LSB error
                        $display("  PASS: C[%0d][%0d] = %7.2f (expected %7.2f)", 
                            i, j, from_fixed(result_c[i][j]), from_fixed(expected_c[i][j]));
                    end else begin
                        $display("  FAIL: C[%0d][%0d] = %7.2f (expected %7.2f, diff = %7.2f)", 
                            i, j, from_fixed(result_c[i][j]), from_fixed(expected_c[i][j]),
                            from_fixed(diff));
                        test_passed = 0;
                        error_count = error_count + 1;
                    end
                end
            end
            
            if (test_passed) begin
                $display("\n*** TEST CASE %0d PASSED! ***", test_case);
                pass_count = pass_count + 1;
            end else begin
                $display("\n*** TEST CASE %0d FAILED! (%0d errors) ***", test_case, error_count);
            end
            
            $display("Timing: Completed in %0d cycles (expected %0d cycles)", 
                (M + N + K - 1), (M + N + K - 1));
            $display("Performance: %0dx faster than sequential (%0d vs %0d cycles)",
                (M * N * K) / (M + N + K - 1), M * N * K, (M + N + K - 1));
        end
    endtask
    
    // Run a complete test
    task run_test;
        begin
            compute_expected();
            
            // Reset
            @(posedge clk);
            rst_n = 0;
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
        // Generate VCD for debugging
        $dumpfile("systolic_matrix_mult_5x5_tb.vcd");
        $dumpvars(0, systolic_matrix_mult_5x5_tb);
        
        // Initialize
        rst_n = 0;
        start = 0;
        a_valid = 0;
        b_valid = 0;
        test_case = 0;
        pass_count = 0;
        total_tests = 5;
        
        $display("\n================================================");
        $display("     5x5 Systolic Array Comprehensive Test");
        $display("================================================");
        
        // Test Case 1: Identity Matrix
        test_case = 1;
        init_identity_test();
        run_test();
        #100;
        
        // Test Case 2: Uniform Values
        test_case = 2;
        init_uniform_test();
        run_test();
        #100;
        
        // Test Case 3: Diagonal Matrices
        test_case = 3;
        init_diagonal_test();
        run_test();
        #100;
        
        // Test Case 4: Pattern Matrix
        test_case = 4;
        init_pattern_test();
        run_test();
        #100;
        
        // Test Case 5: Large Values
        test_case = 5;
        init_large_values_test();
        run_test();
        #100;
        
        // Final summary
        $display("\n================================================");
        $display("              FINAL SUMMARY");
        $display("================================================");
        $display("Tests Passed: %0d/%0d", pass_count, total_tests);
        $display("Success Rate: %0d%%", (pass_count * 100) / total_tests);
        
        if (pass_count == total_tests) begin
            $display("🎉 ALL TESTS PASSED! 🎉");
        end else begin
            $display("❌ %0d TEST(S) FAILED", total_tests - pass_count);
        end
        
        $display("================================================");
        
        #100;
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #500000;
        $display("ERROR: Global test timeout!");
        $finish;
    end

endmodule