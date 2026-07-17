# States

### IDLE
- Does nothing
- Waits for start_i

### LOAD_W 
- START OF LOOP
- Gets the K tile's weights and latches onto each PE
- "Stationary" weight system...basically the tiles keep the weights as the activations flow through them
- Keeps running every loop

### LOAD_A
- Pulls the activation from act_buffer which then goes to the act_skew

### COMPUTE
- Computation rolls out across the systolic array

### ACCUM
- Accumlator adds the tile's psum to running total or bias if its the first tile
- Continues the loop until its the last tile
- END OF LOOP (if last tile)

### STORE
- After the accumlator is all done and added up it goes to requantize --> activation --> output buffer

### DONE
- Now everything is in output buffer and waits for the host to pick it up