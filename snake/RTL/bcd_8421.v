module bcd_8421 (  
    input wire sys_clk,         // System clock, 50 MHz  
    input wire sys_rst_n,       // Reset signal, active low  
    input wire [19:0] data,     // Input data to be converted  

    output reg [3:0] unit,      // Units place BCD code  
    output reg [3:0] ten,       // Tens place BCD code  
    output reg [3:0] hun,       // Hundreds place BCD code  
    output reg [3:0] tho,       // Thousands place BCD code  
    output reg [3:0] t_tho,     // Ten-thousands place BCD code  
    output reg [3:0] h_hun      // Hundred-thousands place BCD code  
);  

    // Internal signals and registers  
    reg [4:0] cnt_shift;        // Shift counter  
    reg [43:0] data_shift;      // Shift register for data  
    reg shift_flag;             // Shift operation flag  

    // Shift counter: Counts from 0 to 21  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            cnt_shift <= 5'd0;  
        else if ((cnt_shift == 5'd21) && shift_flag)  
            cnt_shift <= 5'd0;  
        else if (shift_flag)  
            cnt_shift <= cnt_shift + 1'b1;  
    end  

    // Shift register: Performs the BCD conversion  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            data_shift <= 44'b0;  
        else if (cnt_shift == 5'd0)  
            data_shift <= {24'b0, data};  
        else if ((cnt_shift <= 20) && !shift_flag) begin  
            data_shift[23:20] <= (data_shift[23:20] > 4) ? (data_shift[23:20] + 3) : data_shift[23:20];  
            data_shift[27:24] <= (data_shift[27:24] > 4) ? (data_shift[27:24] + 3) : data_shift[27:24];  
            data_shift[31:28] <= (data_shift[31:28] > 4) ? (data_shift[31:28] + 3) : data_shift[31:28];  
            data_shift[35:32] <= (data_shift[35:32] > 4) ? (data_shift[35:32] + 3) : data_shift[35:32];  
            data_shift[39:36] <= (data_shift[39:36] > 4) ? (data_shift[39:36] + 3) : data_shift[39:36];  
            data_shift[43:40] <= (data_shift[43:40] > 4) ? (data_shift[43:40] + 3) : data_shift[43:40];  
        end else if ((cnt_shift <= 20) && shift_flag)  
            data_shift <= data_shift << 1;  
    end  

    // Shift flag: Alternates between 0 and 1 to control the shift operation  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            shift_flag <= 1'b0;  
        else  
            shift_flag <= ~shift_flag;  
    end  

    // Assign BCD values after the shift operation is complete  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n) begin  
            unit <= 4'b0;  
            ten <= 4'b0;  
            hun <= 4'b0;  
            tho <= 4'b0;  
            t_tho <= 4'b0;  
            h_hun <= 4'b0;  
        end else if (cnt_shift == 5'd21) begin  
            unit <= data_shift[23:20];  
            ten <= data_shift[27:24];  
            hun <= data_shift[31:28];  
            tho <= data_shift[35:32];  
            t_tho <= data_shift[39:36];  
            h_hun <= data_shift[43:40];  
        end  
    end  

endmodule