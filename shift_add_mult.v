// shift_add_mult.v
// signed shift-add multiplier: one multiplier bit per clock over DATA_WIDTH
// cycles, single reused adder. signed by SUBTRACTing (not adding) on the top
// sign bit. pulse start_i; done_o pulses when product_o is valid.

module shift_add_mult #(
    parameter DATA_WIDTH = 4,
    parameter PROD_WIDTH = 2*DATA_WIDTH
) (
    input wire [0:0] clk_i,
    input wire [0:0] rst_i,
    input wire [0:0] start_i,
    input wire signed [DATA_WIDTH-1:0] a_i, // multiplicand (weight)
    input wire signed [DATA_WIDTH-1:0] b_i, // multiplier (activation)
    output wire signed [PROD_WIDTH-1:0] product_o,
    output reg [0:0] busy_o,
    output reg [0:0] done_o
);
    localparam CW = $clog2(DATA_WIDTH+1);

    reg signed [PROD_WIDTH-1:0] acc; // running product
    reg signed [PROD_WIDTH-1:0] mcand; // a_i sign-extended, shifted left each step
    reg [DATA_WIDTH-1:0] mplier; // b_i, shifted right each step
    reg [CW-1:0] count;

    wire last = (count == DATA_WIDTH-1); // sign-bit step: subtract

    always @(posedge clk_i) begin
        if (rst_i) begin
            acc <= 0; mcand <= 0; mplier <= 0; count <= 0;
            busy_o <= 1'b0; done_o <= 1'b0;
        end else begin
            done_o <= 1'b0;
            if (start_i && !busy_o) begin
                acc <= 0;
                mcand <= {{DATA_WIDTH{a_i[DATA_WIDTH-1]}}, a_i}; // sign-extend
                mplier <= b_i;
                count <= 0;
                busy_o <= 1'b1;
            end else if (busy_o) begin
                if (mplier[0])
                    acc <= last ? (acc - mcand) : (acc + mcand);
                mcand <= mcand << 1;
                mplier <= mplier >> 1;
                count <= count + 1'b1;
                if (last) begin
                    busy_o <= 1'b0;
                    done_o <= 1'b1;
                end
            end
        end
    end

    assign product_o = acc;

`ifdef COCOTB_SIM
    initial begin
        $dumpfile("shift_add_mult.vcd");
        $dumpvars(0, shift_add_mult);
        #1;
    end
`endif

endmodule
