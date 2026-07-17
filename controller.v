// main sequencer: idle -> load_w -> load_a -> compute -> accum -> (loop or store) -> done.
// its whole job is generating the strobes the datapath testbench faked by hand.
// the accum->load_w loop is the K accumulation: one pass per K tile, piling into
// the accumulator, until tile_counter says last_tile; then store the result.
// phase lengths are parameters so they can be retuned for a given array/tiling.
module controller #(
    parameter LOAD_CYCLES = 4, // cycles to stream weights / activations
    parameter COMPUTE_CYC = 3*3 + 8, // fill + drain of the array (macro-stepped)
    parameter STORE_CYC = 4 // cycles to drain results to the output buffer
)(
    input wire clk_i,
    input wire rst_i,
    input wire start_i,
    input wire last_tile_i, // from tile_counter: this K tile is the last
    output reg w_load, // stream weights into the array
    output reg a_load, // stream activations
    output reg compute_en, // let the array settle
    output reg acc_valid, // pulse: latch this tile's psum into the accumulator
    output reg tile_step, // pulse: advance tile_counter to the next K tile
    output reg store_en, // drain the accumulator column to the output buffer
    output reg busy,
    output reg done
);
    localparam [2:0] S_IDLE = 3'd0,
                     S_LOAD_W = 3'd1,
                     S_LOAD_A = 3'd2,
                     S_COMPUTE = 3'd3,
                     S_ACCUM = 3'd4,
                     S_STORE = 3'd5,
                     S_DONE = 3'd6;

    reg [2:0] state;
    reg [15:0] cnt;

    always @(posedge clk_i) begin
        if (rst_i) begin
            state <= S_IDLE;
            cnt <= 16'd0;
        end else begin
            case (state)
                S_IDLE: begin cnt <= 0; if (start_i) state <= S_LOAD_W; end
                S_LOAD_W: if (cnt == LOAD_CYCLES-1) begin cnt <= 0; state <= S_LOAD_A; end else cnt <= cnt + 1'b1;
                S_LOAD_A: if (cnt == LOAD_CYCLES-1) begin cnt <= 0; state <= S_COMPUTE; end else cnt <= cnt + 1'b1;
                S_COMPUTE: if (cnt == COMPUTE_CYC-1) begin cnt <= 0; state <= S_ACCUM; end else cnt <= cnt + 1'b1;
                // one cycle: latch the partial sum and step the tile. last tile -> store,
                // otherwise loop back and grab the next K slice of weights/acts.
                S_ACCUM: state <= last_tile_i ? S_STORE : S_LOAD_W;
                S_STORE: if (cnt == STORE_CYC-1) begin cnt <= 0; state <= S_DONE; end else cnt <= cnt + 1'b1;
                S_DONE: if (!start_i) state <= S_IDLE;
                default: state <= S_IDLE;
            endcase
        end
    end

    // outputs are a pure function of state (Moore)
    always @(*) begin
        w_load = (state == S_LOAD_W);
        a_load = (state == S_LOAD_A);
        compute_en = (state == S_COMPUTE);
        acc_valid = (state == S_ACCUM);
        tile_step = (state == S_ACCUM);
        store_en = (state == S_STORE);
        busy = (state != S_IDLE) && (state != S_DONE);
        done = (state == S_DONE);
    end

`ifdef COCOTB_SIM
    initial begin
        $dumpfile("controller.vcd");
        $dumpvars(0, controller);
        #1;
    end
`endif

endmodule
