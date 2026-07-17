// plain 8N1 UART, TX 
// this is how the host talks to the accelerator: 
// TX reads results back
// CLKS_PER_BIT = clk_freq / baud (kept small for sim)


module uart_tx #(
    parameter CLKS_PER_BIT = 16
)(
    input wire clk_i,
    input wire rst_i,
    input wire start_i, // pulse to send data_i
    input wire [7:0] data_i,
    output reg tx_o, // serial line out (idles high)
    output reg busy_o
);
    localparam S_IDLE=2'd0, S_START=2'd1, S_DATA=2'd2, S_STOP=2'd3;
    reg [1:0] state;
    reg [15:0] clk_cnt;
    reg [2:0] bit_idx;
    reg [7:0] shreg;

    always @(posedge clk_i) begin
        if (rst_i) begin
            state <= S_IDLE; tx_o <= 1'b1; busy_o <= 1'b0;
            clk_cnt <= 0; bit_idx <= 0; shreg <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx_o <= 1'b1; busy_o <= 1'b0; clk_cnt <= 0; bit_idx <= 0;
                    if (start_i) begin shreg <= data_i; busy_o <= 1'b1; state <= S_START; end
                end
                S_START: begin // start bit low
                    tx_o <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT-1) begin clk_cnt <= 0; state <= S_DATA; end
                    else clk_cnt <= clk_cnt + 1'b1;
                end
                S_DATA: begin // 8 data bits, LSB first
                    tx_o <= shreg[bit_idx];
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 0;
                        if (bit_idx == 3'd7) state <= S_STOP;
                        else bit_idx <= bit_idx + 1'b1;
                    end else clk_cnt <= clk_cnt + 1'b1;
                end
                S_STOP: begin // stop bit high
                    tx_o <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT-1) begin clk_cnt <= 0; state <= S_IDLE; end
                    else clk_cnt <= clk_cnt + 1'b1;
                end
            endcase
        end
    end

endmodule
