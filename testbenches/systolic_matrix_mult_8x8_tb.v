`timescale 1ns / 1ps

module systolic_matrix_mult_8x8_tb;
    
    // Parameters for 8x8 matrices
    parameter DATA_WIDTH = 16;
    parameter FRAC_WIDTH = 8;
    parameter M = 8;  // Rows of A, rows of C
    parameter N = 8;  // Cols of B, cols of C
    parameter K = 8;  // Cols of A, rows of B
    
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
    integer start_time, end_time;
    
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
    
    // Display matrix summary helpers (too large for full display)
    task display_matrix_a_summary;
        begin
            $display("\nMatrix A (%0dx%0d) - Corner elements:", M, K);
            $display("  Top-left:     [%7.2f  %7.2f  ...  %7.2f  %7.2f]", 
                from_fixed(test_a[0][0]), from_fixed(test_a[0][1]), 
                from_fixed(test_a[0][K-2]), from_fixed(test_a[0][K-1]));
            $display("  Bottom-right: [%7.2f  %7.2f  ...  %7.2f  %7.2f]", 
                from_fixed(test_a[M-2][0]), from_fixed(test_a[M-2][1]),
                from_fixed(test_a[M-1][K-2]), from_fixed(test_a[M-1][K-1]));
        end
    endtask
    
    task display_matrix_b_summary;
        begin
            $display("\nMatrix B (%0dx%0d) - Corner elements:", K, N);
            $display("  Top-left:     [%7.2f  %7.2f  ...  %7.2f  %7.2f]", 
                from_fixed(test_b[0][0]), from_fixed(test_b[0][1]), 
                from_fixed(test_b[0][N-2]), from_fixed(test_b[0][N-1]));
            $display("  Bottom-right: [%7.2f  %7.2f  ...  %7.2f  %7.2f]", 
                from_fixed(test_b[K-2][0]), from_fixed(test_b[K-2][1]),
                from_fixed(test_b[K-1][N-2]), from_fixed(test_b[K-1][N-1]));
        end
    endtask
    
    task display_expected_summary;
        begin
            $display("\nExpected C (%0dx%0d) - Corner elements:", M, N);
            $display("  Top-left:     [%7.2f  %7.2f  ...  %7.2f  %7.2f]", 
                from_fixed(expected_c[0][0]), from_fixed(expected_c[0][1]), 
                from_fixed(expected_c[0][N-2]), from_fixed(expected_c[0][N-1]));
            $display("  Bottom-right: [%7.2f  %7.2f  ...  %7.2f  %7.2f]", 
                from_fixed(expected_c[M-2][0]), from_fixed(expected_c[M-2][1]),
                from_fixed(expected_c[M-1][N-2]), from_fixed(expected_c[M-1][N-1]));
        end
    endtask
    
    task display_result_summary;
        begin
            $display("\nActual C (%0dx%0d) - Corner elements:", M, N);
            $display("  Top-left:     [%7.2f  %7.2f  ...  %7.2f  %7.2f]", 
                from_fixed(result_c[0][0]), from_fixed(result_c[0][1]), 
                from_fixed(result_c[0][N-2]), from_fixed(result_c[0][N-1]));
            $display("  Bottom-right: [%7.2f  %7.2f  ...  %7.2f  %7.2f]", 
                from_fixed(result_c[M-2][0]), from_fixed(result_c[M-2][1]),
                from_fixed(result_c[M-1][N-2]), from_fixed(result_c[M-1][N-1]));
        end
    endtask
    
    // Test Case 1: Identity Matrix Multiplication
    task init_identity_test;
        begin
            $display("\n========== TEST CASE 1: 8x8 Identity Matrix ==========");
            // Matrix A: Sequential pattern
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < K; j = j + 1) begin
                    test_a[i][j] = to_fixed(i + j + 1);
                end
            end
            
            // Matrix B: Identity matrix
            for (i = 0; i < K; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    test_b[i][j] = (i == j) ? to_fixed(1.0) : to_fixed(0.0);
                end
            end
            
            display_matrix_a_summary();
            display_matrix_b_summary();
        end
    endtask
    
    // Test Case 2: Symmetric Matrices
    task init_symmetric_test;
        begin
            $display("\n========== TEST CASE 2: 8x8 Symmetric Matrices ==========");
            // Matrix A: Symmetric pattern
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < K; j = j + 1) begin
                    test_a[i][j] = to_fixed(1.0 / (i + j + 1));
                end
            end
            
            // Matrix B: Symmetric pattern  
            for (i = 0; i < K; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    test_b[i][j] = to_fixed(1.0 / (i + j + 1));
                end
            end
            
            display_matrix_a_summary();
            display_matrix_b_summary();
        end
    endtask
    
    // Test Case 3: Stress Test with Mixed Values
    task init_stress_test;
        begin
            $display("\n========== TEST CASE 3: 8x8 Stress Test ==========");
            // Matrix A: Mixed positive/negative pattern
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < K; j = j + 1) begin
                    if ((i + j) % 3 == 0) begin
                        test_a[i][j] = to_fixed(3.5 - i * 0.5);
                    end else if ((i + j) % 3 == 1) begin
                        test_a[i][j] = to_fixed(-2.0 + j);
                    end else begin
                        test_a[i][j] = to_fixed(1.5 * i - j);
                    end
                end
            end
            
            // Matrix B: Complex pattern
            for (i = 0; i < K; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    test_b[i][j] = to_fixed((i - j) * 0.75 + 2.0);
                end
            end
            
            display_matrix_a_summary();
            display_matrix_b_summary();
        end
    endtask
    
    // Compute expected result
    task compute_expected;
        reg signed [2*DATA_WIDTH-1:0] temp_sum;
        begin
            $display("\nComputing expected results for 8x8 multiplication...");
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    temp_sum = 0;
                    for (k = 0; k < K; k = k + 1) begin
                        temp_sum = temp_sum + (test_a[i][k] * test_b[k][j]);
                    end
                    expected_c[i][j] = temp_sum[DATA_WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
                end
            end
            
            display_expected_summary();
        end
    endtask
    
    // Load matrix A into DUT
    task load_matrix_a;
        integer a_i, a_j;
        begin
            $display("Loading 8x8 Matrix A...");
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
            $display("Matrix A loaded successfully.");
        end
    endtask
    
    // Load matrix B into DUT
    task load_matrix_b;
        integer b_i, b_j;
        begin
            $display("Loading 8x8 Matrix B...");
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
            $display("Matrix B loaded successfully.");
        end
    endtask
    
    // Collect output matrix C
    task collect_result;
        integer timeout_counter;
        integer result_count;
        begin
            $display("Collecting 8x8 results...");
            timeout_counter = 0;
            result_count = 0;
            start_time = $time;
            
            // Initialize result matrix
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    result_c[i][j] = 0;
                end
            end
            
            while (!done && timeout_counter < 5000) begin
                @(posedge clk);
                timeout_counter = timeout_counter + 1;
                if (c_valid) begin
                    result_c[c_row][c_col] = c_data;
                    result_count = result_count + 1;
                    if (result_count % 16 == 0) begin
                        $display("  Collected %0d/64 results...", result_count);
                    end
                end
            end
            
            end_time = $time;
            
            if (timeout_counter >= 5000) begin
                $display("ERROR: Timeout while waiting for results!");
            end else begin
                $display("All 64 results collected successfully.");
            end
            
            display_result_summary();
        end
    endtask
    
    // Compare results with statistical summary
    task check_results;
        reg test_passed;
        reg signed [DATA_WIDTH-1:0] diff;
        integer error_count;
        integer total_elements;
        real max_error, avg_error, sum_error;
        begin
            test_passed = 1;
            error_count = 0;
            total_elements = M * N;
            max_error = 0.0;
            sum_error = 0.0;
            
            $display("\n=== Statistical Analysis ===");
            
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    diff = result_c[i][j] - expected_c[i][j];
                    sum_error = sum_error + (from_fixed(diff) < 0 ? -from_fixed(diff) : from_fixed(diff));
                    
                    if (from_fixed(diff) > max_error || -from_fixed(diff) > max_error) begin
                        max_error = (from_fixed(diff) > 0) ? from_fixed(diff) : -from_fixed(diff);
                    end
                    
                    if (diff == 0 || diff == 1 || diff == -1) begin  // Allow ±1 LSB error
                        // Pass - within tolerance
                    end else begin
                        if (error_count < 5) begin  // Show first 5 errors
                            $display("  ERROR: C[%0d][%0d] = %7.2f (expected %7.2f, diff = %7.2f)", 
                                i, j, from_fixed(result_c[i][j]), from_fixed(expected_c[i][j]),
                                from_fixed(diff));
                        end
                        test_passed = 0;
                        error_count = error_count + 1;
                    end
                end
            end
            
            avg_error = sum_error / total_elements;
            
            $display("Total Elements: %0d", total_elements);
            $display("Errors Found: %0d", error_count);
            $display("Error Rate: %0.2f%%", (error_count * 100.0) / total_elements);
            $display("Max Error: %7.4f", max_error);
            $display("Avg Error: %7.4f", avg_error);
            
            if (test_passed) begin
                $display("\n*** TEST CASE %0d PASSED! ***", test_case);
                pass_count = pass_count + 1;
            end else begin
                $display("\n*** TEST CASE %0d FAILED! (%0d errors) ***", test_case, error_count);
            end
            
            // Performance metrics
            $display("\n=== Performance Metrics ===");
            $display("Expected Cycles: %0d", (M + N + K - 1));
            $display("Sequential Cycles: %0d", M * N * K);
            $display("Speedup: %0.1fx", (M * N * K * 1.0) / (M + N + K - 1));
            $display("Simulation Time: %0d time units", (end_time - start_time));
            $display("Matrix Size: %0dx%0d (%0d elements)", M, N, M * N);
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
        // Generate VCD for debugging (commented out due to size)
        // $dumpfile("systolic_matrix_mult_8x8_tb.vcd");
        // $dumpvars(0, systolic_matrix_mult_8x8_tb);
        
        // Initialize
        rst_n = 0;
        start = 0;
        a_valid = 0;
        b_valid = 0;
        test_case = 0;
        pass_count = 0;
        total_tests = 3;
        
        $display("\n====================================================");
        $display("       8x8 Systolic Array Performance Test");
        $display("====================================================");
        $display("This test validates large-scale matrix multiplication");
        $display("Expected performance: 23x speedup vs sequential");
        $display("Matrix operations: 8x8 × 8x8 = 8x8 (512 MACs each)");
        $display("====================================================");
        
        // Test Case 1: Identity Matrix
        test_case = 1;
        init_identity_test();
        run_test();
        #200;
        
        // Test Case 2: Symmetric Matrices
        test_case = 2;
        init_symmetric_test();
        run_test();
        #200;
        
        // Test Case 3: Stress Test
        test_case = 3;
        init_stress_test();
        run_test();
        #200;
        
        // Final summary
        $display("\n====================================================");
        $display("                FINAL SUMMARY");
        $display("====================================================");
        $display("Tests Passed: %0d/%0d", pass_count, total_tests);
        $display("Success Rate: %0d%%", (pass_count * 100) / total_tests);
        
        if (pass_count == total_tests) begin
            $display("🎉 ALL 8x8 TESTS PASSED! 🎉");
            $display("Systolic array successfully handles large matrices!");
        end else begin
            $display("❌ %0d TEST(S) FAILED", total_tests - pass_count);
        end
        
        $display("Matrix Elements Processed: %0d", total_tests * M * N);
        $display("====================================================");
        
        #100;
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #2000000;  // Longer timeout for 8x8
        $display("ERROR: Global test timeout!");
        $finish;
    end

endmodule