module Chiptop(
    input wire clk,             // 100MHz clock (Arty Z7 standard PL clock)
    input wire [3:0] btn,       // Buttons: 0=Reset, 1=Left, 2=Right, 3=Pause
    output reg [3:0] led,       // 4 LEDs
    output wire uart_txd        // Connect to CH340 RX
);

    // --- 1. System Parameters ---
    parameter TICKS_PER_SEC = 125000000; // 1 second at 100MHz
    
    // Modes as defined in the Lab Manual
    localparam MODE_PAUSE = 2'b00;
    localparam MODE_LEFT  = 2'b01;
    localparam MODE_RIGHT = 2'b10;

    // --- 2. Internal Signals ---
    reg [31:0] timer_count = 0;
    reg tick_1hz = 0;
    reg [1:0] current_mode = MODE_PAUSE;
    
    // UART Signals
    reg [7:0] uart_data_in;
    reg uart_start;
    wire uart_busy;
    
    // Printing Control
    reg [3:0] print_step = 0;
    reg print_active = 0;

    // --- 3. Instantiate UART with 115200 Baud Rate ---
    uart_tx #(
        .CLK_FREQ(125000000), // Change to 125000000 if using sys_clk pin directly
        .BAUD_RATE(115200)    // UPDATED: Set to 115200
    ) my_uart (
        .clk(clk),
        .rst(btn[0]),      
        .tx_start(uart_start),
        .tx_data(uart_data_in),
        .tx_busy(uart_busy),
        .tx_pin(uart_txd)
    );

    // --- 4. Mode Control (Button Logic) ---
    //
    always @(posedge clk) begin
        if (btn[0]) current_mode <= MODE_PAUSE;      // Reset
        else if (btn[1]) current_mode <= MODE_LEFT;  // Left Shift
        else if (btn[2]) current_mode <= MODE_RIGHT; // Right Shift
        else if (btn[3]) current_mode <= MODE_PAUSE; // Pause
    end

    // --- 5. LED Shift Logic (1Hz) ---
    always @(posedge clk) begin
        if (btn[0]) begin
            led <= 4'b0011; // Default string
            timer_count <= 0;
            tick_1hz <= 0;
        end else begin
            if (timer_count < TICKS_PER_SEC - 1) begin
                timer_count <= timer_count + 1;
                tick_1hz <= 0;
            end else begin
                timer_count <= 0;
                tick_1hz <= 1; // Pulse every 1 second
                
                // Shift Logic
                case (current_mode)
                    MODE_LEFT:  led <= {led[2:0], led[3]}; // Circular Left
                    MODE_RIGHT: led <= {led[0], led[3:1]}; // Circular Right
                    MODE_PAUSE: led <= led;                // Hold
                endcase
            end
        end
    end

    // --- 6. Printing State Machine ---
    // Sends "XXXX" + New Line when LED updates
    always @(posedge clk) begin
        if (btn[0]) begin
            print_step <= 0;
            print_active <= 0;
            uart_start <= 0;
        end else begin
            // Start print sequence on 1Hz tick
            if (tick_1hz) begin
                print_active <= 1;
                print_step <= 0;
            end

            uart_start <= 0; // Default low

            if (print_active && !uart_busy && !uart_start) begin
                case (print_step)
                    0: begin // Bit 3
                        uart_data_in <= (led[3]) ? 8'h31 : 8'h30;
                        uart_start <= 1;
                        print_step <= 1;
                    end
                    1: begin // Bit 2
                        uart_data_in <= (led[2]) ? 8'h31 : 8'h30;
                        uart_start <= 1;
                        print_step <= 2;
                    end
                    2: begin // Bit 1
                        uart_data_in <= (led[1]) ? 8'h31 : 8'h30;
                        uart_start <= 1;
                        print_step <= 3;
                    end
                    3: begin // Bit 0
                        uart_data_in <= (led[0]) ? 8'h31 : 8'h30;
                        uart_start <= 1;
                        print_step <= 4;
                    end
                    4: begin // Carriage Return (\r)
                        uart_data_in <= 8'h0D; 
                        uart_start <= 1;
                        print_step <= 5;
                    end
                    5: begin // Line Feed (\n)
                        uart_data_in <= 8'h0A; 
                        uart_start <= 1;
                        print_step <= 6;
                    end
                    6: begin // End
                        print_active <= 0;
                        print_step <= 0;
                    end
                endcase
            end
        end
    end
endmodule