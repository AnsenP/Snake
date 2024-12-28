// Score Control Module  
module score_ctrl (  
    input clk,               // 25 MHz clock  
    input rst_n,             // System reset (active low)  
    input add_cube,          // Signal indicating the snake ate an apple  
    input [1:0] game_status, // Game state  

    output [11:0] bcd_data,       // Current score in BCD format  
    output [11:0] bcd_data_best,  // Best score in BCD format  
    output [7:0] bcd_data2        // Current score for seven-segment display  
);  

    // Local parameters for game states  
    localparam RESTART = 2'b00; // Game restart state  

    // Registers for binary scores  
    reg [7:0] bin_data;       // Current score in binary (0-100)  
    reg [7:0] bin_data_best;  // Best score in binary  

    // Current score logic  
    always @(posedge clk or negedge rst_n) begin  
        if (!rst_n) begin  
            bin_data <= 0; // Reset score to 0  
        end else if (game_status == RESTART) begin  
            bin_data <= 0; // Reset score to 0 on game restart  
        end else if (add_cube && bin_data < 8'd100) begin  
            bin_data <= bin_data + 1; // Increment score when apple is eaten  
        end else begin  
            bin_data <= bin_data; // Hold current score  
        end  
    end  

    // Best score logic  
    always @(posedge clk or negedge rst_n) begin  
        if (!rst_n) begin  
            bin_data_best <= 0; // Reset best score to 0  
        end else if (bin_data >= bin_data_best) begin  
            bin_data_best <= bin_data; // Update best score if current score is higher  
        end else begin  
            bin_data_best <= bin_data_best; // Hold best score  
        end  
    end  

    // Convert binary scores to BCD format  
    assign bcd_data[3:0]   = bin_data % 10;           // Units digit  
    assign bcd_data[7:4]   = (bin_data / 10) % 10;    // Tens digit  
    assign bcd_data[11:8]  = (bin_data / 100) % 10;   // Hundreds digit  

    assign bcd_data_best[3:0]   = bin_data_best % 10;           // Units digit  
    assign bcd_data_best[7:4]   = (bin_data_best / 10) % 10;    // Tens digit  
    assign bcd_data_best[11:8]  = (bin_data_best / 100) % 10;   // Hundreds digit  

    // Assign current score to seven-segment display output  
    assign bcd_data2 = bin_data;  

endmodule  