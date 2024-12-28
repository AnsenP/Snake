// Top-Level Module for 7-Segment Display Control with 74HC595  
module top_seg_595 (  
    input wire sys_clk,        // System clock, frequency 50 MHz  
    input wire sys_rst_n,      // Reset signal, active low  
    input [7:0] bcd_data,      // Input score for the snake game  
    input wire clear_signal,   // Input clear signal  
    input wire start_signal,   // Input start signal  

    output wire stcp,          // Storage register clock (STCP)  
    output wire shcp,          // Shift register clock (SHCP)  
    output wire ds,            // Serial data input (DS)  
    output wire oe             // Output enable signal (OE)  
);  

    // Internal wires  
    wire [15:0] data;          // Data to be displayed on the 7-segment display  
    wire [5:0] point;          // Decimal point control, active high  
    wire seg_en;               // 7-segment display enable signal, active high  
    wire sign;                 // Sign bit, active high for negative sign  

    // Instantiate the data generation module  
    data_gen data_gen_inst (  
        .sys_clk(sys_clk),         // System clock, frequency 50 MHz  
        .sys_rst_n(sys_rst_n),     // Reset signal, active low  
        .clear_signal(clear_signal), // Input clear signal  
        .start_signal(start_signal), // Input start signal  
        .data(data),               // Data to be displayed on the 7-segment display  
        .point(point),             // Decimal point control, active high  
        .seg_en(seg_en),           // 7-segment display enable signal, active high  
        .sign(sign)                // Sign bit, active high for negative sign  
    );  

    // Instantiate the 7-segment display control module  
    seg_595_dynamic seg_595_dynamic_inst (  
        .sys_clk(sys_clk),         // System clock, frequency 50 MHz  
        .sys_rst_n(sys_rst_n),     // Reset signal, active low  
        .data(data),               // Data to be displayed on the 7-segment display  
        .bcd_data(bcd_data),       // Input score for the snake game  
        .point(point),             // Decimal point control, active high  
        .seg_en(seg_en),           // 7-segment display enable signal, active high  
        .sign(sign),               // Sign bit, active high for negative sign  

        .stcp(stcp),               // Storage register clock (STCP)  
        .shcp(shcp),               // Shift register clock (SHCP)  
        .ds(ds),                   // Serial data input (DS)  
        .oe(oe)                    // Output enable signal (OE)  
    );  

endmodule  