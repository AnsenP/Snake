`timescale 1ns/1ps  
module tb_top();  

    // Clock and reset signals  
    reg clk;  
    reg rst_n;  

    // Key inputs  
    reg [3:0] key;  

    // Outputs to observe  
    wire [3:0] led;            // LED output  
    wire vga_hsync;            // VGA horizontal sync  
    wire vga_vsync;            // VGA vertical sync  
    wire [15:0] rgb;           // VGA RGB output  
    wire stcp;                 // Serial-to-Parallel control signal  
    wire shcp;                 // Shift clock  
    wire ds;                   // Serial data  
    wire oe;                   // Output enable  

    // Instantiate the DUT (Device Under Test)  
    snake_top uut (  
        .clk(clk),  
        .rst_n(rst_n),  
        .key(key),  
        .led(led),  
        .vga_hsync(vga_hsync),  
        .vga_vsync(vga_vsync),  
        .rgb(rgb),  
        .stcp(stcp),  
        .shcp(shcp),  
        .ds(ds),  
        .oe(oe)  
    );  

    // Clock generation (50 MHz)  
    initial begin  
        clk = 0;  
        forever #10 clk = ~clk; // Toggle clock every 10ns (50 MHz frequency)  
    end  

    // Reset signal generation  
    initial begin  
        rst_n = 0;            // Initially reset the system  
        #50 rst_n = 1;        // Release reset after 50ns  
    end  

    // Key input simulation  
    initial begin  
        // Initialize key inputs (all keys unpressed)  
        key = 4'b1111;  

        // Simulate key presses with debounce  
        simulate_key_press(4'b1110, 200000); // Simulate key 1 press  
        simulate_key_press(4'b1101, 200000); // Simulate key 2 press  
        simulate_key_press(4'b1011, 200000); // Simulate key 3 press  
        simulate_key_press(4'b0111, 200000); // Simulate key 4 press  
        simulate_key_press(4'b1101, 200000); // Simulate key 2 press again  

        // Wait for a while before ending the simulation  
        #100000000;  
        $finish; // End simulation  
    end  

    // Task to simulate key presses with debounce  
    task simulate_key_press(input [3:0] key_value, input integer debounce_time);  
        begin  
            #100 key = key_value;        // Simulate key press  
            #debounce_time;             // Wait for debounce time  
            #100 key = 4'b1111;         // Release key  
        end  
    endtask  

endmodule 