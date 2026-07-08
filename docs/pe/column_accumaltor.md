# Column Accumulator

Inputs
1. clk_i
2. rst_i
3. product

If rst_i is high act_o = 0 & psum_o = 0
If rst_i is low
1. act_o = act_i performing forward activation
2. psum_o = psum_i + product performing the downwards sum