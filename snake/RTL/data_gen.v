module data_gen #(  
    parameter CNT_MAX = 23'd2499_999, // 100ms count value  
    parameter DATA_MAX = 20'd999_999  // Maximum display value  
)(  
    input wire sys_clk,         // System clock, 25 MHz  
    input wire sys_rst_n,       // Reset signal, active low  
    input wire clear_signal,    // Clear signal  
    input wire start_signal,    // Start signal  

    output wire [15:0] data,    // Data to be displayed on the 7-segment display  
    output wire [5:0] point,    // Decimal point control, active high  
    output reg seg_en,          // 7-segment display enable signal, active high  
    output wire sign            // Sign bit, active high for negative sign  
);  

    // Internal signals and registers  
    reg [22:0] cnt_100ms;       // 100ms counter  
    reg cnt_flag;               // 100ms flag signal  
    reg [15:0] data_h;          // Hours data  
    reg [15:0] data_s;          // Seconds data  
    reg [15:0] data_ms;         // Milliseconds data  

    // Assignments  
    assign point = 6'b010_000;  // No decimal points displayed  
    assign sign = 1'b0;         // No negative sign  
    assign data = data_s;       // Display seconds data  
    wire en = start_signal;     // Enable signal  

    // 100ms counter  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            cnt_100ms <= 23'd0;  
        else if (cnt_100ms == CNT_MAX || clear_signal)  
            cnt_100ms <= 23'd0;  
        else if (en)  
            cnt_100ms <= cnt_100ms + 1'b1;  
    end  

    // 100ms flag signal  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            cnt_flag <= 1'b0;  
        else if (cnt_100ms == CNT_MAX - 1'b1 || clear_signal)  
            cnt_flag <= 1'b1;  
        else  
            cnt_flag <= 1'b0;  
    end  

    // Milliseconds counter  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            data_ms <= 16'd0;  
        else if ((data_ms == 9 && cnt_flag) || clear_signal)  
            data_ms <= 16'd0;  
        else if (cnt_flag)  
            data_ms <= data_ms + 1'b1;  
    end  

    // Seconds counter  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            data_s <= 16'd0;  
        else if (clear_signal)  
            data_s <= 16'd0;  
        else if (data_ms == 9 && cnt_flag)  
            data_s <= data_s + 1'b1;  
    end  

    // Hours counter  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            data_h <= 16'd0;  
        else if ((data_h == 9 && data_s == 59 && data_ms == 9 && cnt_flag) || clear_signal)  
            data_h <= 16'd0;  
        else if (data_s == 59 && cnt_flag)  
            data_h <= data_h + 1'b1;  
    end  

    // Enable signal for the 7-segment display  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            seg_en <= 1'b0;  
        else  
            seg_en <= 1'b1;  
    end  

endmodule