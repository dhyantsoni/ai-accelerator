// address sequencer for the SRAMs. load_i -> base, then += stride each enable.
// the sky130 macro reads with 1-CYCLE LATENCY: the data for the address we
// drive this cycle lands NEXT cycle. so en_i is registered into rd_valid_o --
// when rd_valid_o is high, rdata belongs to the address issued last cycle.
// this offset is baked in ON PURPOSE so the FSM upstream never has to think
// about it (and so this module is easy to rule out when the FSM misbehaves).
module addr_gen #(
    parameter AW = 8
)(
    input wire clk_i,
    input wire rst_i,
    input wire en_i, // issue the next address
    input wire load_i, // jump to base (priority over en_i)
    input wire [AW-1:0] base_i,
    input wire [AW-1:0] stride_i,
    output reg [AW-1:0] addr_o, // drive this straight into the SRAM
    output reg rd_valid_o // high when SRAM rdata matches the PREVIOUS addr_o
);
    always @(posedge clk_i) begin
        if (rst_i) begin
            addr_o <= {AW{1'b0}};
            rd_valid_o <= 1'b0;
        end else begin
            rd_valid_o <= en_i; // 1-cycle read latency, baked in here
            if (load_i) addr_o <= base_i;
            else if (en_i) addr_o <= addr_o + stride_i;
        end
    end

`ifdef COCOTB_SIM
    initial begin
        $dumpfile("addr_gen.vcd");
        $dumpvars(0, addr_gen);
        #1;
    end
`endif

endmodule
