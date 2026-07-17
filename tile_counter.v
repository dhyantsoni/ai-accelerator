// walks the tiles of a matmul. k_tile counts the K (accumulation) tiles that
// pile into one output tile; first_tile/last_tile mark its ends so accumalator
// knows when to load bias and when the running total is final. when a K-sweep
// finishes we step the output tile position (col, then row).
module tile_counter #(
    parameter NROW = 4, // output tile grid rows
    parameter NCOL = 4, // output tile grid cols
    parameter CW = 8
)(
    input wire clk_i,
    input wire rst_i,
    input wire step_i, // advance one K tile
    input wire [CW-1:0] total_tiles_i, // K tiles per output tile (>=1)
    output reg [CW-1:0] k_tile, // current K tile, 0..total-1
    output reg [CW-1:0] tile_row, // output tile row
    output reg [CW-1:0] tile_col, // output tile col
    output wire first_tile, // k_tile == 0 -> accumalator loads bias
    output wire last_tile, // k_tile == total-1 -> total is done after this
    output wire tile_done // the step that closes a K-sweep
);
    assign first_tile = (k_tile == {CW{1'b0}});
    assign last_tile = (k_tile == total_tiles_i - 1'b1);
    assign tile_done = step_i & last_tile;

    wire col_max = (tile_col == NCOL-1);
    wire row_max = (tile_row == NROW-1);

    always @(posedge clk_i) begin
        if (rst_i) begin
            k_tile <= {CW{1'b0}};
            tile_row <= {CW{1'b0}};
            tile_col <= {CW{1'b0}};
        end else if (step_i) begin
            if (last_tile) begin
                k_tile <= {CW{1'b0}}; // restart K for the next output tile
                if (col_max) begin
                    tile_col <= {CW{1'b0}};
                    tile_row <= row_max ? {CW{1'b0}} : tile_row + 1'b1;
                end else begin
                    tile_col <= tile_col + 1'b1;
                end
            end else begin
                k_tile <= k_tile + 1'b1; // keep piling into the same output tile
            end
        end
    end

`ifdef COCOTB_SIM
    initial begin
        $dumpfile("tile_counter.vcd");
        $dumpvars(0, tile_counter);
        #1;
    end
`endif

endmodule
