module uart_tx #(
    parameter CLK_FREQ = 100000000,
    parameter BAUD_RATE = 115200 // Default, but overridden by instantiation
)(
    input wire clk,
    input wire rst,
    input wire tx_start,
    input wire [7:0] tx_data,
    output reg tx_busy,
    output reg tx_pin
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state = IDLE;
    reg [31:0] clk_count = 0;
    reg [2:0] bit_index = 0;
    reg [7:0] data_temp = 0;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            tx_pin <= 1;
            tx_busy <= 0;
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_pin <= 1;
                    tx_busy <= 0;
                    clk_count <= 0;
                    if (tx_start) begin
                        data_temp <= tx_data;
                        state <= START;
                        tx_busy <= 1;
                    end
                end
                START: begin
                    tx_pin <= 0;
                    if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        state <= DATA;
                    end
                end
                DATA: begin
                    tx_pin <= data_temp[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        if (bit_index < 7) bit_index <= bit_index + 1;
                        else begin
                            bit_index <= 0;
                            state <= STOP;
                        end
                    end
                end
                STOP: begin
                    tx_pin <= 1;
                    if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                    else state <= IDLE;
                end
            endcase
        end
    end
endmodule