// Apple Generation Module  
// Initializes an apple's coordinates and checks if the snake eats the apple.  
// If eaten, generates new apple coordinates. Handles obstacles based on difficulty.  
module apple_generate (  
    input clk,               // 25 MHz clock  
    input rst_n,             // System reset (active low)  

    input [5:0] head_x,      // Snake head x-coordinate  
    input [5:0] head_y,      // Snake head y-coordinate  
    input [1:0] fact_status, // Difficulty level  

    output reg [5:0] apple_x, // Apple x-coordinate  
    output reg [4:0] apple_y, // Apple y-coordinate  
    output reg hit_stone,     // Collision with stone flag  
    output reg add_cube       // Snake eats an apple flag  
);  

    // Internal registers  
    reg [31:0] clk_cnt;       // Clock counter  
    reg [10:0] random_num;    // Random number generator (uninitialized)  

    // Random number generation logic  
    always @(posedge clk) begin  
        random_num <= random_num + 999; // Generate random number using addition  
        // High 6 bits: apple_x, Low 5 bits: apple_y  
    end  

    // Main logic  
    always @(posedge clk or negedge rst_n) begin  
        if (!rst_n) begin  
            // Reset logic  
            clk_cnt <= 0;  
            apple_x <= 20;  
            apple_y <= 10;  
            add_cube <= 0;  
            hit_stone <= 0;  
        end else begin  
            // Check if the snake eats the apple  
            if (apple_x == head_x && apple_y == head_y) begin  
                add_cube <= 1; // Snake eats the apple  
                // Generate new apple coordinates  
                apple_x <= (random_num[10:5] > 38) ? (random_num[10:5] - 25) :  
                           (random_num[10:5] == 0) ? 1 : random_num[10:5];  
                apple_y <= (random_num[4:0] > 28) ? (random_num[4:0] - 3) :  
                           (random_num[4:0] == 0) ? 1 : random_num[4:0];  
            end else if (fact_status == 1) begin  
                // Medium difficulty: Handle obstacles  
                add_cube <= 0;  
                handle_obstacles_medium();  
            end else if (fact_status == 2) begin  
                // Hard difficulty: Handle obstacles  
                add_cube <= 0;  
                handle_obstacles_hard();  
            end else begin  
                // Default case: No apple eaten, no obstacles  
                add_cube <= 0;  
                hit_stone <= 0;  
            end  
        end  
    end  

    // Task: Handle obstacles for medium difficulty  
    task handle_obstacles_medium;  
        begin  
            // Adjust apple position if it overlaps with obstacles  
            if (apple_x == 12 && apple_y >= 4 && apple_y <= 10) apple_x <= apple_x + 1;  
            else if (apple_x == 16 && apple_y >= 18 && apple_y <= 26) apple_x <= apple_x + 1;  
            else if (apple_x == 24 && apple_y >= 4 && apple_y <= 10) apple_x <= apple_x + 1;  
            else if (apple_x == 28 && apple_y >= 18 && apple_y <= 26) apple_x <= apple_x + 1;  

            // Check if the snake head collides with obstacles  
            if (head_x == 12 && head_y >= 4 && head_y <= 10) hit_stone <= 1;  
            else if (head_x == 16 && head_y >= 18 && head_y <= 26) hit_stone <= 1;  
            else if (head_x == 24 && head_y >= 4 && head_y <= 10) hit_stone <= 1;  
            else if (head_x == 28 && head_y >= 18 && head_y <= 26) hit_stone <= 1;  
            else hit_stone <= 0;  
        end  
    endtask  

    // Task: Handle obstacles for hard difficulty  
    task handle_obstacles_hard;  
        begin  
            // Adjust apple position if it overlaps with obstacles  
            if (apple_x == 12 && apple_y >= 4 && apple_y <= 10) apple_x <= apple_x + 1;  
            else if (apple_x == 16 && apple_y >= 18 && apple_y <= 26) apple_x <= apple_x + 1;  
            else if (apple_x == 24 && apple_y >= 4 && apple_y <= 10) apple_x <= apple_x + 1;  
            else if (apple_x == 28 && apple_y >= 18 && apple_y <= 26) apple_x <= apple_x + 1;  
            else if (apple_y == 10 && apple_x >= 5 && apple_x < 9) apple_y <= apple_y + 1;  
            else if (apple_y == 10 && apple_x >= 32 && apple_x < 36) apple_y <= apple_y + 1;  
            else if (apple_y == 20 && apple_x >= 5 && apple_x < 9) apple_y <= apple_y + 1;  
            else if (apple_y == 20 && apple_x >= 32 && apple_x < 36) apple_y <= apple_y + 1;  

            // Check if the snake head collides with obstacles  
            if (head_x == 12 && head_y >= 4 && head_y <= 10) hit_stone <= 1;  
            else if (head_x == 16 && head_y >= 18 && head_y <= 26) hit_stone <= 1;  
            else if (head_x == 24 && head_y >= 4 && head_y <= 10) hit_stone <= 1;  
            else if (head_x == 28 && head_y >= 18 && head_y <= 26) hit_stone <= 1;  
            else if (head_y == 10 && head_x >= 5 && head_x < 9) hit_stone <= 1;  
            else if (head_y == 10 && head_x >= 32 && head_x < 36) hit_stone <= 1;  
            else if (head_y == 20 && head_x >= 5 && head_x < 9) hit_stone <= 1;  
            else if (head_y == 20 && head_x >= 32 && head_x < 36) hit_stone <= 1;  
            else hit_stone <= 0;  
        end  
    endtask  

endmodule  