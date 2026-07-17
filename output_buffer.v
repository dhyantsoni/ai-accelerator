module output_buffer (
    input wire clk,
    // write port (accelerator results) -> macro Port 0
    input wire we, // active-HIGH write enable
    input wire [7:0] waddr, // 0..255
    input wire [127:0] wdata, // 16 INT8 result lanes
    input wire [15:0] wmask, // per-lane; 16'hFFFF = full word
    // read port (host reads results back) -> macro Port 1
    input wire re, // active-HIGH read enable
    input wire [7:0] raddr,
    output wire [127:0] rdata // VALID ONE CYCLE AFTER raddr
);
    sky130_sram_1rw1r_128x256_8 u_sram (
        .clk0 (clk),
        .csb0 (~we), // 0 = selected when accelerator writes
        .web0 (1'b0), // 0 = write (only matters when csb0==0)
        .wmask0(wmask),
        .addr0 (waddr),
        .din0 (wdata),
        .dout0 (), // unused — this instance never reads on port 0
        .clk1 (clk),
        .csb1 (~re), // 0 = selected when host reads
        .addr1 (raddr),
        .dout1 (rdata)
    );
endmodule
