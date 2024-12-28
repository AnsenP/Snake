// Top-level module for the Snake Game  
module snake_top (  
    input clk,              // System clock (50 MHz)  
    input rst_n,            // System reset (active low, connected to SW[3])  
    input [3:0] key,        // Direction control keys  
    output wire [3:0] led,  // Debugging LEDs (mirrors key inputs)  

    // VGA outputs  
    output vga_hsync,       // VGA horizontal sync signal  
    output vga_vsync,       // VGA vertical sync signal  
    output [15:0] rgb,      // VGA RGB output (5 bits red, 6 bits green, 5 bits blue)  

    // Seven-segment display outputs  
    output wire stcp,       // Storage register clock  
    output wire shcp,       // Shift register clock  
    output wire ds,         // Serial data input  
    output wire oe          // Output enable signal  
);  

    // Assign LEDs to mirror key inputs for debugging  
    assign led = key;  

    // Internal signals  
    wire clk_25m;           // 25 MHz clock for VGA  
    wire pll_locked;        // PLL lock status  
    wire [23:0] vga_rgb;    // 24-bit RGB signal for VGA  
    assign rgb = {vga_rgb[23:19], vga_rgb[15:10], vga_rgb[7:3]}; // Convert to 16-bit RGB  

    // VGA control signals  
    wire vga_clk = clk_25m; // VGA pixel clock  
    wire vga_blank_n;       // VGA blanking signal  
    wire vga_sync_n = 1'b0; // VGA sync signal (not used)  

    // Game control signals  
    wire [1:0] snake_show;  // Indicates the current scanned object (head, body, etc.)  
    wire [9:0] pos_x;       // VGA pixel x-coordinate  
    wire [9:0] pos_y;       // VGA pixel y-coordinate  
    wire [5:0] apple_x;     // Apple x-coordinate  
    wire [4:0] apple_y;     // Apple y-coordinate  
    wire [5:0] head_x;      // Snake head x-coordinate  
    wire [5:0] head_y;      // Snake head y-coordinate  
    wire add_cube;          // Signal to grow the snake  
    wire [1:0] game_status; // Game state (restart, play, die)  
    wire [3:0] body_status; // Current body segment being scanned  
    wire hit_wall;          // Collision with wall flag  
    wire hit_body;          // Collision with body flag  
    wire snake_display;     // Snake visibility flag  
    wire [1:0] fact_status; // Difficulty level  
    wire clear_signal;      // Clear game signal  
    wire start_signal;      // Start game signal  
    wire hit_stone;         // Collision with stone flag  

    // Score signals  
    wire [11:0] bcd_data;       // Current score in BCD format  
    wire [7:0] bcd_data2;       // Score for seven-segment display  
    wire [11:0] bcd_data_best;  // Best score in BCD format  

    // Direction control signals  
    wire right_flag;    // Right direction flag  
    wire left_flag;     // Left direction flag  
    wire down_flag;     // Down direction flag  
    wire up_flag;       // Up direction flag  

    // PLL Instance (Generates 25 MHz clock for VGA)  
    pll pll_inst (  
        .areset(~rst_n),    // Active-high reset  
        .inclk0(clk),       // Input clock (50 MHz)  
        .c0(clk_25m),       // Output clock (25 MHz)  
        .locked(pll_locked) // PLL lock status  
    );  

    // Key Filter (Debounces input keys)  
    key_filter key_filter_inst (  
        .sys_clk(clk_25m),  
        .sys_rst_n(rst_n),  
        .key_in(key),  
        .key_value({right_flag, left_flag, down_flag, up_flag})  
    );  

    // Game Control Unit (Manages game state and interactions)  
    game_ctrl_unit game_ctrl_inst (  
        .clk(clk_25m),  
        .rst_n(rst_n),  
        .key0_right(right_flag),  
        .key1_left(left_flag),  
        .key2_down(down_flag),  
        .key3_up(up_flag),  
        .game_status(game_status),  
        .snake_display(snake_display),  
        .hit_wall(hit_wall),  
        .hit_body(hit_body),  
        .hit_stone(hit_stone),  
        .bcd_data(bcd_data),  
        .fact_status(fact_status),  
        .clear_signal(clear_signal),  
        .start_signal(start_signal)  
    );  

    // Apple Generator (Generates apple coordinates and checks if eaten)  
    apple_generate apple_gen_inst (  
        .clk(clk_25m),  
        .rst_n(rst_n),  
        .apple_x(apple_x),  
        .apple_y(apple_y),  
        .head_x(head_x),  
        .head_y(head_y),  
        .fact_status(fact_status),  
        .add_cube(add_cube),  
        .hit_stone(hit_stone)  
    );  

    // Snake Controller (Handles snake movement, collisions, and rendering)  
    snake_ctrl snake_ctrl_inst (  
        .clk(clk_25m),  
        .rst_n(rst_n),  
        .key0_right(right_flag),  
        .key1_left(left_flag),  
        .key2_down(down_flag),  
        .key3_up(up_flag),  
        .snake_show(snake_show),  
        .pos_x(pos_x),  
        .pos_y(pos_y),  
        .head_x(head_x),  
        .head_y(head_y),  
        .add_cube(add_cube),  
        .game_status(game_status),  
        .hit_body(hit_body),  
        .snake_display(snake_display),  
        .hit_wall(hit_wall),  
        .body_status(body_status),  
        .fact_status(fact_status)  
    );  

    // VGA Controller (Generates VGA signals and renders game objects)  
    VGA_control vga_ctrl_inst (  
        .clk(clk_25m),  
        .rst_n(rst_n),  
        .game_status(game_status),  
        .snake_show(snake_show),  
        .bcd_data(bcd_data),  
        .bcd_data_best(bcd_data_best),  
        .pos_x(pos_x),  
        .pos_y(pos_y),  
        .apple_x(apple_x),  
        .apple_y(apple_y),  
        .vga_rgb(vga_rgb),  
        .vga_hs(vga_hsync),  
        .vga_blank_n(vga_blank_n),  
        .vga_vs(vga_vsync),  
        .body_status(body_status),  
        .fact_status(fact_status)  
    );  

    // Score Controller (Tracks and updates the score)  
    score_ctrl score_ctrl_inst (  
        .clk(clk_25m),  
        .rst_n(rst_n),  
        .add_cube(add_cube),  
        .game_status(game_status),  
        .bcd_data(bcd_data),  
        .bcd_data2(bcd_data2),  
        .bcd_data_best(bcd_data_best)  
    );  

    // Seven-Segment Display Controller (Displays score on 7-segment display)  
    top_seg_595 seg_display_inst (  
        .sys_clk(clk_25m),  
        .sys_rst_n(rst_n),  
        .bcd_data(bcd_data2),  
        .clear_signal(clear_signal),  
        .start_signal(start_signal),  
        .stcp(stcp),  
        .shcp(shcp),  
        .ds(ds),  
        .oe(oe)  
    );  

endmodule 