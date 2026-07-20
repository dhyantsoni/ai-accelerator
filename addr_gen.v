// address sequencer for SRAMs. load_i -> base, += stride on each enable.
// sky130 macro has 1-cycle read latency: rdata for this cycle's address
// arrives next cycle. en_i is registered into rd_valid_o, so when
// rd_valid_o is high, rdata corresponds to the address issued last cycle.
// baked in on purpose so upstream FSM doesn't need to account for it.
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
