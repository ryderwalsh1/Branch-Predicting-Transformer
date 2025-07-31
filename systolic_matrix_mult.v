`timescale 1ns / 1ps

// Processing Element (PE) module for systolic array
module PE #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire clear,  // Clear accumulator for new computation
    
    // Input from left (A) and top (B)
    input wire signed [DATA_WIDTH-1:0] a_in,
    input wire signed [DATA_WIDTH-1:0] b_in,
    
    // Output to right (A) and bottom (B)
    output reg signed [DATA_WIDTH-1:0] a_out,
    output reg signed [DATA_WIDTH-1:0] b_out,
    
    // Accumulated result
    output wire signed [DATA_WIDTH-1:0] c_out
);
    // Internal accumulator with extra bits for overflow
    reg signed [2*DATA_WIDTH-1:0] accumulator;
    wire signed [2*DATA_WIDTH-1:0] product;
    
    // Compute product
    assign product = a_in * b_in;
    
    // Output scaled result
    assign c_out = accumulator[DATA_WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= 0;
            b_out <= 0;
            accumulator <= 0;
        end else begin
            if (clear) begin
                accumulator <= 0;
                a_out <= 0;
                b_out <= 0;
            end else if (enable) begin
                // Pass data to neighbors with one cycle delay
                a_out <= a_in;
                b_out <= b_in;
                
                // Accumulate product
                accumulator <= accumulator + product;
            end
        end
    end
endmodule

// Systolic array matrix multiplier
module systolic_matrix_mult #(
    parameter DATA_WIDTH = 16,  // Fixed-point data width
    parameter FRAC_WIDTH = 8,   // Fractional bits
    parameter M = 4,            // Rows of A, rows of C
    parameter N = 4,            // Cols of B, cols of C  
    parameter K = 4             // Cols of A, rows of B
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Matrix A input (MxK) - same interface as original
    input wire signed [DATA_WIDTH-1:0] a_data,
    input wire [$clog2(M)-1:0] a_row,
    input wire [$clog2(K)-1:0] a_col,
    input wire a_valid,
    
    // Matrix B input (KxN) - same interface as original
    input wire signed [DATA_WIDTH-1:0] b_data,
    input wire [$clog2(K)-1:0] b_row,
    input wire [$clog2(N)-1:0] b_col,
    input wire b_valid,
    
    // Matrix C output (MxN)
    output reg signed [DATA_WIDTH-1:0] c_data,
    output reg [$clog2(M)-1:0] c_row,
    output reg [$clog2(N)-1:0] c_col,
    output reg c_valid,
    output reg done
);

    // Internal memory for input matrices
    reg signed [DATA_WIDTH-1:0] mat_a [0:M-1][0:K-1];
    reg signed [DATA_WIDTH-1:0] mat_b [0:K-1][0:N-1];
    
    // Systolic array connections
    wire signed [DATA_WIDTH-1:0] a_connections [0:M-1][0:N];  // Horizontal A connections
    wire signed [DATA_WIDTH-1:0] b_connections [0:M][0:N-1];  // Vertical B connections
    wire signed [DATA_WIDTH-1:0] c_results [0:M-1][0:N-1];    // C outputs from each PE
    
    // Control signals
    reg compute_enable;
    reg clear_accumulators;
    reg [$clog2(M+N+K):0] cycle_count;
    
    // Generate the systolic array
    genvar i, j;
    generate
        for (i = 0; i < M; i = i + 1) begin : row_gen
            for (j = 0; j < N; j = j + 1) begin : col_gen
                PE #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .FRAC_WIDTH(FRAC_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .enable(compute_enable),
                    .clear(clear_accumulators),
                    
                    // Connect A from left
                    .a_in(a_connections[i][j]),
                    .a_out(a_connections[i][j+1]),
                    
                    // Connect B from top
                    .b_in(b_connections[i][j]),
                    .b_out(b_connections[i+1][j]),
                    
                    // Result output
                    .c_out(c_results[i][j])
                );
            end
        end
    endgenerate
    
    // Connect inputs to array edges with proper skewing
    // A enters from the left with row i delayed by i cycles
    // B enters from the top with column j delayed by j cycles
    generate
        for (i = 0; i < M; i = i + 1) begin : a_edge_gen
            reg signed [DATA_WIDTH-1:0] a_delay_line [0:M-1];
            integer k;
            
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (k = 0; k < M; k = k + 1) begin
                        a_delay_line[k] <= 0;
                    end
                end else if (compute_enable) begin
                    // Shift delay line
                    for (k = M-1; k > 0; k = k - 1) begin
                        a_delay_line[k] <= a_delay_line[k-1];
                    end
                    
                    // Input new data based on cycle count
                    if (cycle_count >= i && cycle_count < K + i) begin
                        a_delay_line[0] <= mat_a[i][cycle_count - i];
                    end else begin
                        a_delay_line[0] <= 0;
                    end
                end
            end
            
            // Connect to array - data already has appropriate delay
            assign a_connections[i][0] = a_delay_line[0];
        end
        
        for (j = 0; j < N; j = j + 1) begin : b_edge_gen
            reg signed [DATA_WIDTH-1:0] b_delay_line [0:N-1];
            integer k;
            
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (k = 0; k < N; k = k + 1) begin
                        b_delay_line[k] <= 0;
                    end
                end else if (compute_enable) begin
                    // Shift delay line
                    for (k = N-1; k > 0; k = k - 1) begin
                        b_delay_line[k] <= b_delay_line[k-1];
                    end
                    
                    // Input new data based on cycle count
                    if (cycle_count >= j && cycle_count < K + j) begin
                        b_delay_line[0] <= mat_b[cycle_count - j][j];
                    end else begin
                        b_delay_line[0] <= 0;
                    end
                end
            end
            
            // Connect to array - data already has appropriate delay
            assign b_connections[0][j] = b_delay_line[0];
        end
    endgenerate
    
    // State machine
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam OUTPUT = 2'b11;
    
    reg [1:0] state, next_state;
    
    // Load counters
    reg [$clog2(M*K):0] a_load_count;
    reg [$clog2(K*N):0] b_load_count;
    
    // State transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            
            LOAD: begin
                if (a_load_count == M*K && b_load_count == K*N) 
                    next_state = COMPUTE;
            end
            
            COMPUTE: begin
                // Need M+N+K-1 cycles for all data to flow through and compute
                if (cycle_count == M + N + K - 1)
                    next_state = OUTPUT;
            end
            
            OUTPUT: begin
                if (c_row == M-1 && c_col == N-1 && c_valid)
                    next_state = IDLE;
            end
        endcase
    end
    
    // Matrix loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_load_count <= 0;
            b_load_count <= 0;
        end else begin
            if (state == IDLE) begin
                a_load_count <= 0;
                b_load_count <= 0;
            end else if (state == LOAD) begin
                if (a_valid && a_load_count < M*K) begin
                    mat_a[a_row][a_col] <= a_data;
                    a_load_count <= a_load_count + 1;
                end
                if (b_valid && b_load_count < K*N) begin
                    mat_b[b_row][b_col] <= b_data;
                    b_load_count <= b_load_count + 1;
                end
            end
        end
    end
    
    // Computation control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 0;
            compute_enable <= 0;
            clear_accumulators <= 0;
        end else begin
            clear_accumulators <= 0;
            
            if (state == IDLE || state == LOAD) begin
                cycle_count <= 0;
                compute_enable <= 0;
                if (state == LOAD && a_load_count == M*K && b_load_count == K*N) begin
                    clear_accumulators <= 1;  // Clear accumulators before computation
                end
            end else if (state == COMPUTE) begin
                compute_enable <= 1;
                if (cycle_count < M + N + K - 1) begin
                    cycle_count <= cycle_count + 1;
                end
            end else begin
                compute_enable <= 0;
            end
        end
    end
    
    // Output stage
    reg [$clog2(M)-1:0] out_row;
    reg [$clog2(N)-1:0] out_col;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_row <= 0;
            out_col <= 0;
            c_data <= 0;
            c_row <= 0;
            c_col <= 0;
            c_valid <= 0;
            done <= 0;
        end else begin
            c_valid <= 0;
            done <= 0;
            
            if (state == OUTPUT) begin
                // Output results from the systolic array
                c_data <= c_results[out_row][out_col];
                c_row <= out_row;
                c_col <= out_col;
                c_valid <= 1;
                
                if (out_col == N-1) begin
                    out_col <= 0;
                    if (out_row == M-1) begin
                        out_row <= 0;
                        done <= 1;
                    end else begin
                        out_row <= out_row + 1;
                    end
                end else begin
                    out_col <= out_col + 1;
                end
            end else if (state == IDLE) begin
                out_row <= 0;
                out_col <= 0;
            end
        end
    end

endmodule