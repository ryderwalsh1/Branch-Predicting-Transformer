module matrix_mult #(
    parameter DATA_WIDTH = 16,  // Fixed-point data width
    parameter FRAC_WIDTH = 8,   // Fractional bits
    parameter M = 64,           // Rows of A, rows of C
    parameter N = 64,           // Cols of B, cols of C  
    parameter K = 64            // Cols of A, rows of B
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Matrix A input (MxK)
    input wire signed [DATA_WIDTH-1:0] a_data,
    input wire [$clog2(M)-1:0] a_row,
    input wire [$clog2(K)-1:0] a_col,
    input wire a_valid,
    
    // Matrix B input (KxN)
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

    // Internal memory for matrices
    reg signed [DATA_WIDTH-1:0] mat_a [0:M-1][0:K-1];
    reg signed [DATA_WIDTH-1:0] mat_b [0:K-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] mat_c [0:M-1][0:N-1];
    
    // State machine
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam OUTPUT = 2'b11;
    
    reg [1:0] state, next_state;
    
    // Computation indices
    reg [$clog2(M)-1:0] comp_row;
    reg [$clog2(N)-1:0] comp_col;
    reg [$clog2(K)-1:0] comp_k;
    reg [$clog2(M)-1:0] out_row;
    reg [$clog2(N)-1:0] out_col;
    
    // Accumulator for dot product (extra bits for overflow)
    reg signed [2*DATA_WIDTH+$clog2(K)-1:0] accumulator;
    
    // Wire for final sum calculation
    wire signed [2*DATA_WIDTH+$clog2(K)-1:0] final_sum;
    assign final_sum = accumulator + (mat_a[comp_row][K-1] * mat_b[K-1][comp_col]);
    
    // Load counters
    reg [$clog2(M*K):0] a_load_count;
    reg [$clog2(K*N):0] b_load_count;
    
    // State machine
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
                if (comp_row == M-1 && comp_col == N-1 && comp_k == K-1)
                    next_state = OUTPUT;
            end
            
            OUTPUT: begin
                if (out_row == M-1 && out_col == N-1)
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
    
    // Matrix multiplication
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            comp_row <= 0;
            comp_col <= 0;
            comp_k <= 0;
            accumulator <= 0;
        end else begin
            if (state == COMPUTE) begin
                if (comp_k == 0) begin
                    // Start new dot product
                    accumulator <= mat_a[comp_row][0] * mat_b[0][comp_col];
                    comp_k <= 1;
                end else if (comp_k < K-1) begin
                    // Continue accumulating
                    accumulator <= accumulator + (mat_a[comp_row][comp_k] * mat_b[comp_k][comp_col]);
                    comp_k <= comp_k + 1;
                end else begin
                    // Final accumulation and store result
                    accumulator <= final_sum; // not strictly necessary, but good for consistency
                    // Scale back to original precision using the complete sum
                    mat_c[comp_row][comp_col] <= final_sum[DATA_WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
                    
                    // Move to next element
                    comp_k <= 0;
                    if (comp_col == N-1) begin
                        comp_col <= 0;
                        comp_row <= comp_row + 1;
                    end else begin
                        comp_col <= comp_col + 1;
                    end
                end
            end else if (state == IDLE) begin
                comp_row <= 0;
                comp_col <= 0;
                comp_k <= 0;
                accumulator <= 0;
            end
        end
    end
    
    // Output stage
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
                c_data <= mat_c[out_row][out_col];
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