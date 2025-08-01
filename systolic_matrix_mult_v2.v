`timescale 1ns / 1ps

// Processing Element (PE) module for systolic array
module PE_v2 #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire clear,
    
    input wire signed [DATA_WIDTH-1:0] a_in,
    input wire signed [DATA_WIDTH-1:0] b_in,
    
    output reg signed [DATA_WIDTH-1:0] a_out,
    output reg signed [DATA_WIDTH-1:0] b_out,
    output wire signed [DATA_WIDTH-1:0] c_out
);
    reg signed [2*DATA_WIDTH-1:0] accumulator;
    wire signed [2*DATA_WIDTH-1:0] product;
    
    assign product = a_in * b_in;
    assign c_out = accumulator[DATA_WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= 0;
            b_out <= 0;
            accumulator <= 0;
        end else begin
            if (clear) begin
                accumulator <= 0;
            end 
            if (enable) begin
                a_out <= a_in;
                b_out <= b_in;
                accumulator <= accumulator + product;
            end
        end
    end
endmodule

// Simplified systolic array implementation
module systolic_matrix_mult #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter M = 4,
    parameter N = 2,  
    parameter K = 3
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire signed [DATA_WIDTH-1:0] a_data,
    input wire [$clog2(M)-1:0] a_row,
    input wire [$clog2(K)-1:0] a_col,
    input wire a_valid,
    
    input wire signed [DATA_WIDTH-1:0] b_data,
    input wire [$clog2(K)-1:0] b_row,
    input wire [$clog2(N)-1:0] b_col,
    input wire b_valid,
    
    output reg signed [DATA_WIDTH-1:0] c_data,
    output reg [$clog2(M)-1:0] c_row,
    output reg [$clog2(N)-1:0] c_col,
    output reg c_valid,
    output reg done
);

    // Input matrices storage
    reg signed [DATA_WIDTH-1:0] mat_a [0:M-1][0:K-1];
    reg signed [DATA_WIDTH-1:0] mat_b [0:K-1][0:N-1];
    
    // Systolic array connections
    wire signed [DATA_WIDTH-1:0] a_h [0:M-1][0:N];
    wire signed [DATA_WIDTH-1:0] b_v [0:M][0:N-1];
    wire signed [DATA_WIDTH-1:0] c_results [0:M-1][0:N-1];
    
    // Control
    reg compute_enable;
    reg clear_accumulators;
    reg [7:0] cycle_count;
    
    // Generate PE array
    genvar i, j;
    generate
        for (i = 0; i < M; i = i + 1) begin : row
            for (j = 0; j < N; j = j + 1) begin : col
                PE_v2 #(.DATA_WIDTH(DATA_WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .enable(compute_enable),
                    .clear(clear_accumulators),
                    .a_in(a_h[i][j]),
                    .a_out(a_h[i][j+1]),
                    .b_in(b_v[i][j]),
                    .b_out(b_v[i+1][j]),
                    .c_out(c_results[i][j])
                );
            end
        end
    endgenerate
    
    // Input staging registers
    reg signed [DATA_WIDTH-1:0] a_feed [0:M-1];
    reg signed [DATA_WIDTH-1:0] b_feed [0:N-1];
    
    // Compute input values
    integer idx;
    always @(*) begin
        for (idx = 0; idx < M; idx = idx + 1) begin
            if (compute_enable && cycle_count >= idx && cycle_count - idx < K) begin
                a_feed[idx] = mat_a[idx][cycle_count - idx];
            end else begin
                a_feed[idx] = 0;
            end
        end
        
        for (idx = 0; idx < N; idx = idx + 1) begin
            if (compute_enable && cycle_count >= idx && cycle_count - idx < K) begin
                b_feed[idx] = mat_b[cycle_count - idx][idx];
            end else begin
                b_feed[idx] = 0;
            end
        end
    end
    
    // Connect to array
    generate
        for (i = 0; i < M; i = i + 1) begin : a_connect
            assign a_h[i][0] = a_feed[i];
        end
        
        for (j = 0; j < N; j = j + 1) begin : b_connect
            assign b_v[0][j] = b_feed[j];
        end
    endgenerate
    
    // State machine
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam OUTPUT = 2'b11;
    
    reg [1:0] state, next_state;
    reg [$clog2(M*K):0] a_load_count;
    reg [$clog2(K*N):0] b_load_count;
    
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
            IDLE: if (start) next_state = LOAD;
            LOAD: if (a_load_count == M*K && b_load_count == K*N) next_state = COMPUTE;
            COMPUTE: if (cycle_count == M + N + K - 1) next_state = OUTPUT;
            OUTPUT: if (c_row == M-1 && c_col == N-1 && c_valid) next_state = IDLE;
        endcase
    end
    
    // Matrix loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_load_count <= 0;
            b_load_count <= 0;
        end else if (state == IDLE) begin
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
    
    // Computation control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 0;
            compute_enable <= 0;
            clear_accumulators <= 0;
        end else begin
            clear_accumulators <= 0;
            
            case (state)
                IDLE, LOAD: begin
                    cycle_count <= 0;
                    compute_enable <= 0;
                    if (state == LOAD && next_state == COMPUTE) begin
                        clear_accumulators <= 1;
                    end
                end
                
                COMPUTE: begin
                    compute_enable <= 1;
                    if (cycle_count < M + N + K - 1 && compute_enable) begin
                        cycle_count <= cycle_count + 1;
                    end
                end
                
                default: begin
                    compute_enable <= 0;
                end
            endcase
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