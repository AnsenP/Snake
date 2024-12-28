`timescale 1ns/1ns  

module seg_595_dynamic (  
    input wire sys_clk,         // System clock, 50 MHz  
    input wire sys_rst_n,       // Reset signal, active low  
    input wire [15:0] data,     // Data to be displayed on the 7-segment display  
    input wire [11:0] bcd_data, // BCD code input  
    input wire [5:0] point,     // Decimal point control, active high  
    input wire seg_en,          // 7-segment display enable signal, active high  
    input wire sign,            // Sign bit, active high for negative sign  

    output wire stcp,           // Storage register clock (STCP)  
    output wire shcp,           // Shift register clock (SHCP)  
    output wire ds,             // Serial data input (DS)  
    output wire oe              // Output enable signal (OE)  
);  

    // Internal signals  
    wire [5:0] sel;             // Digit selection signal  
    wire [7:0] seg;             // Segment selection signal  

    // Dynamic display control  
    seg_dynamic seg_dynamic_inst (  
        .sys_clk(sys_clk),  
        .sys_rst_n(sys_rst_n),  
        .data(data),  
        .bcd_data(bcd_data),  
        .point(point),  
        .seg_en(seg_en),  
        .sign(sign),  
        .sel(sel),  
        .seg(seg)  
    );  

    // 74HC595 control  
    hc595_ctrl hc595_ctrl_inst (  
        .sys_clk(sys_clk),  
        .sys_rst_n(sys_rst_n),  
        .sel(sel),  
        .seg(seg),  
        .stcp(stcp),  
        .shcp(shcp),  
        .ds(ds),  
        .oe(oe)  
    );  

endmodule  