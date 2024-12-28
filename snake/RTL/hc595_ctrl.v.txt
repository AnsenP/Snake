`timescale 1ns/1ns  

module hc595_ctrl (  
    input wire sys_clk,         // System clock, 50 MHz  
    input wire sys_rst_n,       // Reset signal, active low  
    input wire [5:0] sel,       // Digit selection signal  
    input wire [7:0] seg,       // Segment selection signal  

    output reg stcp,            // Storage register clock  
    output reg shcp,            // Shift register clock  
    output reg ds,              // Serial data input  
    output wire oe              // Output enable signal, active low  
);  

    // Internal registers  
    reg [1:0] cnt_4;            // Frequency division counter  
    reg [3:0] cnt_bit;          // Bit counter  

    // Internal wires  
    wire [13:0] data;           // Data to be shifted into the 74HC595  

    // Concatenate segment and digit selection signals  
    assign data = {seg[0], seg[1], seg[2], seg[3], seg[4], seg[5], seg[6], seg[7], sel};  

    // Output enable signal (active low)  
    assign oe = ~sys_rst_n;  

    // Frequency division counter: Cycles from 0 to 3  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            cnt_4 <= 2'd0;  
        else if (cnt_4 == 2'd3)  
            cnt_4 <= 2'd0;  
        else  
            cnt_4 <= cnt_4 + 1'b1;  
    end  

    // Bit counter: Advances on every 4 cycles of `cnt_4`  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            cnt_bit <= 4'd0;  
        else if (cnt_4 == 2'd3 && cnt_bit == 4'd13)  
            cnt_bit <= 4'd0;  
        else if (cnt_4 == 2'd3)  
            cnt_bit <= cnt_bit + 1'b1;  
        else  
            cnt_bit <= cnt_bit;  
    end  

    // Generate `stcp` signal: High after all 14 bits are shifted in  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            stcp <= 1'b0;  
        else if (cnt_bit == 4'd13 && cnt_4 == 2'd3)  
            stcp <= 1'b1;  
        else  
            stcp <= 1'b0;  
    end  

    // Generate `shcp` signal: Clock for the shift register  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            shcp <= 1'b0;  
        else if (cnt_4 >= 2'd2)  
            shcp <= 1'b1;  
        else  
            shcp <= 1'b0;  
    end  

    // Generate `ds` signal: Serial data input to the shift register  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            ds <= 1'b0;  
        else if (cnt_4 == 2'd0)  
            ds <= data[cnt_bit];  
        else  
            ds <= ds;  
    end  

endmodule