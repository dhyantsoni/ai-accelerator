module pe #(
    parameter DATA_WIDTH = 4,
    parameter ACC_WIDTH = 2*DATA_WIDTH + 4
) (
    input wire [0:0] clk_i, // clock
    input wire [0:0] rst_i, // reset
    input wire [0:0] load_w_i, // used to latch on a new weight
    input wire [DATA_WIDTH-1:0] w_i, // originally b_i, now w_i repesenting weight to load
    input wire [DATA_WIDTH-1:0] act_i, // activation in from the LEFT side neighbor (was a_i) (multiplier)
    input wire [ACC_WIDTH-1:0] psum_i, // partial sum in from the PE ABOVE
    output reg [DATA_WIDTH-1:0] act_o, // activation out to the RIGHT side neighbor
    output reg [ACC_WIDTH-1:0] psum_o // partial sum out to the PE BELOW (was c_o)
);
    // stationary weight (loaded at every high of load_w_i)
    reg [DATA_WIDTH-1:0] w_q;

    always @(posedge clk_i) begin
        if (rst_i)
            w_q <= {DATA_WIDTH{1'b0}};
        else if (load_w_i)
            w_q <= w_i;
    end
    
    // SIGNED multiply. re-interpret the stored weight and incoming activation
    // as signed two's complement, multiply, and let the result be a signed
    // 2*DATA_WIDTH product this replaces the old unsigned shift-add loop
    wire signed [DATA_WIDTH-1:0]   w_s   = w_q;
    wire signed [DATA_WIDTH-1:0]   act_s = act_i;
    wire signed [2*DATA_WIDTH-1:0] product = w_s * act_s;
 
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
        end else begin
            act_o  <= act_i; // forward activation right, 1-cycle delay
            psum_o <= psum_s + product_ext;   // add my product to the incoming sum, pass down
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
