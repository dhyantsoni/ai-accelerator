module systolic_array #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 20,
    parameter ROWS       = 3,
    parameter COLS       = 3
) (
    input wire clk_i,
    input wire rst_i,
    input wire load_w_i,   // pulse to load all weights at once
    input wire [DATA_WIDTH*ROWS*COLS-1:0] w_i_flat,   // weight per PE, index = r*COLS + c
    input wire [DATA_WIDTH*ROWS-1:0] act_i_flat, // one activation per row (left edge)
    output wire [ACC_WIDTH*COLS-1:0] psum_o_flat // one result per column (bottom edge)
);

    // interal buse, each of them is one bigger than the PE count in the flow
    // direction gives clean edge wires to hook up as inputs/outputs.
    wire [DATA_WIDTH-1:0] act_h  [0:ROWS-1][0:COLS];   // horizontal activation, act_h[r][c] feeds PE[r][c]
    wire [ACC_WIDTH-1:0]  psum_v [0:ROWS][0:COLS-1];   // vertical partial sum, psum_v[r][c] feeds PE[r][c]
    wire pe_done [0:ROWS-1][0:COLS-1];  // every PE finishes its multiply together

    // PEs are multi-cycle now: pulse start,
    // wait for a PE to finish, start the next wave. one PE's done stands in for all.
    reg step_start, running;
    wire step_done = pe_done[0][0];
    always @(posedge clk_i) begin
        if (rst_i) begin
            running <= 1'b0; step_start <= 1'b0;
        end else begin
            step_start <= 1'b0;
            if (!running)       begin step_start <= 1'b1; running <= 1'b1; end
            else if (step_done) running <= 1'b0;
        end
    end

    genvar r, c;
    generate
        // LEFT edge in: each row's activation input drives that row's first PE
        for (r = 0; r < ROWS; r = r + 1) begin : left_edge
            assign act_h[r][0] = act_i_flat[r*DATA_WIDTH +: DATA_WIDTH];
        end

        // TOP edge in: every column starts its accumulation at 0
        for (c = 0; c < COLS; c = c + 1) begin : top_edge
            assign psum_v[0][c] = {ACC_WIDTH{1'b0}};
        end

        // The PE grid
        for (r = 0; r < ROWS; r = r + 1) begin : grow
            for (c = 0; c < COLS; c = c + 1) begin : gcol
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (ACC_WIDTH)
                ) pe_inst (
                    .clk_i (clk_i),
                    .rst_i (rst_i),
                    .load_w_i(load_w_i),
                    .w_i (w_i_flat[(r*COLS + c)*DATA_WIDTH +: DATA_WIDTH]), // input weight
                    .start_i (step_start),     // same start for every PE
                    .act_i (act_h[r][c]),      // in from the left
                    .psum_i (psum_v[r][c]),    // in from above
                    .act_o (act_h[r][c+1]),    // out to the right
                    .psum_o (psum_v[r+1][c]),  // out below
                    .done_o (pe_done[r][c])
                );
            end
        end

        // BOTTOM edge out: the fully accumulated partial sum for each column
        for (c = 0; c < COLS; c = c + 1) begin : bottom_edge
            assign psum_o_flat[c*ACC_WIDTH +: ACC_WIDTH] = psum_v[ROWS][c];
        end
    endgenerate

`ifdef COCOTB_SIM
    initial begin
        $dumpfile("systolic_array.vcd");
        $dumpvars(0, systolic_array);
        #1;
    end
`endif

endmodule
