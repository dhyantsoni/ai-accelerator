// activation.v
// Applies the activation function after requantize.
// I implemented two options here
// ReLU: out = (x < 0) ? 0 : x
// bypass: out = x (pass straight through)

// FUTURE TODOS (MAYBE): Try to apply a softmax option

module activation #(
    parameter COLS  = 4,
    parameter WIDTH = 8
)(
    input wire clk_i,
    input wire rst_i,
    input wire [WIDTH*COLS-1:0] d_i_flat, // per-column INT8 from requantize
    input wire valid_i,
    input wire bypass_i, // 1 = pass through, 0 = apply ReLU
    output wire [WIDTH*COLS-1:0] d_o_flat, // per-column INT8 out
    output reg valid_o
);
    genvar c;
    generate
        for (c = 0; c < COLS; c = c + 1) begin : col_act
            reg [WIDTH-1:0] d_q;

            wire [WIDTH-1:0] d_c  = d_i_flat[c*WIDTH +: WIDTH];
            // sign bit set -> negative -> ReLU forces 0
            wire [WIDTH-1:0] relu = d_c[WIDTH-1] ? {WIDTH{1'b0}} : d_c;

            always @(posedge clk_i) begin
                if (rst_i)
                    d_q <= {WIDTH{1'b0}};
                else if (valid_i)
                    d_q <= bypass_i ? d_c : relu;
            end

            assign d_o_flat[c*WIDTH +: WIDTH] = d_q;
        end
    endgenerate

    always @(posedge clk_i) begin
        if (rst_i) valid_o <= 1'b0;
        else       valid_o <= valid_i;
    end

`ifdef COCOTB_SIM
    initial begin
        $dumpfile("activation.vcd");
        $dumpvars(0, activation);
        #1;
    end
`endif

endmodule