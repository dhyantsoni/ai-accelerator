// This module should basically do the following
// 1. Access the memory (input)
// 2. Take that input vector and then kind of stagnate it

module act_skew #(
    parameter DATA_WIDTH = 8,
    parameter ROWS       = 4
)(
    input wire clk_i,
    input wire rst_i,
    input [DATA_WIDTH*ROWS-1:0] wire act_i_flat,
    output [DATA_WIDTH*ROWS-1:0] wire act_o_flat
){
    reg [DATA_WIDTH-1:0] delay_line [0:ROWS-1][0:ROWS-1];

    integer r, d;
    always @(posedge clk_i) begin
        if (rst_i) begin
            for (r = 0; r < ROWS; r = r + 1)
                for (d = 0; d < ROWS; d = d + 1)
                    delay_line[r][d] <= {DATA_WIDTH{1'b0}}; // creating the delay line "waiting spots" for all the spots in the array
        end else begin
            for (r = 0; r < ROWS; r = r + 1) begin
                for (d = 0; d < ROWS; d = d + 1) begin
                    if (d < r) begin
                        // stage 0 takes this row's flat input; later stages
                        // shift from the previous stage (the shift register)
                        if (d == 0)
                            delay_line[r][0] <= act_i_flat[r*DATA_WIDTH +: DATA_WIDTH]; // if its the first row, let it go through
                        else
                            delay_line[r][d] <= delay_line[r][d-1]; // else add a delay
                    end
                end
            end
        end
    end
 
    // Output tap: row 0 is combinational passthrough, row r taps the last
    // (r-1) stage of its chain. gr and gr-1 are elaboration-time constants.
    genvar gr;
    generate
        for (gr = 0; gr < ROWS; gr = gr + 1) begin : out_map
            if (gr == 0)
                assign act_o_flat[gr*DATA_WIDTH +: DATA_WIDTH] =
                       act_i_flat[gr*DATA_WIDTH +: DATA_WIDTH];
            else
                assign act_o_flat[gr*DATA_WIDTH +: DATA_WIDTH] =
                       delay_line[gr][gr-1];
        end
    endgenerate
}