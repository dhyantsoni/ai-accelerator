module mac #(
    parameter DATA_WIDTH = 4,
    parameter ACCUMULATOR_WIDTH = 2*DATA_WIDTH + 4
) (
    input wire [0:0] s_i,              // control signal for accumulation
    input wire [DATA_WIDTH-1:0] a_i,   // multiplier
    input wire [DATA_WIDTH-1:0] b_i,   // multiplicant
    input wire [0:0] clk_i,            // clock signal
    output reg [ACCUMULATOR_WIDTH-1:0] c_o  // output product
);
    wire [2*DATA_WIDTH-1:0] intermediate_product [DATA_WIDTH-1:0];

    // original hardwired for a 4-bit mac unit
    // assign c_o = (a_i[0] ? ({{DATA_WIDTH{1'b0}}, b_i}) : {2*DATA_WIDTH{1'b0}}) +
    //             (a_i[1] ? ({{DATA_WIDTH{1'b0}}, b_i} << 1) : {2*DATA_WIDTH{1'b0}}) +
    //             (a_i[2] ? ({{DATA_WIDTH{1'b0}}, b_i} << 2) : {2*DATA_WIDTH{1'b0}}) +
    //             (a_i[3] ? ({{DATA_WIDTH{1'b0}}, b_i} << 3) : {2*DATA_WIDTH{1'b0}});

    // all this does is allow for parameterized DATA_WIDTH, a_i[0-DATA_WIDTH] basically
    genvar g; 
    generate
        for (g = 0; g < DATA_WIDTH; g = g + 1) begin : add_loop
            assign intermediate_product[g] = a_i[g] ? ({{DATA_WIDTH{1'b0}}, b_i} << g) : {2*DATA_WIDTH{1'b0}}; // shifter 
        end                                                                                                    // shift by the number of iteration if 1
    endgenerate                                                                                                // do not need to shift if 0

    // adds up the intermediate_product into product register
    reg [2*DATA_WIDTH-1:0] product;
    integer i;
    always @(*) begin
        product = {(2*DATA_WIDTH){1'b0}};
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin
            product = product + intermediate_product[i];
        end
    end

    // accumulation occurs here
    always @(posedge clk_i) begin
        if (s_i)
            c_o <= product; // start a fresh accumulation
        else
            c_o <= c_o + product; // add into running sum
    end

`ifdef COCOTB_SIM
    initial begin
    $dumpfile ("mac.vcd");
    $dumpvars (0, mac);
    #1;
    end
    `endif

endmodule
