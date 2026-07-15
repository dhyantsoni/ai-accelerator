// requantize.v
// Shrinks the accumulator's big signed INT32 totals back down to signed INT8,
// so the next layer (another INT8 matmul) can use them

module requantize #(
    parameter COLS = 4,
    parameter ACC_WIDTH = 32, // input width (from accumulator)
    parameter OUT_WIDTH = 8, // output width (INT8)
    parameter MULT_WIDTH = 16, // width of the scale multiplier
    parameter PROD_WIDTH = ACC_WIDTH + MULT_WIDTH
)(
    input wire clk_i,
    input wire rst_i,
    input wire [ACC_WIDTH*COLS-1:0] acc_i_flat, // per-column totals from accumulator
    input wire valid_i,
    input wire signed [MULT_WIDTH-1:0] scale_i, // per-layer fixed-point scale
    input wire [4:0] shift_i, // per-layer right shift
    output wire [OUT_WIDTH*COLS-1:0] q_o_flat, // per-column INT8 results
    output reg valid_o
);

    genvar c;
    generate
        for (c = 0; c < COLS; c = c + 1) begin : col_rq
            reg signed [OUT_WIDTH-1:0] q_q;

            wire signed [ACC_WIDTH-1:0] acc_c = acc_i_flat[c*ACC_WIDTH +: ACC_WIDTH];

            // widen multiply: signed acc * signed scale
            wire signed [PROD_WIDTH-1:0] wide = acc_c * scale_i;

            // round-to-nearest: add half an LSB of the shift (0 when shift==0)
            wire signed [PROD_WIDTH-1:0] round_add =
                (shift_i == 5'd0) ? {PROD_WIDTH{1'b0}}
                                  : ({{(PROD_WIDTH-1){1'b0}}, 1'b1} << (shift_i - 1));

            // arithmetic right shift keeps the sign
            wire signed [PROD_WIDTH-1:0] shifted = (wide + round_add) >>> shift_i;

            always @(posedge clk_i) begin
                if (rst_i)
                    q_q <= {OUT_WIDTH{1'b0}};
                else if (valid_i) begin
                    if (shifted > 127)
                        q_q <= 8'sd127; // clamp high
                    else if (shifted < -128)
                        q_q <= -8'sd128; // clamp low
                    else
                        q_q <= shifted[OUT_WIDTH-1:0];
                end
            end

            assign q_o_flat[c*OUT_WIDTH +: OUT_WIDTH] = q_q;
        end
    endgenerate

    always @(posedge clk_i) begin
        if (rst_i)
            valid_o <= 1'b0;
        else
            valid_o <= valid_i;
    end

`ifdef COCOTB_SIM
    initial begin
        $dumpfile("requantize.vcd");
        $dumpvars(0, requantize);
        #1;
    end
`endif

endmodule
