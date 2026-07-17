module pe #(
    parameter DATA_WIDTH = 4,
    parameter ACC_WIDTH = 2*DATA_WIDTH + 4
) (
    input wire [0:0] clk_i, // clock
    input wire [0:0] rst_i, // reset
    input wire [0:0] load_w_i, // used to latch on a new weight
    input wire [DATA_WIDTH-1:0] w_i, // originally b_i, now w_i repesenting weight to load
    input wire [0:0] start_i, // kick off one shift-add multiply
    input wire [DATA_WIDTH-1:0] act_i, // activation in from the LEFT side neighbor (was a_i) (multiplier)
    input wire [ACC_WIDTH-1:0] psum_i, // partial sum in from the PE ABOVE
    output reg [DATA_WIDTH-1:0] act_o, // activation out to the RIGHT side neighbor
    output reg [ACC_WIDTH-1:0] psum_o, // partial sum out to the PE BELOW (was c_o)
    output reg [0:0] done_o // pulses when this step's result lands on psum_o/act_o
);
    // stationary weight (loaded at every high of load_w_i)
    reg [DATA_WIDTH-1:0] w_q;

    always @(posedge clk_i) begin
        if (rst_i)
            w_q <= {DATA_WIDTH{1'b0}};
        else if (load_w_i)
            w_q <= w_i;
    end

    // Signed multiply, but not with "*". the stored weight and incoming activation
    // go to a shift-add multiplier that does one bit per clock over DATA_WIDTH
    // cycles this brings the shift-add loop back, now spread over cycles
    wire signed [2*DATA_WIDTH-1:0] product;
    wire mult_done;
    shift_add_mult #(.DATA_WIDTH(DATA_WIDTH)) u_mult (
        .clk_i(clk_i), .rst_i(rst_i), .start_i(start_i),
        .a_i(w_q), .b_i(act_i),
        .product_o(product), .busy_o(), .done_o(mult_done)
    );

    // Sign-extend the product up to ACC_WIDTH before adding into the partial sum.
    // psum is treated as signed all the way down the column.
    wire signed [ACC_WIDTH-1:0] product_ext =
        {{(ACC_WIDTH-2*DATA_WIDTH){product[2*DATA_WIDTH-1]}}, product};

    wire signed [ACC_WIDTH-1:0] psum_s = psum_i;

    // big change here from mac.v
    // accumulation is not self contained in the module but rather contained by column of the systolic array
    always @(posedge clk_i) begin
        if (rst_i) begin
            act_o  <= {DATA_WIDTH{1'b0}};
            psum_o <= {ACC_WIDTH{1'b0}};
            done_o <= 1'b0;
        end else begin
            done_o <= 1'b0; // one-cycle pulse
            if (mult_done) begin
                act_o  <= act_i; // forward activation right, 1-cycle delay
                psum_o <= psum_s + product_ext;   // add my product to the incoming sum, pass down
                done_o <= 1'b1;
            end
        end
    end

`ifdef COCOTB_SIM
    initial begin
    $dumpfile ("pe.vcd");
    $dumpvars (0, pe);
    #1;
    end
    `endif

endmodule
