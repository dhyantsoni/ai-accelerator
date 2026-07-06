module mac #(
    parameter DATA_WIDTH = 4
) (
    input wire [0:0] s_i,
    input wire [DATA_WIDTH-1:0] a_i,
    input wire [DATA_WIDTH-1:0] b_i,
    input wire [0:0] clk_i,
    output [2*DATA_WIDTH-1:0] c_o
);
    wire [3:0] intermediate_c [DATA_WIDTH-1:0]
    genvar i; 
    generate
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin : add_loop
            assign intermediate_c[i] = a_i[i] ? ({{DATA_WIDTH{1'b0}}, b_i}) : {2*DATA_WIDTH{1'b0}}
        end
    endgenerate

    integer i;

    always @(*) begin
        c_o = DATA_WIDTH{1'b0};
        for (i = 0; i < 8; i = i + 1) begin
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