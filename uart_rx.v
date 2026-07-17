// plain 8N1 UART, RX 
// this is how the host talks to the accelerator: 
// RX writes config/data in, 
// CLKS_PER_BIT = clk_freq / baud (kept small for sim)

module uart_rx #(
    parameter CLKS_PER_BIT = 16
)(
    input wire clk_i,
    input wire rst_i,
    input wire rx_i, // serial line in (idles high)
    output reg [7:0] data_o, // received byte
    output reg valid_o // one-cycle pulse when data_o is fresh
);
    localparam S_IDLE=2'd0, S_START=2'd1, S_DATA=2'd2, S_STOP=2'd3;
    reg [1:0] state;
    reg [15:0] clk_cnt;
    reg [2:0] bit_idx;
    reg rx_d1, rx_d2; // 2FF synchronizer for the async line

    always @(posedge clk_i) begin
        rx_d1 <= rx_i;
        rx_d2 <= rx_d1;
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            state <= S_IDLE; clk_cnt <= 0; bit_idx <= 0; valid_o <= 0; data_o <= 0;
        end else begin
            valid_o <= 1'b0;
            case (state)
                S_IDLE: begin
                    clk_cnt <= 0; bit_idx <= 0;
                    if (!rx_d2) state <= S_START; // start bit: line pulled low
                end
                S_START: // sample at the middle of the start bit to confirm
                    if (clk_cnt == CLKS_PER_BIT/2) begin
                        if (!rx_d2) begin clk_cnt <= 0; state <= S_DATA; end
                        else state <= S_IDLE; // false start
                    end else clk_cnt <= clk_cnt + 1'b1;
                S_DATA: // sample each bit at its center, LSB first
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 0;
                        data_o[bit_idx] <= rx_d2;
                        if (bit_idx == 3'd7) state <= S_STOP;
                        else bit_idx <= bit_idx + 1'b1;
                    end else clk_cnt <= clk_cnt + 1'b1;
                S_STOP:
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        valid_o <= 1'b1; // byte complete
                        state <= S_IDLE;
                    end else clk_cnt <= clk_cnt + 1'b1;
            endcase
        end
    end
endmodule
