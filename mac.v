module mac #(
    parameter DATA_WIDTH = 4
) (
    input wire [0:0] s_i,             // control signal
    input wire [DATA_WIDTH-1:0] a_i,  // multiplier
    input wire [DATA_WIDTH-1:0] b_i,  // multiplicant
    input wire [0:0] clk_i,           // clock signal
    output [2*DATA_WIDTH-1:0] c_o     // output product
);
    wire [2*DATA_WIDTH-1:0] intermediate_c [DATA_WIDTH-1:0];
    genvar i; 
    generate
        for (g = 0; g < DATA_WIDTH; g = g + 1) begin : add_loop
            assign intermediate_c[g] = a_i[g] ? ({{DATA_WIDTH{1'b0}}, b_i}) : {2*DATA_WIDTH{1'b0}}
        end
    endgenerate

    integer i;
    always @(*) begin
        c_o = {(2*DATA_WIDTH){1'b0}};
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin
            c_o = c_o + intermediate_c[i];
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