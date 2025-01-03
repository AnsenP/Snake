module snake_ctrl(  
    // Game control inputs  
    input clk,              // 25MHz clock  
    input rst_n,            // System reset (active low)  
    input [1:0] game_status,// Game state (restart, play, die)  
    input [1:0] fact_status,// Difficulty level  

    // Direction control inputs  
    input key0_right,       // Move right  
    input key1_left,        // Move left  
    input key2_down,        // Move down  
    input key3_up,          // Move up  

    // VGA rendering inputs  
    input [9:0] pos_x,      // Current pixel x-coordinate (0-640)  
    input [9:0] pos_y,      // Current pixel y-coordinate (0-480)  
    input snake_display,    // Snake visibility flag  

    // Snake growth input  
    input add_cube,         // Signal to grow the snake  

    // Outputs  
    output [5:0] head_x,    // Snake head x-coordinate (0-40)  
    output [5:0] head_y,    // Snake head y-coordinate (0-30)  
    output reg [3:0] body_status, // Body segment being scanned  
    output reg hit_body,    // Collision with body flag  
    output reg hit_wall,    // Collision with wall flag  
    output reg [1:0] snake_show // Current scanned object (none, head, body, wall)  
);  

    // Direction encoding  
    localparam UP    = 2'b00;  
    localparam DOWN  = 2'b01;  
    localparam LEFT  = 2'b10;  
    localparam RIGHT = 2'b11;  

    // Display states  
    localparam NONE  = 2'b00; // No object  
    localparam HEAD  = 2'b01; // Snake head  
    localparam BODY  = 2'b10; // Snake body  
    localparam WALL  = 2'b11; // Wall  

    // Game states  
    localparam RESTART = 2'b00;  
    localparam PLAY    = 2'b10;  
    localparam DIE     = 2'b11;  

    // Snake parameters  
    reg [5:0] cube_x[15:0];  // Snake body x-coordinates  
    reg [5:0] cube_y[15:0];  // Snake body y-coordinates  
    reg [15:0] is_exist;     // Active body segments  
    reg [3:0] cube_num;      // Current snake length  
    reg [23:0] speed;        // Snake speed  
    reg [31:0] clk_cnt;      // Clock counter for movement timing  
    reg [1:0] direction;     // Current direction  
    reg [1:0] next_direction;// Next direction  
    reg addcube_state;       // State for handling snake growth  

    // Assign head coordinates  
    assign head_x = cube_x[0];  
    assign head_y = cube_y[0];  

    // Task to reset the snake  
    task reset_snake;  
        integer i;  
        begin  
            clk_cnt <= 0;  
            cube_num <= 5; // Initial length  
            is_exist <= 16'd31; // First 5 segments active  
            direction <= RIGHT;  
            next_direction <= RIGHT;  
            speed <= 24'd12500000; // Default speed  

            // Initialize snake body  
            cube_x[0] <= 10; cube_y[0] <= 5; // Head  
            cube_x[1] <= 9;  cube_y[1] <= 5;  
            cube_x[2] <= 8;  cube_y[2] <= 5;  
            cube_x[3] <= 7;  cube_y[3] <= 5;  
            cube_x[4] <= 6;  cube_y[4] <= 5;  

            for (i = 5; i < 16; i = i + 1) begin  
                cube_x[i] <= 0;  
                cube_y[i] <= 0;  
            end  

            hit_wall <= 0;  
            hit_body <= 0;  
        end  
    endtask  

    // Handle reset and game restart  
    always @(posedge clk or negedge rst_n) begin  
        if (!rst_n || game_status == RESTART) begin  
            reset_snake();  
        end else if (game_status == PLAY) begin  
            // Adjust speed based on difficulty  
            case (fact_status)  
                2'b00: speed <= 24'd12500000; // Slow  
                2'b01: speed <= 24'd6250000;  // Medium  
                2'b10: speed <= 24'd3125000;  // Fast  
                default: speed <= 24'd12500000;  
            endcase  
        end  
    end  

    // Update direction based on key inputs  
    always @(*) begin  
        case (direction)  
            UP: begin  
                if (!key1_left) next_direction = LEFT;  
                else if (!key0_right) next_direction = RIGHT;  
                else next_direction = UP;  
            end  
            DOWN: begin  
                if (!key1_left) next_direction = LEFT;  
                else if (!key0_right) next_direction = RIGHT;  
                else next_direction = DOWN;  
            end  
            LEFT: begin  
                if (!key3_up) next_direction = UP;  
                else if (!key2_down) next_direction = DOWN;  
                else next_direction = LEFT;  
            end  
            RIGHT: begin  
                if (!key3_up) next_direction = UP;  
                else if (!key2_down) next_direction = DOWN;  
                else next_direction = RIGHT;  
            end  
        endcase  
    end  

    // Snake movement and collision detection  
    always @(posedge clk) begin  
        if (game_status == PLAY) begin  
            clk_cnt <= clk_cnt + 1;  
            if (clk_cnt >= speed) begin  
                clk_cnt <= 0;  
                direction <= next_direction;  

                // Move body segments  
                integer i;  
                for (i = cube_num; i > 0; i = i - 1) begin  
                    cube_x[i] <= cube_x[i-1];  
                    cube_y[i] <= cube_y[i-1];  
                end  

                // Move head based on direction  
                case (direction)  
                    UP:    cube_y[0] <= cube_y[0] - 1;  
                    DOWN:  cube_y[0] <= cube_y[0] + 1;  
                    LEFT:  cube_x[0] <= cube_x[0] - 1;  
                    RIGHT: cube_x[0] <= cube_x[0] + 1;  
                endcase  

                // Check for wall collision  
                if (cube_x[0] == 0 || cube_x[0] == 39 || cube_y[0] == 0 || cube_y[0] == 29) begin  
                    hit_wall <= 1;  
                end  

                // Check for body collision  
                hit_body <= 0;  
                for (i = 1; i < cube_num; i = i + 1) begin  
                    if (cube_x[0] == cube_x[i] && cube_y[0] == cube_y[i] && is_exist[i]) begin  
                        hit_body <= 1;  
                    end  
                end  
            end  
        end  
    end  

    // Handle snake growth  
    always @(posedge clk or negedge rst_n) begin  
        if (!rst_n || game_status == RESTART) begin  
            addcube_state <= 0;  
        end else if (add_cube && !addcube_state) begin  
            if (cube_num < 16) begin  
                is_exist[cube_num] <= 1;  
                cube_num <= cube_num + 1;  
            end  
            addcube_state <= 1;  
        end else if (!add_cube) begin  
            addcube_state <= 0;  
        end  
    end  

    // VGA rendering logic  
    always @(*) begin  
        if (pos_x[9:4] == 0 || pos_x[9:4] == 39 || pos_y[9:4] == 0 || pos_y[9:4] == 29) begin  
            snake_show = WALL; // Wall  
        end else if (pos_x[9:4] == cube_x[0] && pos_y[9:4] == cube_y[0] && is_exist[0]) begin  
            snake_show = snake_display ? HEAD : NONE; // Head  
        end else begin  
            snake_show = NONE;  
            integer i;  
            for (i = 1; i < 16; i = i + 1) begin  
                if (pos_x[9:4] == cube_x[i] && pos_y[9:4] == cube_y[i] && is_exist[i]) begin  
                    snake_show = snake_display ? BODY : NONE; // Body  
                end  
            end  
        end  
    end  

endmodule