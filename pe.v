module pe #(
    parameter DATA_WIDTH = 4,
    parameter ACCUMULATOR_WIDTH = 2*DATA_WIDTH + 4
) (
    input wire [0:0] clk_i,             // clock
    input wire [0:0] rst_i,             // reset
    input wire [0:0] load_w_i,          // used to latch on a new weight
    input wire [DATA_WIDTH-1:0] w_i,    // originally b_i, now w_i repesenting weight to load
    input wire [DATA_WIDTH-1:0] act_i,  // activation in from the LEFT side neighbor (was a_i) (multiplier)
    input wire [ACC_WIDTH-1:0] psum_i,  // partial sum in from the PE ABOVE
    output reg [DATA_WIDTH-1:0] act_o,  // activation out to the RIGHT side neighbor
    output reg [ACC_WIDTH-1:0] psum_o   // partial sum out to the PE BELOW (was c_o)
);
    // stationary weight (loaded at every high of load_w_i)
    reg [DATA_WIDTH-1:0] w_q;

    always @(posedge clk_i) begin
        if (rst_i)
            w_q <= {DATA_WIDTH{1'b0}};
        else if (load_w_i)
            w_q <= w_i;
    end

    wire [2*DATA_WIDTH-1:0] intermediate_product [DATA_WIDTH-1:0];
    
    // all this does is allow for parameterized DATA_WIDTH, act_i[0->DATA_WIDTH] basically
    genvar g;
    generate
        for (g = 0; g < DATA_WIDTH; g = g + 1) begin : add_loop
            assign intermediate_product[g] = act_i[g] ? ({{DATA_WIDTH{1'b0}}, w_q} << g) : {2*DATA_WIDTH{1'b0}};
        end
    endgenerate                                                                                                
    
    // adds up the intermediate_product into product register
    reg [2*DATA_WIDTH-1:0] product;
    integer i;
    always @(*) begin
        product = {(2*DATA_WIDTH){1'b0}};
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin
            product = product + intermediate_product[i];
        end
    end

    // big change here from mac.v
    // accumulation is not self contained in the module but rather contained by column of the systolic array
    always @(posedge clk_i) begin
        if (rst_i) begin
            act_o  <= {DATA_WIDTH{1'b0}};
            psum_o <= {ACC_WIDTH{1'b0}};
        end else begin
            act_o  <= act_i;              // forward activation right, 1-cycle delay
            psum_o <= psum_i + product;   // add my product to the incoming sum, pass down
        end
    end

`ifdef COCOTB_SIM
    initial begin
    $dumpfile ("mac.vcd");
    $dumpvars (0, mac);
    #1;
    end
    `endif

endmodule
