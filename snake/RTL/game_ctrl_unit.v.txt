// Game Control Module: Generates control signals based on the game state  
module game_ctrl_unit (  
    input clk,               // 25 MHz clock  
    input rst_n,             // System reset (active low)  

    // Direction control buttons  
    input key0_right,        // Control button: move right  
    input key1_left,         // Control button: move left  
    input key2_down,         // Control button: move down  
    input key3_up,           // Control button: move up  

    // Collision and score signals  
    input hit_wall,          // Collision with wall  
    input hit_body,          // Collision with self  
    input hit_stone,         // Collision with stone  
    input [11:0] bcd_data,   // Score in BCD format (game ends if score reaches 100)  

    // Output signals  
    output reg snake_display, // Snake visibility (used for flashing effect)  
    output reg [1:0] fact_status, // Difficulty level  
    output reg [1:0] game_status, // Current game state  
    output wire clear_signal,     // Signal to clear the game  
    output wire start_signal      // Signal to start the game  
);  

    // Game states  
    localparam RESTART = 2'b00;  // Game restart state  
    localparam START   = 2'b01;  // Game start state  
    localparam PLAY    = 2'b10;  // Game play state  
    localparam DIE     = 2'b11;  // Game over state  

    // Assignments for start and clear signals  
    assign start_signal = (game_status == PLAY) ? 1'b1 : 1'b0;  
    assign clear_signal = ((game_status == START) &&   
                           ((~key0_right) || (~key1_left) || (~key2_down) || (~key3_up))) ? 1'b1 : 1'b0;  

    // Internal registers  
    reg [32:0] cnt_clk;       // Counter for timing during RESTART state  
    reg [31:0] flash_cnt;     // Counter for flashing effect during DIE state  

    // State machine: Handles game states and transitions  
    always @(posedge clk or negedge rst_n) begin  
        if (!rst_n) begin  
            // Reset logic  
            cnt_clk <= 0;  
            flash_cnt <= 0;  
            snake_display <= 1;  
            game_status <= RESTART; // Initial state after reset  
            fact_status <= 0;  
        end else begin  
            case (game_status)  
                // 1. RESTART State  
                RESTART: begin  
                    cnt_clk <= cnt_clk + 1;  
                    if (cnt_clk > 150_000_000) begin // Display "Welcome" for 6 seconds  
                        if ((~key1_left) || (~key2_down) || (~key0_right)) begin  
                            game_status <= START; // Transition to START state after difficulty selection  
                            if (~key2_down) fact_status <= 0;  // Easy  
                            else if (~key1_left) fact_status <= 1; // Medium  
                            else if (~key0_right) fact_status <= 2; // Hard  
                        end  
                    end else begin  
                        game_status <= RESTART; // Stay in RESTART state  
                    end  
                end  

                // 2. START State  
                START: begin  
                    // Transition to PLAY state if any key is pressed  
                    if ((~key0_right) || (~key1_left) || (~key2_down) || (~key3_up)) begin  
                        game_status <= PLAY;  
                    end else begin  
                        game_status <= START; // Stay in START state  
                    end  
                end  

                // 3. PLAY State  
                PLAY: begin  
                    // Transition to DIE state if collision or score reaches 100  
                    if (hit_wall || hit_stone || hit_body || bcd_data[11:8] >= 1'd1) begin  
                        game_status <= DIE;  
                    end else begin  
                        game_status <= PLAY; // Stay in PLAY state  
                    end  
                end  

                // 4. DIE State  
                DIE: begin  
                    // Flashing effect for 4 seconds  
                    if (flash_cnt <= 100_000_000) begin  
                        flash_cnt <= flash_cnt + 1;  
                        // Toggle snake_display for flashing effect  
                        case (flash_cnt)  
                            12_500_000: snake_display <= 1'b0; // 0-0.5s: High  
                            25_000_000: snake_display <= 1'b1; // 0.5-1s: Low  
                            37_500_000: snake_display <= 1'b0; // 1-1.5s: High  
                            50_000_000: snake_display <= 1'b1; // 1.5-2s: Low  
                            62_500_000: snake_display <= 1'b0; // 2-2.5s: High  
                            75_000_000: snake_display <= 1'b1; // 2.5-3s: Low  
                        endcase  
                    end  
                    // Transition to RESTART state if any key is pressed  
                    else if ((~key0_right) || (~key1_left) || (~key2_down) || (~key3_up)) begin  
                        cnt_clk <= 0;  
                        flash_cnt <= 0;  
                        game_status <= RESTART;  
                    end else begin  
                        game_status <= DIE; // Stay in DIE state  
                    end  
                end  

                // Default case: Return to RESTART state  
                default: begin  
                    game_status <= RESTART;  
                end  
            endcase  
        end  
    end  

endmodule 