# Weight Updater

Inputs 
1. rst_i -- the reset
2. load_w_i -- the control signal for weight updates
3. w_i -- input weight
4. clk_i

Internal wires
1. w_q -- holds the value of w_i (this is how the stationary weight dataflow system works)

On a high from the rst: w_q is initalized as 0
On a low from the rst & a high from load_w_i: w_q is initalized as w_i