// top
// host talks over UART (config in, results out); weights/acts come in on a wide host-write port into the SRAMs.
// datapath is: weight/act buffers -> skew -> systolic array -> accumalator -> requantize -> activation -> output buffer. controller + tile_counter drive it.
// Sized for a 4x4 INT8 array: a full weight tile is 4*4*8 = 128 bits = exactly
// one SRAM word, and one activation vector is 4*8 = 32 bits (low lanes of a word).
module top #(
    parameter DW = 8,
    parameter N = 4,
    parameter PW = 20, // array partial-sum width (= systolic_array ACC_WIDTH)
    parameter ACC = 32, // accumulator running-total width
    parameter SW = 16 // requantize scale width
)(
    input wire clk_i,
    input wire rst_i,
    // host UART
    input wire rx_i, // config bytes in
    output wire tx_o, // result bytes out
    // host bulk write: weights and activations into the SRAMs
    input wire w_we_i,
    input wire [7:0] w_addr_i,
    input wire [127:0] w_wdata_i,
    input wire a_we_i,
    input wire [7:0] a_addr_i,
    input wire [127:0] a_wdata_i,
    // status
    output wire busy_o,
    output wire done_o
);
    // config: UART RX writes regfile as (addr, data) pairs
    // host sends a register address byte, then its data byte. lets start (reg0)
    // be written LAST, after total_tiles/scale/etc are already in place.
    wire [7:0] rx_byte; wire rx_valid;
    uart_rx #(.CLKS_PER_BIT(16)) u_rx (
        .clk_i(clk_i), .rst_i(rst_i), .rx_i(rx_i), .data_o(rx_byte), .valid_o(rx_valid));

    reg cfg_phase; // 0 = next byte is an address, 1 = next byte is data
    reg [3:0] cfg_addr;
    always @(posedge clk_i) begin
        if (rst_i) cfg_phase <= 1'b0;
        else if (rx_valid) begin
            if (!cfg_phase) cfg_addr <= rx_byte[3:0];
            cfg_phase <= ~cfg_phase;
        end
    end
    wire cfg_we = rx_valid & cfg_phase; // commit on the data byte

    wire cfg_start, cfg_bypass;
    wire [7:0] cfg_total_tiles;
    wire [SW-1:0] cfg_scale;
    wire [4:0] cfg_shift;
    wire [31:0] cfg_bias;
    regfile #(.AW(4)) u_regs (
        .clk_i(clk_i), .rst_i(rst_i),
        .we_i(cfg_we), .waddr_i(cfg_addr), .wdata_i(rx_byte),
        .cfg_start(cfg_start), .cfg_bypass(cfg_bypass),
        .cfg_total_tiles(cfg_total_tiles), .cfg_scale(cfg_scale),
        .cfg_shift(cfg_shift), .cfg_bias(cfg_bias));

    // control: FSM + tile counter
    wire w_load, a_load, compute_en, acc_valid, tile_step, store_en;
    wire first_tile, last_tile, tile_done;
    wire [7:0] k_tile, tile_row, tile_col;

    controller #(.LOAD_CYCLES(N), .COMPUTE_CYC((2*N + 10) * (DW + 4)), .STORE_CYC(N)) u_ctrl (
        .clk_i(clk_i), .rst_i(rst_i), .start_i(cfg_start), .last_tile_i(last_tile),
        .w_load(w_load), .a_load(a_load), .compute_en(compute_en),
        .acc_valid(acc_valid), .tile_step(tile_step), .store_en(store_en),
        .busy(busy_o), .done(done_o));

    tile_counter #(.NROW(N), .NCOL(N), .CW(8)) u_tc (
        .clk_i(clk_i), .rst_i(rst_i), .step_i(tile_step), .total_tiles_i(cfg_total_tiles),
        .k_tile(k_tile), .tile_row(tile_row), .tile_col(tile_col),
        .first_tile(first_tile), .last_tile(last_tile), .tile_done(tile_done));

    // read-address gen for the two source SRAMs
    wire [7:0] w_raddr, a_raddr;
    wire w_rvalid, a_rvalid;
    addr_gen #(.AW(8)) u_wag (
        .clk_i(clk_i), .rst_i(rst_i), .en_i(w_load), .load_i(cfg_start),
        .base_i(8'd0), .stride_i(8'd1), .addr_o(w_raddr), .rd_valid_o(w_rvalid));
    addr_gen #(.AW(8)) u_aag (
        .clk_i(clk_i), .rst_i(rst_i), .en_i(a_load), .load_i(cfg_start),
        .base_i(8'd0), .stride_i(8'd1), .addr_o(a_raddr), .rd_valid_o(a_rvalid));

    // source SRAMs (128-bit words)
    wire [127:0] w_word, a_word;
    weight_buffer u_wbuf (
        .clk(clk_i), .we(w_we_i), .waddr(w_addr_i), .wdata(w_wdata_i), .wmask(16'hFFFF),
        .re(w_load), .raddr(w_raddr), .rdata(w_word));
    act_buffer u_abuf (
        .clk(clk_i), .we(a_we_i), .waddr(a_addr_i), .wdata(a_wdata_i), .wmask(16'hFFFF),
        .re(a_load), .raddr(a_raddr), .rdata(a_word));

    // register+hold each SRAM word on its rd_valid (and load the array a cycle later) so the datapath sees defined, held data honoring the macro's 1-cycle read latency
    reg [127:0] w_word_q, a_word_q;
    reg w_loaded;
    always @(posedge clk_i) begin
        if (rst_i) begin w_word_q <= 128'd0; a_word_q <= 128'd0; w_loaded <= 1'b0; end
        else begin
            if (w_rvalid) w_word_q <= w_word;
            if (a_rvalid) a_word_q <= a_word;
            w_loaded <= w_rvalid;
        end
    end

    // skew + systolic array
    // one 128-bit weight word IS the whole 4x4 tile; low 32 bits of an act word
    // are this tile's activation vector.
    wire [DW*N-1:0] act_skewed;
    act_skew #(.DATA_WIDTH(DW), .ROWS(N)) u_skew (
        .clk_i(clk_i), .rst_i(rst_i),
        .act_i_flat(a_word_q[DW*N-1:0]), .act_o_flat(act_skewed));

    wire [PW*N-1:0] psum_bot;
    systolic_array #(.DATA_WIDTH(DW), .ACC_WIDTH(PW), .ROWS(N), .COLS(N)) u_array (
        .clk_i(clk_i), .rst_i(rst_i),
        .load_w_i(w_loaded),
        .w_i_flat(w_word_q[DW*N*N-1:0]),
        .act_i_flat(act_skewed),
        .psum_o_flat(psum_bot));

    // accumulate across K tiles
    wire [ACC*N-1:0] acc_flat;
    wire acc_valid_o;
    wire [ACC*N-1:0] bias_flat = {N{cfg_bias}}; // broadcast the scalar bias to columns
    accumalator #(.COLS(N), .PSUM_WIDTH(PW), .ACC_WIDTH(ACC)) u_acc (
        .clk_i(clk_i), .rst_i(rst_i),
        .psum_i_flat(psum_bot), .valid_i(acc_valid),
        .first_tile_i(first_tile), .last_tile_i(last_tile),
        .bias_i_flat(bias_flat), .acc_o_flat(acc_flat), .acc_valid_o(acc_valid_o));

    // requantize INT32 -> INT8
    wire [DW*N-1:0] q_flat;
    wire q_valid;
    requantize #(.COLS(N), .ACC_WIDTH(ACC), .OUT_WIDTH(DW), .MULT_WIDTH(SW)) u_rq (
        .clk_i(clk_i), .rst_i(rst_i),
        .acc_i_flat(acc_flat), .valid_i(acc_valid_o),
        .scale_i(cfg_scale), .shift_i(cfg_shift),
        .q_o_flat(q_flat), .valid_o(q_valid));

    // activation (relu / bypass)
    wire [DW*N-1:0] act_out;
    wire act_valid;
    activation #(.COLS(N), .WIDTH(DW)) u_act (
        .clk_i(clk_i), .rst_i(rst_i),
        .d_i_flat(q_flat), .valid_i(q_valid), .bypass_i(cfg_bypass),
        .d_o_flat(act_out), .valid_o(act_valid));

    // store results into the output buffer
    reg [7:0] store_idx;
    always @(posedge clk_i) begin
        if (rst_i) store_idx <= 8'd0;
        else if (store_en) store_idx <= store_idx + 1'b1;
    end

    output_buffer u_obuf (
        .clk(clk_i),
        .we(store_en), .waddr(store_idx),
        .wdata({{(128-DW*N){1'b0}}, act_out}), // N INT8 results in the low lanes
        .wmask(16'hFFFF),
        .re(1'b0), .raddr(8'd0), .rdata());

    // result readback over UART TX (stub streamer)
    // real host would clock out output_buffer here; left un-driven so top stays
    // synthesizable and self-contained. tie TX idle-high for now.
    wire tx_busy;
    uart_tx #(.CLKS_PER_BIT(16)) u_tx (
        .clk_i(clk_i), .rst_i(rst_i), .start_i(1'b0), .data_i(8'd0),
        .tx_o(tx_o), .busy_o(tx_busy));

`ifdef COCOTB_SIM
    initial begin
        $dumpfile("top.vcd");
        $dumpvars(0, top);
        #1;
    end
`endif

endmodule
