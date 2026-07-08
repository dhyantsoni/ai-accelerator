# Shifter

Inputs
1. act_i
2. w_q

Internal wires
1. intermediate_product

Very much an abstraction in the block diagram, however can be easily conceptualized by thinking of the shifter as an adder + actual shifting mechanism

Adder determines how many shifts to perform
1. Based on the DATA_WIDTH paramater act_i is interated through
2. Shifts occur when act_i[g] = 1, the number of shifts depend on the "g" value at act_i[g] = 1
3. If act_i[0] = 1 then it is simply unshifted as g = 0 and is added

Shifter does the shifting
1. Uses padding through the DATA_WIDTH paramater
2. Shifts by g if act_i