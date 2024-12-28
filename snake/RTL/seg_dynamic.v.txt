`timescale 1ns/1ns  

module seg_dynamic (  
    input wire sys_clk,         // System clock, 50 MHz  
    input wire sys_rst_n,       // Reset signal, active low  
    input wire [15:0] data,     // Data to be displayed on the 7-segment display  
    input wire [7:0] bcd_data,  // BCD code input  
    input wire [5:0] point,     // Decimal point control, active high  
    input wire seg_en,          // 7-segment display enable signal, active high  
    input wire sign,            // Sign bit, active high for negative sign  

    output reg [5:0] sel,       // Digit selection signal  
    output reg [7:0] seg        // Segment selection signal  
);  

    // Parameters  
    parameter CNT_MAX = 16'd49_999; // Refresh time counter max value  

    // Internal signals and registers  
    wire [3:0] unit, ten, hun, tho, t_tho, h_hun;  
    reg [23:0] data_reg;  
    reg [15:0] cnt_1ms;  
    reg flag_1ms;  
    reg [2:0] cnt_sel;  
    reg [5:0] sel_reg;  
    reg [3:0] data_disp;  
    reg dot_disp;  

    // Data register: Control the data to be displayed  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            data_reg <= 24'b0;  
        else if (h_hun || point[5])  
            data_reg <= {h_hun, t_tho, tho, hun, ten, unit};  
        else if ((t_tho || point[4]) && sign)  
            data_reg <= {4'd10, t_tho, tho, hun, ten, unit};  
        else if ((t_tho || point[4]) && !sign)  
            data_reg <= {4'd11, t_tho, tho, hun, ten, unit};  
        else if ((tho || point[3]) && sign)  
            data_reg <= {4'd11, 4'd10, tho, hun, ten, unit};  
        else if ((tho || point[3]) && !sign)  
            data_reg <= {4'd11, 4'd11, tho, hun, ten, unit};  
        else if ((hun || point[2]) && sign)  
            data_reg <= {4'd11, 4'd11, 4'd10, hun, ten, unit};  
        else if ((hun || point[2]) && !sign)  
            data_reg <= {4'd11, 4'd11, 4'd11, hun, ten, unit};  
        else if ((ten || point[1]) && sign)  
            data_reg <= {4'd11, 4'd11, 4'd11, 4'd10, ten, unit};  
        else if ((ten || point[1]) && !sign)  
            data_reg <= {4'd11, 4'd11, 4'd11, 4'd11, ten, unit};  
        else if ((unit || point[0]) && sign)  
            data_reg <= {4'd11, 4'd11, 4'd11, 4'd11, 4'd10, unit};  
        else  
            data_reg <= {4'd11, 4'd11, 4'd11, 4'd11, 4'd11, unit};  
    end  

    // Counter for 1ms timing  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            cnt_1ms <= 16'd0;  
        else if (cnt_1ms == CNT_MAX)  
            cnt_1ms <= 16'd0;  
        else  
            cnt_1ms <= cnt_1ms + 1'b1;  
    end  

    // 1ms flag  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            flag_1ms <= 1'b0;  
        else if (cnt_1ms == CNT_MAX - 1'b1)  
            flag_1ms <= 1'b1;  
        else  
            flag_1ms <= 1'b0;  
    end  

    // Digit selection counter  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            cnt_sel <= 3'd0;  
        else if (cnt_sel == 3'd5 && flag_1ms)  
            cnt_sel <= 3'd0;  
        else if (flag_1ms)  
            cnt_sel <= cnt_sel + 1'b1;  
    end  

    // Digit selection register  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            sel_reg <= 6'b000_000;  
        else if (cnt_sel == 3'd0 && flag_1ms)  
            sel_reg <= 6'b000_001;  
        else if (flag_1ms)  
            sel_reg <= sel_reg << 1;  
    end  

    // Data to be displayed on the current digit  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            data_disp <= 4'b0;  
        else if (seg_en && flag_1ms)  
            case (cnt_sel)  
                3'd0: data_disp <= data_reg[3:0];  
                3'd1: data_disp <= data_reg[7:4];  
                3'd2: data_disp <= data_reg[11:8];  
                3'd3: data_disp <= data_reg[15:12];  
                3'd4: data_disp <= data_reg[19:16];  
                3'd5: data_disp <= data_reg[23:20];  
                default: data_disp <= 4'b0;  
            endcase  
    end  

    // Decimal point control  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            dot_disp <= 1'b1;  
        else if (flag_1ms)  
            dot_disp <= ~point[cnt_sel];  
    end  

    // Segment selection signal  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            seg <= 8'b1111_1111;  
        else  
            case (data_disp)  
                4'd0: seg <= {dot_disp, 7'b100_0000};  
                4'd1: seg <= {dot_disp, 7'b111_1001};  
                4'd2: seg <= {dot_disp, 7'b010_0100};  
                4'd3: seg <= {dot_disp, 7'b011_0000};  
                4'd4: seg <= {dot_disp, 7'b001_1001};  
                4'd5: seg <= {dot_disp, 7'b001_0010};  
                4'd6: seg <= {dot_disp, 7'b000_0010};  
                4'd7: seg <= {dot_disp, 7'b111_1000};  
                4'd8: seg <= {dot_disp, 7'b000_0000};  
                4'd9: seg <= {dot_disp, 7'b001_0000};  
                4'd10: seg <= 8'b1011_1111; // Negative sign  
                4'd11: seg <= 8'b1111_1111; // No display  
                default: seg <= 8'b1100_0000;  
            endcase  
    end  

    // Assign digit selection signal  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n)  
            sel <= 6'b000_000;  
        else  
            sel <= sel_reg;  
    end  

    // Instantiate BCD converters  
    bcd_8421 bcd_8421_inst1 (  
        .sys_clk(sys_clk),  
        .sys_rst_n(sys_rst_n),  
        .data({5'd0, data}),  
        .unit(unit),  
        .ten(ten),  
        .hun(hun),  
        .tho(tho)  
    );  

    bcd_8421 bcd_8421_inst2 (  
        .sys_clk(sys_clk),  
        .sys_rst_n(sys_rst_n),  
        .data({12'd0, bcd_data}),  
        .unit(t_tho),  
        .ten(h_hun)  
    );  

endmodule