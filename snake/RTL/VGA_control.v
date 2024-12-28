// VGA Control Module  
// Displays the following:  
// 1. Our group 24 designated start page screen at the start.  
// 2. "Level" screen to choose three levels.  
// 3. Snake body, food, and walls during gameplay, with appropriate colors based on the scanned pixel.  
// 4. Score display at the end of the game, rendering Arabic numerals on the VGA screen.   

module VGA_control (  
    input clk,                  // Pixel clock (25 MHz)  
    input rst_n,                // System reset signal (active low)  

    input [1:0] snake_show,     // Current scanned part: 00 = None, 01 = Head, 10 = Body, 11 = Wall  
    input [1:0] game_status,    // Game states: 00 = Restart, 01 = Start, 10 = Play, 11 = Die  
    input [11:0] bcd_data,      // Current score in BCD format  
    input [11:0] bcd_data_best, // Best score in BCD format  
    input [5:0] apple_x,        // X-coordinate of the apple  
    input [4:0] apple_y,        // Y-coordinate of the apple  
    input [1:0] fact_status,    // Additional status input  

    output [9:0] pos_x,         // X-coordinate of the scanned pixel (0-640)  
    output [9:0] pos_y,         // Y-coordinate of the scanned pixel (0-480)  

    input [3:0] body_status,    // Snake body status  
    output reg vga_hs,          // Horizontal sync signal  
    output reg vga_vs,          // Vertical sync signal  
    output reg [23:0] vga_rgb,  // RGB output to ADV7123  
    output vga_blank_n          // Blanking signal  
);  

    // Game states  
    localparam RESTART = 2'b00; // Game restart  
    localparam START   = 2'b01; // Game start  
    localparam PLAY    = 2'b10; // Game in progress  
    localparam DIE     = 2'b11; // Game over  

    // Snake parts  
    localparam NONE = 2'b00;  
    localparam HEAD = 2'b01;  
    localparam BODY = 2'b10;  
    localparam WALL = 2'b11;  

    // Colors (24-bit RGB)  
    localparam RED        = 24'hF80000; // Red  
    localparam DEEP_GREEN = 24'h00FF00; // Deep Green  
    localparam GREEN      = 24'hFF9933; // Green  
    localparam BLUE       = 24'h082460; // Blue  
    localparam YELLOW     = 24'hF8FCE0; // Yellow  
    localparam PINK       = 24'hFFC8B0; // Pink  
    localparam WHITE      = 24'hFFFFFF; // White  
    localparam BLACK      = 24'h000000; // Black  
    localparam SALMON     = 24'h986818; // Wall  
    localparam SEASHELL   = 24'h8800F8; // Purple  
    localparam SEASHELL2  = 24'hF8D400; // Gold  
    localparam SEASHELL3  = 24'h808000; // Olive Green  
    localparam SEASHELL4  = 24'h898989; // Gray  
    localparam SEASHELL5  = 24'h890089; // Purple  
    localparam SEASHELL6  = 24'h208989; // Light Blue  
    localparam SEASHELL7  = 24'h581033; // Dark Red  
    localparam SEASHELL8  = 24'hF0E4BB; // Beige  

    // Character display coordinates and data  
    wire [9:0] char_x;          // Character X-coordinate  
    wire [9:0] char_y;          // Character Y-coordinate  
    reg [255:0] char [31:0];    // Character data (width = 160, height = 32)  

    wire [9:0] char_xx;         // Character X-coordinate (alternative)  
    wire [9:0] char_yx;         // Character Y-coordinate (alternative)  
    reg [127:0] charx [31:0];   // Character data (width = 128, height = 32)  

    wire [9:0] char_xx2;        // Character X-coordinate (alternative 2)  
    wire [9:0] char_yx2;        // Character Y-coordinate (alternative 2)  
    reg [127:0] charx2 [31:0];  // Character data (width = 128, height = 32)  

    // VGA timing parameters for 640x480 @ 60Hz  
    parameter HS_A = 96;        // Horizontal sync pulse width  
    parameter HS_B = 48;        // Back porch  
    parameter HS_C = 640;       // Active video  
    parameter HS_D = 16;        // Front porch  
    parameter HS_E = 800;       // Total line width  

    parameter VS_A = 2;         // Vertical sync pulse width  
    parameter VS_B = 33;        // Back porch  
    parameter VS_C = 480;       // Active video  
    parameter VS_D = 10;        // Front porch  
    parameter VS_E = 525;       // Total frame height  

    parameter HS_WIDTH = 10;    // Horizontal counter width  
    parameter VS_WIDTH = 10;    // Vertical counter width  

    // Screen and block dimensions  
    localparam SIDE_W = 11'd16; // Screen border width  
    localparam BLOCK_W = 11'd16; // Block width  

    // Image dimensions  
    parameter height = 109;     // Image height  
    parameter width  = 145;     // Image width  

    // Character dimensions  
    parameter CHAR_W = 160;     // Character width  
    parameter CHAR_H = 32;      // Character height  

    // Counters and addresses  
    reg [HS_WIDTH-1:0] cnt_hs;  // Horizontal counter  
    reg [VS_WIDTH-1:0] cnt_vs;  // Vertical counter  
    reg [27:0] cnt;             // General-purpose counter  
    reg [27:0] cnt_clk;         // Clock counter  
    reg [13:0] cnt_rom_address; // ROM address counter  
    reg [11:0] addr_h;          // Horizontal address  
    reg [11:0] addr_v;          // Vertical address  

    // Enable signals  
    wire en_hs;                 // Horizontal enable  
    wire en_vs;                 // Vertical enable  
    wire en;                    // VGA active display enable  

    // Flags  
    wire flag_clear_rom_address; // ROM address counter clear flag  
    wire flag_clear_word_address; // Word address counter clear flag  
    wire flag_begin_h;           // Image row display enable flag  
    wire flag_begin_v;           // Image column display enable flag  
    wire picture_flag_enable;    // Image active display area flag  

    // ROM and word data  
    wire [15:0] rom_data;       // Picture data  
    wire word_data;             // Character data  
    wire [23:0] rom_data_RGB;   // RGB data from ROM  

    // Assign RGB data from ROM  
    assign rom_data_RGB = {rom_data[15:11], 3'd0, rom_data[10:5], 2'd0, rom_data[4:0], 3'd0}; 
	
	    // Horizontal Counter Implementation  
    always @(posedge clk or negedge rst_n) begin  
        if (!rst_n)  
            cnt_hs <= 0;  
        else if (cnt_hs < HS_E - 1)  
            cnt_hs <= cnt_hs + 1'b1;  
        else  
            cnt_hs <= 0;  
    end  

    // Vertical Counter Implementation  
    always @(posedge clk or negedge rst_n) begin  
        if (!rst_n)  
            cnt_vs <= 0;  
        else if (cnt_hs == HS_E - 1) begin  
            if (cnt_vs < VS_E - 1)  
                cnt_vs <= cnt_vs + 1'b1;  
            else  
                cnt_vs <= 0;  
        end  
    end  

    // Horizontal Sync Signal Generation  
    always @(posedge clk or negedge rst_n) begin  
        if (!rst_n)  
            vga_hs <= 1'b1;  
        else  
            vga_hs <= (cnt_hs < HS_A - 1) ? 1'b0 : 1'b1; // Low during sync pulse  
    end  

    // Vertical Sync Signal Generation  
    always @(posedge clk or negedge rst_n) begin  
        if (!rst_n)  
            vga_vs <= 1'b1;  
        else  
            vga_vs <= (cnt_vs < VS_A - 1) ? 1'b0 : 1'b1; // Low during sync pulse  
    end  

    // Enable Signals for Active Display Area  
    assign en_hs = (cnt_hs > HS_A + HS_B - 1) && (cnt_hs < HS_E - HS_D);  
    assign en_vs = (cnt_vs > VS_A + VS_B - 1) && (cnt_vs < VS_E - VS_D);  
    assign en = en_hs && en_vs;  
    assign vga_blank_n = en;  

    // Pixel Coordinates  
    assign pos_x = en ? (cnt_hs - (HS_A + HS_B - 1'b1)) : 0;  
    assign pos_y = en ? (cnt_vs - (VS_A + VS_B - 1'b1)) : 0;  

    // Game Restart Logic  
    always @(posedge clk or negedge rst_n) begin  
        if (!rst_n) begin  
            cnt_clk <= 0;  
            cnt <= 0;  
        end else if (game_status == RESTART) begin  
            cnt <= 0;  
            if (cnt_clk < 150_000_000) begin // 6 seconds delay (25 MHz clock)  
                cnt_clk <= cnt_clk + 1;  
                if (cnt_clk < 100_000_000) begin  
                    if (picture_flag_enable) // Display picture if within valid area  
                        vga_rgb <= rom_data_RGB;  
                    else  
                        vga_rgb <= 24'd0; // Black background  
                end else begin  
                    // Display "Record" text  
                    if (pos_x[9:4] >= 5 && pos_x[9:4] < 13 && pos_y[9:4] >= 4 && pos_y[9:4] < 6 &&  
                        charx[char_yx][127 - char_xx] == 1'b1) begin  
                        vga_rgb <= Seashell8; // Text color  
                    end else begin
					  if(pos_x[9:4] >= 0 && pos_x[9:4] < 15 )begin
						case (bcd_data_best[11:8])
							4'd0:begin
								if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
									vga_rgb = 24'hFFA500;
							else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
							else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
							else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
							else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
							else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
							else
										 vga_rgb = BLACK;
							end
						4'd1:begin
							if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
							else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
					else
										  vga_rgb = BLACK;

				end
						4'd2:begin
					if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end
						4'd3:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end
						4'd4:begin
						 if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end
						4'd5:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
						  end

						4'd6:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end
						4'd7:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end
						4'd8:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end
						4'd9:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end 
				default: 
								 vga_rgb = BLACK;
			endcase
			end
			else if(pos_x[9:4] >= 15 && pos_x[9:4] < 25)begin
			case (bcd_data_best[7:4])
					 4'd0:begin
				if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						else
										 vga_rgb = BLACK;
						  end
					 4'd1:begin
						  if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										 vga_rgb = BLACK;
			
					end
					 4'd2:begin
				if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										 vga_rgb = BLACK;
					end
					 4'd3:begin
			if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
									 vga_rgb = 24'hFFA500;
					 else
									vga_rgb = BLACK;	
					end
					 4'd4:begin
			
					 if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
									 vga_rgb = 24'hFFA500;
					 else
									vga_rgb = BLACK;	
					end
					 4'd5:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
						  end
					 4'd6:begin
				if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										 vga_rgb = BLACK;
					end
					 4'd7:begin
				if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										 vga_rgb = BLACK;
					end
					 4'd8:begin
				if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										 vga_rgb = BLACK;
					end
					 4'd9:begin
				if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_x[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										 vga_rgb = BLACK;
					end 
					default: 
										 vga_rgb = BLACK;
				endcase
		end
		else begin
		case (bcd_data_best[3:0])
					 4'd0:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
						  end
					 4'd1:begin
						  if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd2:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd3:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd4:begin
						  if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd5:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
						  end
					 4'd6:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd7:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd8:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd9:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end 
					default: 
										 vga_rgb = BLACK;
				   endcase
				    end
					end
				end
				end
				
				else if (cnt_clk >= 150_000_000) begin  
    // Display "LEVEL" text  
    if (pos_x[9:4] >= 12 && pos_x[9:4] < 28 && pos_y[9:4] >= 6 && pos_y[9:4] < 8 &&  
        char[char_y][255 - char_x] == 1'b1) begin  
        vga_rgb <= Seashell8; // Text color for "Select Difficulty"  
    end  
    // Display "Easy" green block  
    else if (is_easy_block(pos_x, pos_y)) begin  
        vga_rgb <= DEEP_GREEN;  
    end  
    // Display "Medium" blue block  
    else if (is_medium_block(pos_x, pos_y)) begin  
        vga_rgb <= BLUE;  
    end  
    // Display "Hard" red block  
    else if (is_hard_block(pos_x, pos_y)) begin  
        vga_rgb <= RED;  
    end  
    // Display picture if within valid area  
    else if (picture_flag_enable) begin  
        vga_rgb <= rom_data_RGB;  
    end  
    // Default background color  
    else begin  
        vga_rgb <= BLACK;  
    end  
end  

// Helper Functions for Difficulty Blocks  
function is_easy_block(input [9:0] x, input [9:0] y);  
    begin  
        is_easy_block = (x[9:4] >= 17 && x[9:4] < 18 && y[9:4] >= 10 && y[9:4] < 11);  
    end  
endfunction  

function is_medium_block(input [9:0] x, input [9:0] y);  
    begin  
        is_medium_block = (x[9:4] >= 19 && x[9:4] < 20 && y[9:4] >= 10 && y[9:4] < 11);  
    end  
endfunction  

function is_hard_block(input [9:0] x, input [9:0] y);  
    begin  
        is_hard_block = (x[9:4] >= 21 && x[9:4] < 22 && y[9:4] >= 10 && y[9:4] < 11);  
    end  
endfunction  

			else if ( game_status == PLAY|game_status == START) begin//When game begins, scans apple,snake head,snake body and wall.
				//led[0]<=1;
				cnt<=0;
				if(pos_x[9:4] == apple_x && pos_y[9:4] == apple_y) begin
					vga_rgb = PINK;
				end		
				else if(snake_show == WALL) begin
					vga_rgb = Salmon;
				end			
				else if(snake_show == NONE) begin

					if(fact_status==1)begin
					if(pos_x[9:4] >=12 && pos_x[9:4] < 13 && pos_y[9:4] >= 4 && pos_y[9:4] <= 10 ) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=16 && pos_x[9:4] < 17 && pos_y[9:4] >= 18  && pos_y[9:4] <= 26) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=24 && pos_x[9:4] < 25 && pos_y[9:4] >= 4 && pos_y[9:4] <= 10 ) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=28 && pos_x[9:4] < 29 && pos_y[9:4] >= 18 && pos_y[9:4] <= 26) begin
						vga_rgb<= GREEN;
					end
					else
					vga_rgb = BLACK;
				    end
					else if(fact_status==2)begin
					if(pos_x[9:4] >=12 && pos_x[9:4] < 13 && pos_y[9:4] >= 4 && pos_y[9:4] <= 10 ) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=16 && pos_x[9:4] < 17 && pos_y[9:4] >= 18  && pos_y[9:4] <= 26) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=24 && pos_x[9:4] < 25 && pos_y[9:4] >= 4 && pos_y[9:4] <= 10 ) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=28 && pos_x[9:4] < 29 && pos_y[9:4] >= 18 && pos_y[9:4] <= 26) begin
						vga_rgb<= GREEN;
					end

					else if(pos_x[9:4] >=5 && pos_x[9:4] < 9 && pos_y[9:4] >= 10 && pos_y[9:4] < 11) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=5 && pos_x[9:4] < 9 && pos_y[9:4] >= 20 && pos_y[9:4] < 21) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=32 && pos_x[9:4] < 36 && pos_y[9:4] >= 10 && pos_y[9:4] < 11) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=32 && pos_x[9:4] < 36 && pos_y[9:4] >= 20 && pos_y[9:4] < 21) begin
						vga_rgb<= GREEN;
					end
					else
					vga_rgb = BLACK;
					end
					else
					vga_rgb = BLACK;
					end
				else if(snake_show == HEAD|snake_show == BODY) begin
					//vga_rgb = (snake_show == HEAD) ?  GREEN : BLUE;
					case(body_status)
					4'b0001: vga_rgb = Seashell2;
					4'b0010:vga_rgb = WHITE;
					4'b0011:vga_rgb = BLUE;
					4'b0100:vga_rgb = Seashell2;
					4'b0101:vga_rgb = PINK;
					default: vga_rgb = Seashell;
					endcase
				end
				else begin
					vga_rgb<= Salmon;
				end
			end
			
			else if(bcd_data[11:8]==1'd1)begin//When it ups to 100 scores, means clearing the level
				if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
					vga_rgb = 24'hFFA500;
				else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
					vga_rgb = 24'hFFA500;

				else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
					vga_rgb = 24'hFFA500;
				else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
					vga_rgb = 24'hFFA500;
				else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
					vga_rgb = 24'hFFA500;
				else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
					vga_rgb = 24'hFFA500;
				else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
					vga_rgb = 24'hFFA500;
				else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
					vga_rgb = 24'hFFA500;

				else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
					vga_rgb = 24'hFFA500;
				else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
					vga_rgb = 24'hFFA500;
				else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
					vga_rgb = 24'hFFA500;
				else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
					vga_rgb = 24'hFFA500f;
				else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
					vga_rgb = 24'hFFA500;
				else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
					vga_rgb = 24'hFFA500;
				else 
					vga_rgb = BLACK;
				end
				
			else if (game_status==DIE )  begin
				cnt_clk<=0;
			  if(cnt<100000000)begin
					cnt<=cnt+1;
					if(pos_x[9:4] == apple_x && pos_y[9:4] == apple_y) begin
						vga_rgb = PINK;
					end	
					else if(snake_show == WALL) begin
						vga_rgb = Salmon;
					end				
					else if(snake_show == NONE) begin
					if(fact_status==1)begin
					if(pos_x[9:4] >=12 && pos_x[9:4] < 13 && pos_y[9:4] >= 4 && pos_y[9:4] <= 10 ) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=16 && pos_x[9:4] < 17 && pos_y[9:4] >= 18  && pos_y[9:4] <= 26) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=24 && pos_x[9:4] < 25 && pos_y[9:4] >= 4 && pos_y[9:4] <= 10 ) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=28 && pos_x[9:4] < 29 && pos_y[9:4] >= 18 && pos_y[9:4] <= 26) begin
						vga_rgb<= GREEN;
					end
					else
					vga_rgb = BLACK;
				    end
					else if(fact_status==2)begin
					if(pos_x[9:4] >=12 && pos_x[9:4] < 13 && pos_y[9:4] >= 4 && pos_y[9:4] <= 10 ) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=16 && pos_x[9:4] < 17 && pos_y[9:4] >= 18  && pos_y[9:4] <= 26) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=24 && pos_x[9:4] < 25 && pos_y[9:4] >= 4 && pos_y[9:4] <= 10 ) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=28 && pos_x[9:4] < 29 && pos_y[9:4] >= 18 && pos_y[9:4] <= 26) begin
						vga_rgb<= GREEN;
					end

					else if(pos_x[9:4] >=5 && pos_x[9:4] < 9 && pos_y[9:4] >= 10 && pos_y[9:4] < 11) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=5 && pos_x[9:4] < 9 && pos_y[9:4] >= 20 && pos_y[9:4] < 21) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=32 && pos_x[9:4] < 36 && pos_y[9:4] >= 10 && pos_y[9:4] < 11) begin
						vga_rgb<= GREEN;
					end
					else if(pos_x[9:4] >=32 && pos_x[9:4] < 36 && pos_y[9:4] >= 20 && pos_y[9:4] < 21) begin
						vga_rgb<= GREEN;
					end
					else
					vga_rgb = BLACK;
					end
					else
					vga_rgb = BLACK; 
					end
				
					else if(snake_show == HEAD|snake_show == BODY) begin
						//vga_rgb = (snake_show == HEAD) ?  GREEN : BLUE;
						case(body_status)
						4'b0001: vga_rgb = Seashell2;
						4'b0010:vga_rgb = WHITE;
						4'b0011:vga_rgb = BLUE;
						4'b0100:vga_rgb = Seashell6;
						4'b0101:vga_rgb = PINK;
					default: vga_rgb = Seashell;
					endcase
					end
					else begin
					vga_rgb<= BLACK;
					end
				end
				else if(cnt>=100000000) begin
					//cnt<=0;
					if(pos_x[9:4] >=5 && pos_x[9:4] < 13 && pos_y[9:4] >= 4 && pos_y[9:4] < 6&& charx2[char_yx2][127-char_xx2] == 1'b1)begin
						vga_rgb<= Seashell8; end//Displays 'final'
					else if(pos_x[9:4] >= 0 && pos_x[9:4] < 15 )begin
						case (bcd_data[11:8])
							4'd0:begin
								if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
									vga_rgb = 24'hFFA500;
							else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
							else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
							else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
							else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
							else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
							else
										 vga_rgb = BLACK;
							end
						4'd1:begin
							if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
							else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
					else
										  vga_rgb = BLACK;

				end
						4'd2:begin
					if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end
						4'd3:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end
						4'd4:begin
						 if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end
						4'd5:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
						  end

						4'd6:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end
						4'd7:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end
						4'd8:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end
						4'd9:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
				end 
				default: 
								 vga_rgb = BLACK;
			endcase
			end
			else if(pos_x[9:4] >= 15 && pos_x[9:4] < 25)begin
			case (bcd_data[7:4])
					 4'd0:begin
				if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						else
										 vga_rgb = BLACK;
						  end
					 4'd1:begin
						  if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										 vga_rgb = BLACK;
			
					end
					 4'd2:begin
				if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										 vga_rgb = BLACK;
					end
					 4'd3:begin
			if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
									 vga_rgb = 24'hFFA500;
					 else
									vga_rgb = BLACK;	
					end
					 4'd4:begin
			
					 if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
									 vga_rgb = 24'hFFA500;
					 else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
									 vga_rgb = 24'hFFA500;
					 else
									vga_rgb = BLACK;	
					end
					 4'd5:begin
						if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 14 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 6 && pos_x[9:4] < 8 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 12 && pos_x[9:4] < 14 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										  vga_rgb = BLACK;
						  end
					 4'd6:begin
				if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										 vga_rgb = BLACK;
					end
					 4'd7:begin
				if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										 vga_rgb = BLACK;
					end
					 4'd8:begin
				if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										 vga_rgb = BLACK;
					end
					 4'd9:begin
				if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_x[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 24 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 16 && pos_x[9:4] < 18 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 22 && pos_x[9:4] < 24 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else
										 vga_rgb = BLACK;
					end 
					default: 
										 vga_rgb = BLACK;
				endcase
		end
		else begin
		case (bcd_data[3:0])
					 4'd0:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
						  end
					 4'd1:begin
						  if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd2:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd3:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd4:begin
						  if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd5:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
						  end
					 4'd6:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd7:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd8:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end
					 4'd9:begin
				if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 10)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 34 && pos_y[9:4] >= 20 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 26 && pos_x[9:4] < 28 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 8 && pos_y[9:4] < 16)
										  vga_rgb = 24'hFFA500;
						  else if(pos_x[9:4] >= 32 && pos_x[9:4] < 34 && pos_y[9:4] >= 14 && pos_y[9:4] < 22)
										  vga_rgb = 24'hFFA500;
						  else 
											vga_rgb = BLACK;
					end 
					default: 
										 vga_rgb = BLACK;
				endcase
				end
			end
		end
	 else
		 vga_rgb = 24'h000000;
	end

// Instantiate ROM to store the initial game image  
rom_pic_v rom_pic_v_inst (  
    .address    (cnt_rom_address), // ROM address  
    .clock      (clk),             // Clock signal  
    .q          (rom_data)         // Output pixel data (one pixel at a time)  
);  

// ROM Address Counter  
always @(posedge clk or negedge rst_n) begin  
    if (!rst_n) begin  
        cnt_rom_address <= 0; // Reset address to zero  
    end else if (flag_clear_rom_address) begin  
        cnt_rom_address <= 0; // Clear address when counter reaches max  
    end else if (picture_flag_enable) begin  
        cnt_rom_address <= cnt_rom_address + 1; // Increment address in valid area  
    end else begin  
        cnt_rom_address <= cnt_rom_address; // Hold address in invalid area  
    end  
end  

// Clear ROM Address Flag  
assign flag_clear_rom_address = (cnt_rom_address == height * width - 1);  

// Horizontal and Vertical Flags for Picture Display Area  
assign flag_begin_h = (pos_x > ((640 - width) / 2)) && (pos_x < ((640 - width) / 2) + width + 1);  
assign flag_begin_v = (pos_y > ((480 - height) / 2)) && (pos_y < ((480 - height) / 2) + height + 1);  
assign picture_flag_enable = flag_begin_h && flag_begin_v; // Enable picture display in valid area  

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////  
// Character "LEVEL"  
// The character will be displayed in the range:  
// pos_x[9:4] >= 15 && pos_x[9:4] < 25 && pos_y[9:4] >= 8 && pos_y[9:4] < 10  
// Pixels where char[char_y][159-char_x] == 1'b1 will be displayed as white.  
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////  

// Character Coordinates for "LEVEL"  
assign char_x = (pos_x[9:4] >= 12 && pos_x[9:4] < 28 && pos_y[9:4] >= 6 && pos_y[9:4] < 8) ?   
                (pos_x - 12 * 16) : 0;  
assign char_y = (pos_x[9:4] >= 12 && pos_x[9:4] < 28 && pos_y[9:4] >= 6 && pos_y[9:4] < 8) ?   
                (pos_y - 6 * 16) : 0;  

// Character Coordinates for Other Text  
assign char_xx = (pos_x[9:4] >= 5 && pos_x[9:4] < 13 && pos_y[9:4] >= 4 && pos_y[9:4] < 6) ?   
                 (pos_x - 5 * 16) : 0;  
assign char_yx = (pos_x[9:4] >= 5 && pos_x[9:4] < 13 && pos_y[9:4] >= 4 && pos_y[9:4] < 6) ?   
                 (pos_y - 4 * 16) : 0;  

assign char_xx2 = (pos_x[9:4] >= 5 && pos_x[9:4] < 13 && pos_y[9:4] >= 4 && pos_y[9:4] < 6) ?   
                  (pos_x - 5 * 16) : 0;  
assign char_yx2 = (pos_x[9:4] >= 5 && pos_x[9:4] < 13 && pos_y[9:4] >= 4 && pos_y[9:4] < 6) ?   
                  (pos_y - 4 * 16) : 0;  
				  
//Text'LEVEL'
always@(posedge clk)
    begin
 char[0]      <=  256'h0000000000000000000000000000000000000000000000000000000000000000;
 char[1]      <=  256'h0000000000000000000000000000000000000000000000000000000000000000;
 char[2]      <=  256'h0000000000000000000000000000000000000000000000000000000000000000;
 char[3]      <=  256'h0000000000000000000000000000000000000000000000000000000000000000;
 char[4]      <=  256'h0000000000000000000000000000000000000000000000000000000000000000;
 char[5]      <=  256'h0000000000000000000000000000000000000000000000000000000000000000;
 char[6]      <=  256'h0000000000000000000000000000000000000000000000000000000000000000;
 char[7]      <=  256'h0000000000000000000000000000000000000000000000000000000000000000;
 char[8]      <=  256'h0000000000000000000007F80007F83F000007F8000000000000000000000000;
 char[9]      <=  256'h000000000000F80003FFFFF803FFE3FC03FFFFF8007C00000000000000000000;
 char[10]     <=  256'h0000000001FFE000007FFFF8007FC1F8007FFFF8FFF000000000000000000000;
 char[11]     <=  256'h00000000001FC000003FFFF8007FE1F8003FFFF80FE000000000000000000000;
 char[12]     <=  256'h00000000001FC000001FF80C003FE1F8001FF80C0FE000000000000000000000;
 char[13]     <=  256'h00000000001FC000001FF044003FE3F0001FF0440FE000000000000000000000;
 char[14]     <=  256'h00000000001FC000001FF040003FE3F0001FF0400FE000000000000000000000;
 char[15]     <=  256'h00000000001FC000001FF3C0001FE3E0001FF3C00FE000000000000000000000;
 char[16]     <=  256'h00000000001FE000001FFFC0001FE3E0001FFFC00FF000000000000000000000;
 char[17]     <=  256'h00000000001FE020001FFFC0000FE7E0001FFFC00FF010000000000000000000;
 char[18]     <=  256'h00000000001FE020001FFFC0000FE7C0001FFFC00FF010000000000000000000;
 char[19]     <=  256'h00000000001FE020000FF8E0000FF7C0000FF8E00FF010000000000000000000;
 char[20]     <=  256'h00000000001FE060000FF0220007F780000FF0220FF030000000000000000000;
 char[21]     <=  256'h00000000001FF1F0000FF0220007FF80000FF0220FF8F8000000000000000000;
 char[22]     <=  256'h00000000001FF7F0000FF0060003FF00000FF0060FFBF8000000000000000000;
 char[23]     <=  256'h00000000001FFFF0000FE00C0003FF00000FE00C0FFFF8000000000000000000;
 char[24]     <=  256'h00000000003FFFF0000FFF0C0003FF00000FFF0C1FFFF8000000000000000000;
 char[25]     <=  256'h00000000003FFFF00007FFFC0001FE000007FFFC1FFFF8000000000000000000;
 char[26]     <=  256'h00000000003FFFF8003FFFFC0003FE00003FFFFC1FFFFC000000000000000000;
 char[27]     <=  256'h0000000000FFC00801FFFFFC0007FF0001FFFFFC7FE004000000000000000000;
 char[28]     <=  256'h0000000000000008020007FC00081FC0020007FC000004000000000000000000;
 char[29]     <=  256'h0000000000000000000000000000000000000000000000000000000000000000;
 char[30]     <=  256'h0000000000000000000000000000000000000000000000000000000000000000;
 char[31]     <=  256'h0000000000000000000000000000000000000000000000000000000000000000;
    end
\\Text'record'
always@(posedge clk)
    begin
charx[0]      <=  128'h00000000000000000000000000000000;
charx[1]      <=  128'h00000000000000000000000000000000;
charx[2]      <=  128'h00000000000000000000000000000000;
charx[3]      <=  128'h00000000000000000000000000000000;
charx[4]      <=  128'h00000000000000000000000000000000;
charx[5]      <=  128'h00000000000000000000006000000000;
charx[6]      <=  128'h00000000000000000000006000000000;
charx[7]      <=  128'h00000000000000000000004000000000;
charx[8]      <=  128'h00000000000000000000004000000000;
charx[9]      <=  128'h00000000000000000000004000000000;
charx[10]     <=  128'h00000000000000000000004000000000;
charx[11]     <=  128'h00000000000000000000004000000000;
charx[12]     <=  128'h00E00006001C00000002034000000000;
charx[13]     <=  128'h73F8001F00360020010F054000000000;
charx[14]     <=  128'h73F800210064007001991A4000000000;
charx[15]     <=  128'h7700004100C000CC019010C000000000;
charx[16]     <=  128'h7E000086008000DE01A020C000000000;
charx[17]     <=  128'h7C0001B80180018301C060C000000000;
charx[18]     <=  128'h7C0001C00100010101C0C14000000000;
charx[19]     <=  128'h78000100030001010180816000000000;
charx[20]     <=  128'h78000100030303000180826000000000;
charx[21]     <=  128'h70000300020203010180826000000000;
charx[22]     <=  128'h70000100020403010180046000000000;
charx[23]     <=  128'h700001810208030301800C6000000000;
charx[24]     <=  128'h380001C60330018E0180986000000000;
charx[25]     <=  128'h3800007C01E001F80180F04000000000;
charx[26]     <=  128'h30000000000000000100000000000000;
charx[27]     <=  128'h00000000000000000000000000000000;
charx[28]     <=  128'h00000000000000000000000000000000;
charx[29]     <=  128'h00000000000000000000000000000000;
charx[30]     <=  128'h00000000000000000000000000000000;
charx[31]     <=  128'h00000000000000000000000000000000;
    end
\\Text'final'
always@(posedge clk)
    begin
        charx2[0]      <=  128'h00000000000000000000000000000000;
 charx2[1]      <=  128'h00000000000000000000000000000000;
 charx2[2]      <=  128'h00000000000000000000000000000000;
 charx2[3]      <=  128'h00000000000000000000000000000000;
 charx2[4]      <=  128'h00000000000000000000000000000000;
 charx2[5]      <=  128'h07800000000000000000000000000000;
 charx2[6]      <=  128'h1FE00000000000000400000000000000;
 charx2[7]      <=  128'h1CE01800000000000400000000000000;
 charx2[8]      <=  128'h38600C00000000000C00000000000000;
 charx2[9]      <=  128'h38600000000000000C00000000000000;
 charx2[10]     <=  128'h70000000000000000C00000000000000;
 charx2[11]     <=  128'h70000000000000000C00000000000000;
 charx2[12]     <=  128'h70000800000000040C00000000000000;
 charx2[13]     <=  128'h70000C000800001E0C00000000000000;
 charx2[14]     <=  128'h71E00C00181800230C00000000000000;
 charx2[15]     <=  128'h7FE00C00082C00C20C00000000000000;
 charx2[16]     <=  128'hFFC00C00084401830C00000000000000;
 charx2[17]     <=  128'hF0000C00084401030C00000000000000;
 charx2[18]     <=  128'h70000C000C8402050C00000000000000;
 charx2[19]     <=  128'h70000C000C84060D0C00000000000000;
 charx2[20]     <=  128'h70000C000D040C090C00000000000000;
 charx2[21]     <=  128'h70000C000D0408110C00000000000000;
 charx2[22]     <=  128'h70000400060C18210C00000000000000;
 charx2[23]     <=  128'h70000400060C18410C00000000000000;
 charx2[24]     <=  128'h70000400060C19810C00000000000000;
 charx2[25]     <=  128'h70000400000C1F010600000000000000;
 charx2[26]     <=  128'h70000400000C00000000000000000000;
 charx2[27]     <=  128'h70000000000000000000000000000000;
 charx2[28]     <=  128'h30000000000000000000000000000000;
 charx2[29]     <=  128'h30000000000000000000000000000000;
 charx2[30]     <=  128'h00000000000000000000000000000000;
 charx2[31]     <=  128'h00000000000000000000000000000000;
  
        
    end
 
endmodule				  
