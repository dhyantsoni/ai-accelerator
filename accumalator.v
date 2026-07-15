// accumalator.v
// 1. Accumulate across tiles: acc <= acc + this_tile's_partial
// 2. Preload the bias: on the first tile, start from bias instead of 0

module accumalator #(
    parameter COLS = 4, // one accumulator per array column
    parameter PSUM_WIDTH = 20, // width of each partial sum from the array (= array's ACC_WIDTH)
    parameter ACC_WIDTH = 32 // running-total width (wider, to sum many tiles safely)
)(
    input wire clk_i,
    input wire rst_i,

    input wire [PSUM_WIDTH*COLS-1:0] psum_i_flat, // per-column results from array bottom edge
    input wire valid_i, // high when psum_i_flat is a real tile result to add
    input wire first_tile_i, // high on the FIRST tile: start from bias
    input wire last_tile_i, // high on the LAST tile: total is done after this add
    input wire [ACC_WIDTH*COLS-1:0] bias_i_flat, // per-column bias, folded in on the first tile

    output wire [ACC_WIDTH*COLS-1:0] acc_o_flat, // per-column running totals
    output reg acc_valid_o // pulses high the cycle the final total is ready
);
    genvar c;
    generate
        for (c = 0; c < COLS; c = c + 1) begin : col_acc
            reg [ACC_WIDTH-1:0] acc_q;

            // this column's incoming partial sum, sign-extended up to ACC_WIDTH.
            // treats the value as signed two's complement (useful for INT8 math (took so long to understand)).
            wire signed [PSUM_WIDTH-1:0] psum_c = psum_i_flat[c*PSUM_WIDTH +: PSUM_WIDTH];
            wire signed [ACC_WIDTH-1:0] psum_ext = {{(ACC_WIDTH-PSUM_WIDTH){psum_c[PSUM_WIDTH-1]}}, psum_c};
            wire [ACC_WIDTH-1:0] bias_c = bias_i_flat[c*ACC_WIDTH +: ACC_WIDTH];

            always @(posedge clk_i) begin
                if (rst_i)
                    acc_q <= {ACC_WIDTH{1'b0}};
                else if (valid_i) begin
                    if (first_tile_i)
                        acc_q <= bias_c + psum_ext; // first tile: start from bias, add first partial
                    else
                        acc_q <= acc_q + psum_ext; // later tiles: keep piling on
                end
            end

            assign acc_o_flat[c*ACC_WIDTH +: ACC_WIDTH] = acc_q;
        end
    endgenerate

    // final total is registered on the same edge as the last accumulate,
    // so acc_valid_o lines up with acc_q holding the complete result.
    always @(posedge clk_i) begin
        if (rst_i)
            acc_valid_o <= 1'b0;
        else
            acc_valid_o <= valid_i & last_tile_i;
    end

`ifdef COCOTB_SIM
    initial begin
        $dumpfile("accumalator.vcd");
        $dumpvars(0, accumalator);
        #1;
    end
`endif

endmodule
