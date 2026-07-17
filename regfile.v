// host-writable config for one layer. the UART puts bytes in here by address;
// the datapath just reads the fields it needs off the named outputs.
module regfile #(
    parameter AW = 4 // 16 byte registers
)(
    input wire clk_i,
    input wire rst_i,
    input wire we_i, // host write strobe (one byte)
    input wire [AW-1:0] waddr_i,
    input wire [7:0] wdata_i,
    // decoded config fields
    output wire cfg_start, // reg0 bit0: kick a run
    output wire cfg_bypass, // reg0 bit1: 1=pass-through, 0=relu
    output wire [7:0] cfg_total_tiles, // reg1: K tiles to accumulate
    output wire [15:0] cfg_scale, // reg2..3: requantize scale
    output wire [4:0] cfg_shift, // reg4: requantize right shift
    output wire [31:0] cfg_bias // reg5..8: bias (broadcast to columns)
);
    reg [7:0] regs [0:(1<<AW)-1];
    integer i;

    always @(posedge clk_i) begin
        if (rst_i) begin
            for (i = 0; i < (1<<AW); i = i + 1) regs[i] <= 8'd0;
        end else if (we_i) begin
            regs[waddr_i] <= wdata_i;
        end
    end

    // address map (little-endian for the multi-byte fields)
    assign cfg_start = regs[0][0];
    assign cfg_bypass = regs[0][1];
    assign cfg_total_tiles = regs[1];
    assign cfg_scale = {regs[3], regs[2]};
    assign cfg_shift = regs[4][4:0];
    assign cfg_bias = {regs[8], regs[7], regs[6], regs[5]};

`ifdef COCOTB_SIM
    initial begin
        $dumpfile("regfile.vcd");
        $dumpvars(0, regfile);
        #1;
    end
`endif

endmodule
