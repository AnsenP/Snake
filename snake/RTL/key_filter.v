// Key Filter Module  
// Debounces key inputs and detects when a key is pressed.  
module key_filter (  
    input sys_clk,            // System clock  
    input sys_rst_n,          // System reset (active low)  
    input [3:0] key_in,       // Key input signals  

    output key_flag,          // Key press flag (rising edge detected)  
    output reg [3:0] key_value // Current stable key value  
);  

    // Parameters  
    parameter DELAY = 20'd1_000_000; // Debounce delay (20 ms)  

    // Internal registers  
    reg [3:0] key_now;         // Current key state  
    reg [3:0] key_last;        // Previous key state  
    reg key_state;             // Stable key state  
    reg key_state0, key_state1; // Synchronization registers for edge detection  
    reg [19:0] cnt;            // Counter for debounce delay  
    reg en_cnt;                // Counter enable signal  

    // Synchronize key_state for edge detection  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n) begin  
            key_state0 <= 1'b0;  
            key_state1 <= 1'b0;  
        end else begin  
            key_state0 <= key_state;  
            key_state1 <= key_state0;  
        end  
    end  

    // Detect rising edge of key_state  
    assign key_flag = key_state0 & (~key_state1);  

    // Read the current and previous key states  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n) begin  
            key_now <= 4'b1111;  // Default: all keys unpressed  
            key_last <= 4'b1111;  
        end else begin  
            key_now <= key_in;   // Update current key state  
            key_last <= key_now; // Update previous key state  
        end  
    end  

    // Debounce logic: Detect stable key state after DELAY  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n) begin  
            en_cnt <= 1'b1;      // Enable counter by default  
            key_state <= 1'b0;   // Default: no key pressed  
            key_value <= 4'b1111; // Default: no key value  
        end else if (key_last != key_now) begin  
            en_cnt <= 1'b0;      // Disable counter if key state changes  
            key_state <= 1'b0;   // Reset stable key state  
        end else if (key_last == key_now) begin  
            en_cnt <= 1'b1;      // Enable counter if key state is stable  
            if (cnt == DELAY - 1'b1) begin  
                key_value <= key_last; // Update stable key value  
                if (key_last != 4'b1111) begin  
                    key_state <= 1'b1; // Set stable key state if key is pressed  
                end  
            end  
        end  
    end  

    // Counter for debounce delay (20 ms)  
    always @(posedge sys_clk or negedge sys_rst_n) begin  
        if (!sys_rst_n) begin  
            cnt <= 20'd0; // Reset counter  
        end else if (en_cnt) begin  
            if (cnt == DELAY - 1'b1) begin  
                cnt <= 20'd0; // Reset counter after reaching DELAY  
            end else begin  
                cnt <= cnt + 1'b1; // Increment counter  
            end  
        end else begin  
            cnt <= 20'd0; // Reset counter if disabled  
        end  
    end  

endmodule 