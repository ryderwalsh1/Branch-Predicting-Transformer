`timescale 1ns / 1ps

module systolic_debug;
    parameter DATA_WIDTH = 16;
    parameter FRAC_WIDTH = 8;
    
    // Simple 2x2 * 2x2 test
    reg clk;
    reg rst_n;
    reg enable;
    reg clear;
    
    // Test data
    reg signed [DATA_WIDTH-1:0] a0, a1, b0, b1;
    wire signed [DATA_WIDTH-1:0] c00, c01, c10, c11;
    
    // Internal connections
    wire signed [DATA_WIDTH-1:0] a_h [0:1][0:2];  // horizontal
    wire signed [DATA_WIDTH-1:0] b_v [0:2][0:1];  // vertical
    
    // 2x2 PE array
    PE pe00(.clk(clk), .rst_n(rst_n), .enable(enable), .clear(clear),
            .a_in(a_h[0][0]), .b_in(b_v[0][0]), 
            .a_out(a_h[0][1]), .b_out(b_v[1][0]), .c_out(c00));
            
    PE pe01(.clk(clk), .rst_n(rst_n), .enable(enable), .clear(clear),
            .a_in(a_h[0][1]), .b_in(b_v[0][1]), 
            .a_out(a_h[0][2]), .b_out(b_v[1][1]), .c_out(c01));
            
    PE pe10(.clk(clk), .rst_n(rst_n), .enable(enable), .clear(clear),
            .a_in(a_h[1][0]), .b_in(b_v[1][0]), 
            .a_out(a_h[1][1]), .b_out(b_v[2][0]), .c_out(c10));
            
    PE pe11(.clk(clk), .rst_n(rst_n), .enable(enable), .clear(clear),
            .a_in(a_h[1][1]), .b_in(b_v[1][1]), 
            .a_out(a_h[1][2]), .b_out(b_v[2][1]), .c_out(c11));
    
    // Input staging
    reg signed [DATA_WIDTH-1:0] a_stage [0:1];
    reg signed [DATA_WIDTH-1:0] b_stage [0:1];
    
    assign a_h[0][0] = a_stage[0];
    assign a_h[1][0] = a_stage[1];
    assign b_v[0][0] = b_stage[0];
    assign b_v[0][1] = b_stage[1];
    
    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test
    initial begin
        $dumpfile("systolic_debug.vcd");
        $dumpvars(0, systolic_debug);
        
        // Init
        rst_n = 0;
        enable = 0;
        clear = 0;
        a_stage[0] = 0; a_stage[1] = 0;
        b_stage[0] = 0; b_stage[1] = 0;
        
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Clear accumulators
        clear = 1;
        @(posedge clk);
        clear = 0;
        
        // Test: [[1,2],[3,4]] * [[1,0],[0,1]] = [[1,2],[3,4]]
        enable = 1;
        
        // Cycle 0: a[0][0]=1, b[0][0]=1
        a_stage[0] = 16'h0100; // 1.0
        a_stage[1] = 16'h0000;
        b_stage[0] = 16'h0100; // 1.0
        b_stage[1] = 16'h0000;
        @(posedge clk);
        
        // Cycle 1: a[0][1]=2, b[1][0]=0, a[1][0]=3, b[0][1]=0
        a_stage[0] = 16'h0200; // 2.0
        a_stage[1] = 16'h0300; // 3.0
        b_stage[0] = 16'h0000; // 0.0
        b_stage[1] = 16'h0000; // 0.0
        @(posedge clk);
        
        // Cycle 2: a[1][1]=4, b[1][1]=1
        a_stage[0] = 16'h0000;
        a_stage[1] = 16'h0400; // 4.0
        b_stage[0] = 16'h0000;
        b_stage[1] = 16'h0100; // 1.0
        @(posedge clk);
        
        // Extra cycles for propagation
        a_stage[0] = 16'h0000;
        a_stage[1] = 16'h0000;
        b_stage[0] = 16'h0000;
        b_stage[1] = 16'h0000;
        @(posedge clk);
        @(posedge clk);
        
        enable = 0;
        
        // Check results
        $display("Results:");
        $display("C[0][0] = %d (expect 256=1.0)", c00);
        $display("C[0][1] = %d (expect 512=2.0)", c01);
        $display("C[1][0] = %d (expect 768=3.0)", c10);
        $display("C[1][1] = %d (expect 1024=4.0)", c11);
        
        #50;
        $finish;
    end
endmodule