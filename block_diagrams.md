# Block Diagrams

## PE Unit

- The main functional unit of an AI accelerator
- Look at mac.v, this was the starting point for the PE unit

Block diagram: [PE](https://drive.google.com/file/d/1_0RGloJ3rkyu87viL_k1TscjuxNxwspw/view?usp=sharing)

## Systolic Array 
- This is what connects all the PE units together

Block diagram: [Systolic Array](https://drive.google.com/file/d/1gX0ZXrZ7IqKfoExGiVN-6u5UVnYSWcoF/view?usp=sharing)

## Skew buffer 
- Essentially uses a clock to stagnate the inputs so that each line accumlates
- Here is what it looks like (i will try my best )

```
B   ^ ^ ^ ^ ^ ^
U     ^ ^ ^ ^ ^
F       ^ ^ ^ ^
F         ^ ^ ^
E           ^ ^
R             ^
```

Block diagram: [Skew Buffer](https://drive.google.com/file/d/1yCY5LFB-YURFfUKiLkMdQnbfUh0XhYHy/view?usp=sharing)

## Accumalator
- Every column has this accumlator 
- Sign extension occurs here as well to make the weighted stuff work

Block diagram: [Accumlator](https://drive.google.com/file/d/1hdjqNlpVDT8pzFkOia7M-QiQGwncftGq/view?usp=sharing)

## Requantize
- The whole thing is doing INT32 to INT8
- This is so that layer 2-3-4 can accept INT8

Block diagram: [Requantize](https://drive.google.com/file/d/1vrBPTA9lsryj5UNcmvj1z-aXxtL1lz2K/view?usp=sharing)

## Activation
- Relu activation unit
- Super simple

Block diagram: [Activation](https://drive.google.com/file/d/1u6FH8gsHxTtDRPeuvKutmbxKYowsdN01/view?usp=sharing)
