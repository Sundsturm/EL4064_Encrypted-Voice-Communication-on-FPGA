/*

Any particular permutation of 8 digits from 1 to 8
can be produced by swapping (first number, another number)
10 times, for example

1 2 3 4 5 6 7 8
5 2 3 4 1 6 7 8
4 2 3 5 1 6 7 8
1 2 3 5 4 6 7 8
3 2 1 5 4 6 7 8
6 2 1 5 4 3 7 8
1 2 6 5 4 3 7 8
7 2 6 5 4 3 1 8
2 7 6 5 4 3 1 8
1 7 6 5 4 3 2 8
8 7 6 5 4 3 2 1

as such, the shift_key is ideally 10 x 3 bits in length.

However, we make do with 8 x 3 bits for now. 

Two keys are to be produced for the left and right sides of the FFT.
The left key is produced by continously swapping with the left-most index,
while the right key is produced by continuously swapping with the right-most index.

*/

module GenPermutationKey (
    // input shift key
    input   wire [23:0] shift_key,

    // permutation_key1 is for first 8 samples
    // permutation_key2 is for last 8 samples
    output  wire [23:0] permutation_key1, // left key
    output  wire [23:0] permutation_key2 // right key
);

    wire [23:0] tmpL0, tmpL1, tmpL2, tmpL3, tmpL4, tmpL5, tmpL6, tmpL7;
    wire [23:0] tmpR0, tmpR1, tmpR2, tmpR3, tmpR4, tmpR5, tmpR6, tmpR7;

    // for readability + debugging
    wire [2:0]  k0, k1, k2, k3, k4, k5, k6, k7; 

// number  1
assign k0 = shift_key[23:21];
assign tmpL0 =  (k0 == 'b000) ? {3'd0, 3'd1, 3'd2, 3'd3, 3'd4, 3'd5, 3'd6, 3'd7} :
                (k0 == 'b001) ? {3'd1, 3'd0, 3'd2, 3'd3, 3'd4, 3'd5, 3'd6, 3'd7} :
                (k0 == 'b010) ? {3'd2, 3'd1, 3'd0, 3'd3, 3'd4, 3'd5, 3'd6, 3'd7} :
                (k0 == 'b011) ? {3'd3, 3'd1, 3'd2, 3'd0, 3'd4, 3'd5, 3'd6, 3'd7} :
                (k0 == 'b100) ? {3'd4, 3'd1, 3'd2, 3'd3, 3'd0, 3'd5, 3'd6, 3'd7} :
                (k0 == 'b101) ? {3'd5, 3'd1, 3'd2, 3'd3, 3'd4, 3'd0, 3'd6, 3'd7} :
                (k0 == 'b110) ? {3'd6, 3'd1, 3'd2, 3'd3, 3'd4, 3'd5, 3'd0, 3'd7} :
                (k0 == 'b111) ? {3'd7, 3'd1, 3'd2, 3'd3, 3'd4, 3'd5, 3'd6, 3'd0} :
                                3'bx ;

assign tmpR0 =  (k0 == 'b000) ? {3'd0, 3'd1, 3'd2, 3'd3, 3'd4, 3'd5, 3'd6, 3'd7} :
                (k0 == 'b001) ? {3'd0, 3'd1, 3'd2, 3'd3, 3'd4, 3'd5, 3'd7, 3'd6} :
                (k0 == 'b010) ? {3'd0, 3'd1, 3'd2, 3'd3, 3'd4, 3'd7, 3'd6, 3'd5} :
                (k0 == 'b011) ? {3'd0, 3'd1, 3'd2, 3'd3, 3'd7, 3'd5, 3'd6, 3'd4} :
                (k0 == 'b100) ? {3'd0, 3'd1, 3'd2, 3'd7, 3'd4, 3'd5, 3'd6, 3'd3} :
                (k0 == 'b101) ? {3'd0, 3'd1, 3'd7, 3'd3, 3'd4, 3'd5, 3'd6, 3'd2} :
                (k0 == 'b110) ? {3'd0, 3'd7, 3'd2, 3'd3, 3'd4, 3'd5, 3'd6, 3'd1} :
                (k0 == 'b111) ? {3'd7, 3'd1, 3'd2, 3'd3, 3'd4, 3'd5, 3'd6, 3'd0} :
                                3'bx ;

// number 2
assign k1 = shift_key[20:18];
assign tmpL1 =  (k1 == 'b000) ? {tmpL0[23:21], tmpL0[20:18], tmpL0[17:15], tmpL0[14:12], tmpL0[11:09], tmpL0[08:06], tmpL0[05:03], tmpL0[02:00]} :
                (k1 == 'b001) ? {tmpL0[20:18], tmpL0[23:21], tmpL0[17:15], tmpL0[14:12], tmpL0[11:09], tmpL0[08:06], tmpL0[05:03], tmpL0[02:00]} :
                (k1 == 'b010) ? {tmpL0[17:15], tmpL0[20:18], tmpL0[23:21], tmpL0[14:12], tmpL0[11:09], tmpL0[08:06], tmpL0[05:03], tmpL0[02:00]} :
                (k1 == 'b011) ? {tmpL0[14:12], tmpL0[20:18], tmpL0[17:15], tmpL0[23:21], tmpL0[11:09], tmpL0[08:06], tmpL0[05:03], tmpL0[02:00]} :
                (k1 == 'b100) ? {tmpL0[11:09], tmpL0[20:18], tmpL0[17:15], tmpL0[14:12], tmpL0[23:21], tmpL0[08:06], tmpL0[05:03], tmpL0[02:00]} :
                (k1 == 'b101) ? {tmpL0[08:06], tmpL0[20:18], tmpL0[17:15], tmpL0[14:12], tmpL0[11:09], tmpL0[23:21], tmpL0[05:03], tmpL0[02:00]} :
                (k1 == 'b110) ? {tmpL0[05:03], tmpL0[20:18], tmpL0[17:15], tmpL0[14:12], tmpL0[11:09], tmpL0[08:06], tmpL0[23:21], tmpL0[02:00]} :
                (k1 == 'b111) ? {tmpL0[02:00], tmpL0[20:18], tmpL0[17:15], tmpL0[14:12], tmpL0[11:09], tmpL0[08:06], tmpL0[05:03], tmpL0[23:21]} :
                                3'bx ;

assign tmpR1 =  (k1 == 'b000) ? {tmpR0[23:21], tmpR0[20:18], tmpR0[17:15], tmpR0[14:12], tmpR0[11:09], tmpR0[08:06], tmpR0[05:03], tmpR0[02:00]} :
                (k1 == 'b001) ? {tmpR0[23:21], tmpR0[20:18], tmpR0[17:15], tmpR0[14:12], tmpR0[11:09], tmpR0[08:06], tmpR0[02:00], tmpR0[05:03]} :
                (k1 == 'b010) ? {tmpR0[23:21], tmpR0[20:18], tmpR0[17:15], tmpR0[14:12], tmpR0[11:09], tmpR0[02:00], tmpR0[05:03], tmpR0[08:06]} :
                (k1 == 'b011) ? {tmpR0[23:21], tmpR0[20:18], tmpR0[17:15], tmpR0[14:12], tmpR0[02:00], tmpR0[08:06], tmpR0[05:03], tmpR0[11:09]} :
                (k1 == 'b100) ? {tmpR0[23:21], tmpR0[20:18], tmpR0[17:15], tmpR0[02:00], tmpR0[11:09], tmpR0[08:06], tmpR0[05:03], tmpR0[14:12]} :
                (k1 == 'b101) ? {tmpR0[23:21], tmpR0[20:18], tmpR0[02:00], tmpR0[14:12], tmpR0[11:09], tmpR0[08:06], tmpR0[05:03], tmpR0[17:15]} :
                (k1 == 'b110) ? {tmpR0[23:21], tmpR0[02:00], tmpR0[17:15], tmpR0[14:12], tmpR0[11:09], tmpR0[08:06], tmpR0[05:03], tmpR0[20:18]} :
                (k1 == 'b111) ? {tmpR0[02:00], tmpR0[20:18], tmpR0[17:15], tmpR0[14:12], tmpR0[11:09], tmpR0[08:06], tmpR0[05:03], tmpR0[23:21]} :
                                3'bx ;

// number 3
assign k2 = shift_key[17:15];
assign tmpL2 =  (k2 == 'b000) ? {tmpL1[23:21], tmpL1[20:18], tmpL1[17:15], tmpL1[14:12], tmpL1[11:09], tmpL1[08:06], tmpL1[05:03], tmpL1[02:00]} :
                (k2 == 'b001) ? {tmpL1[20:18], tmpL1[23:21], tmpL1[17:15], tmpL1[14:12], tmpL1[11:09], tmpL1[08:06], tmpL1[05:03], tmpL1[02:00]} :
                (k2 == 'b010) ? {tmpL1[17:15], tmpL1[20:18], tmpL1[23:21], tmpL1[14:12], tmpL1[11:09], tmpL1[08:06], tmpL1[05:03], tmpL1[02:00]} :
                (k2 == 'b011) ? {tmpL1[14:12], tmpL1[20:18], tmpL1[17:15], tmpL1[23:21], tmpL1[11:09], tmpL1[08:06], tmpL1[05:03], tmpL1[02:00]} :
                (k2 == 'b100) ? {tmpL1[11:09], tmpL1[20:18], tmpL1[17:15], tmpL1[14:12], tmpL1[23:21], tmpL1[08:06], tmpL1[05:03], tmpL1[02:00]} :
                (k2 == 'b101) ? {tmpL1[08:06], tmpL1[20:18], tmpL1[17:15], tmpL1[14:12], tmpL1[11:09], tmpL1[23:21], tmpL1[05:03], tmpL1[02:00]} :
                (k2 == 'b110) ? {tmpL1[05:03], tmpL1[20:18], tmpL1[17:15], tmpL1[14:12], tmpL1[11:09], tmpL1[08:06], tmpL1[23:21], tmpL1[02:00]} :
                (k2 == 'b111) ? {tmpL1[02:00], tmpL1[20:18], tmpL1[17:15], tmpL1[14:12], tmpL1[11:09], tmpL1[08:06], tmpL1[05:03], tmpL1[23:21]} :
                                3'bx ;

assign tmpR2 =  (k2 == 'b000) ? {tmpR1[23:21], tmpR1[20:18], tmpR1[17:15], tmpR1[14:12], tmpR1[11:09], tmpR1[08:06], tmpR1[05:03], tmpR1[02:00]} :
                (k2 == 'b001) ? {tmpR1[23:21], tmpR1[20:18], tmpR1[17:15], tmpR1[14:12], tmpR1[11:09], tmpR1[08:06], tmpR1[02:00], tmpR1[05:03]} :
                (k2 == 'b010) ? {tmpR1[23:21], tmpR1[20:18], tmpR1[17:15], tmpR1[14:12], tmpR1[11:09], tmpR1[02:00], tmpR1[05:03], tmpR1[08:06]} :
                (k2 == 'b011) ? {tmpR1[23:21], tmpR1[20:18], tmpR1[17:15], tmpR1[14:12], tmpR1[02:00], tmpR1[08:06], tmpR1[05:03], tmpR1[11:09]} :
                (k2 == 'b100) ? {tmpR1[23:21], tmpR1[20:18], tmpR1[17:15], tmpR1[02:00], tmpR1[11:09], tmpR1[08:06], tmpR1[05:03], tmpR1[14:12]} :
                (k2 == 'b101) ? {tmpR1[23:21], tmpR1[20:18], tmpR1[02:00], tmpR1[14:12], tmpR1[11:09], tmpR1[08:06], tmpR1[05:03], tmpR1[17:15]} :
                (k2 == 'b110) ? {tmpR1[23:21], tmpR1[02:00], tmpR1[17:15], tmpR1[14:12], tmpR1[11:09], tmpR1[08:06], tmpR1[05:03], tmpR1[20:18]} :
                (k2 == 'b111) ? {tmpR1[02:00], tmpR1[20:18], tmpR1[17:15], tmpR1[14:12], tmpR1[11:09], tmpR1[08:06], tmpR1[05:03], tmpR1[23:21]} :
                                3'bx ;

// number 4
assign k3 = shift_key[14:12];
assign tmpL3 =  (k3 == 'b000) ? {tmpL2[23:21], tmpL2[20:18], tmpL2[17:15], tmpL2[14:12], tmpL2[11:09], tmpL2[08:06], tmpL2[05:03], tmpL2[02:00]} :
                (k3 == 'b001) ? {tmpL2[20:18], tmpL2[23:21], tmpL2[17:15], tmpL2[14:12], tmpL2[11:09], tmpL2[08:06], tmpL2[05:03], tmpL2[02:00]} :
                (k3 == 'b010) ? {tmpL2[17:15], tmpL2[20:18], tmpL2[23:21], tmpL2[14:12], tmpL2[11:09], tmpL2[08:06], tmpL2[05:03], tmpL2[02:00]} :
                (k3 == 'b011) ? {tmpL2[14:12], tmpL2[20:18], tmpL2[17:15], tmpL2[23:21], tmpL2[11:09], tmpL2[08:06], tmpL2[05:03], tmpL2[02:00]} :
                (k3 == 'b100) ? {tmpL2[11:09], tmpL2[20:18], tmpL2[17:15], tmpL2[14:12], tmpL2[23:21], tmpL2[08:06], tmpL2[05:03], tmpL2[02:00]} :
                (k3 == 'b101) ? {tmpL2[08:06], tmpL2[20:18], tmpL2[17:15], tmpL2[14:12], tmpL2[11:09], tmpL2[23:21], tmpL2[05:03], tmpL2[02:00]} :
                (k3 == 'b110) ? {tmpL2[05:03], tmpL2[20:18], tmpL2[17:15], tmpL2[14:12], tmpL2[11:09], tmpL2[08:06], tmpL2[23:21], tmpL2[02:00]} :
                (k3 == 'b111) ? {tmpL2[02:00], tmpL2[20:18], tmpL2[17:15], tmpL2[14:12], tmpL2[11:09], tmpL2[08:06], tmpL2[05:03], tmpL2[23:21]} :
                                3'bx ;

assign tmpR3 =  (k3 == 'b000) ? {tmpR2[23:21], tmpR2[20:18], tmpR2[17:15], tmpR2[14:12], tmpR2[11:09], tmpR2[08:06], tmpR2[05:03], tmpR2[02:00]} :
                (k3 == 'b001) ? {tmpR2[23:21], tmpR2[20:18], tmpR2[17:15], tmpR2[14:12], tmpR2[11:09], tmpR2[08:06], tmpR2[02:00], tmpR2[05:03]} :
                (k3 == 'b010) ? {tmpR2[23:21], tmpR2[20:18], tmpR2[17:15], tmpR2[14:12], tmpR2[11:09], tmpR2[02:00], tmpR2[05:03], tmpR2[08:06]} :
                (k3 == 'b011) ? {tmpR2[23:21], tmpR2[20:18], tmpR2[17:15], tmpR2[14:12], tmpR2[02:00], tmpR2[08:06], tmpR2[05:03], tmpR2[11:09]} :
                (k3 == 'b100) ? {tmpR2[23:21], tmpR2[20:18], tmpR2[17:15], tmpR2[02:00], tmpR2[11:09], tmpR2[08:06], tmpR2[05:03], tmpR2[14:12]} :
                (k3 == 'b101) ? {tmpR2[23:21], tmpR2[20:18], tmpR2[02:00], tmpR2[14:12], tmpR2[11:09], tmpR2[08:06], tmpR2[05:03], tmpR2[17:15]} :
                (k3 == 'b110) ? {tmpR2[23:21], tmpR2[02:00], tmpR2[17:15], tmpR2[14:12], tmpR2[11:09], tmpR2[08:06], tmpR2[05:03], tmpR2[20:18]} :
                (k3 == 'b111) ? {tmpR2[02:00], tmpR2[20:18], tmpR2[17:15], tmpR2[14:12], tmpR2[11:09], tmpR2[08:06], tmpR2[05:03], tmpR2[23:21]} :
                                3'bx ;

// number 5
assign k4 = shift_key[11:09];
assign tmpL4 =  (k4 == 'b000) ? {tmpL3[23:21], tmpL3[20:18], tmpL3[17:15], tmpL3[14:12], tmpL3[11:09], tmpL3[08:06], tmpL3[05:03], tmpL3[02:00]} :
                (k4 == 'b001) ? {tmpL3[20:18], tmpL3[23:21], tmpL3[17:15], tmpL3[14:12], tmpL3[11:09], tmpL3[08:06], tmpL3[05:03], tmpL3[02:00]} :
                (k4 == 'b010) ? {tmpL3[17:15], tmpL3[20:18], tmpL3[23:21], tmpL3[14:12], tmpL3[11:09], tmpL3[08:06], tmpL3[05:03], tmpL3[02:00]} :
                (k4 == 'b011) ? {tmpL3[14:12], tmpL3[20:18], tmpL3[17:15], tmpL3[23:21], tmpL3[11:09], tmpL3[08:06], tmpL3[05:03], tmpL3[02:00]} :
                (k4 == 'b100) ? {tmpL3[11:09], tmpL3[20:18], tmpL3[17:15], tmpL3[14:12], tmpL3[23:21], tmpL3[08:06], tmpL3[05:03], tmpL3[02:00]} :
                (k4 == 'b101) ? {tmpL3[08:06], tmpL3[20:18], tmpL3[17:15], tmpL3[14:12], tmpL3[11:09], tmpL3[23:21], tmpL3[05:03], tmpL3[02:00]} :
                (k4 == 'b110) ? {tmpL3[05:03], tmpL3[20:18], tmpL3[17:15], tmpL3[14:12], tmpL3[11:09], tmpL3[08:06], tmpL3[23:21], tmpL3[02:00]} :
                (k4 == 'b111) ? {tmpL3[02:00], tmpL3[20:18], tmpL3[17:15], tmpL3[14:12], tmpL3[11:09], tmpL3[08:06], tmpL3[05:03], tmpL3[23:21]} :
                                3'bx ;

assign tmpR4 =  (k4 == 'b000) ? {tmpR3[23:21], tmpR3[20:18], tmpR3[17:15], tmpR3[14:12], tmpR3[11:09], tmpR3[08:06], tmpR3[05:03], tmpR3[02:00]} :
                (k4 == 'b001) ? {tmpR3[23:21], tmpR3[20:18], tmpR3[17:15], tmpR3[14:12], tmpR3[11:09], tmpR3[08:06], tmpR3[02:00], tmpR3[05:03]} :
                (k4 == 'b010) ? {tmpR3[23:21], tmpR3[20:18], tmpR3[17:15], tmpR3[14:12], tmpR3[11:09], tmpR3[02:00], tmpR3[05:03], tmpR3[08:06]} :
                (k4 == 'b011) ? {tmpR3[23:21], tmpR3[20:18], tmpR3[17:15], tmpR3[14:12], tmpR3[02:00], tmpR3[08:06], tmpR3[05:03], tmpR3[11:09]} :
                (k4 == 'b100) ? {tmpR3[23:21], tmpR3[20:18], tmpR3[17:15], tmpR3[02:00], tmpR3[11:09], tmpR3[08:06], tmpR3[05:03], tmpR3[14:12]} :
                (k4 == 'b101) ? {tmpR3[23:21], tmpR3[20:18], tmpR3[02:00], tmpR3[14:12], tmpR3[11:09], tmpR3[08:06], tmpR3[05:03], tmpR3[17:15]} :
                (k4 == 'b110) ? {tmpR3[23:21], tmpR3[02:00], tmpR3[17:15], tmpR3[14:12], tmpR3[11:09], tmpR3[08:06], tmpR3[05:03], tmpR3[20:18]} :
                (k4 == 'b111) ? {tmpR3[02:00], tmpR3[20:18], tmpR3[17:15], tmpR3[14:12], tmpR3[11:09], tmpR3[08:06], tmpR3[05:03], tmpR3[23:21]} :
                                3'bx ;

// number 6
assign k5 = shift_key[08:06];
assign tmpL5 =  (k5 == 'b000) ? {tmpL4[23:21], tmpL4[20:18], tmpL4[17:15], tmpL4[14:12], tmpL4[11:09], tmpL4[08:06], tmpL4[05:03], tmpL4[02:00]} :
                (k5 == 'b001) ? {tmpL4[20:18], tmpL4[23:21], tmpL4[17:15], tmpL4[14:12], tmpL4[11:09], tmpL4[08:06], tmpL4[05:03], tmpL4[02:00]} :
                (k5 == 'b010) ? {tmpL4[17:15], tmpL4[20:18], tmpL4[23:21], tmpL4[14:12], tmpL4[11:09], tmpL4[08:06], tmpL4[05:03], tmpL4[02:00]} :
                (k5 == 'b011) ? {tmpL4[14:12], tmpL4[20:18], tmpL4[17:15], tmpL4[23:21], tmpL4[11:09], tmpL4[08:06], tmpL4[05:03], tmpL4[02:00]} :
                (k5 == 'b100) ? {tmpL4[11:09], tmpL4[20:18], tmpL4[17:15], tmpL4[14:12], tmpL4[23:21], tmpL4[08:06], tmpL4[05:03], tmpL4[02:00]} :
                (k5 == 'b101) ? {tmpL4[08:06], tmpL4[20:18], tmpL4[17:15], tmpL4[14:12], tmpL4[11:09], tmpL4[23:21], tmpL4[05:03], tmpL4[02:00]} :
                (k5 == 'b110) ? {tmpL4[05:03], tmpL4[20:18], tmpL4[17:15], tmpL4[14:12], tmpL4[11:09], tmpL4[08:06], tmpL4[23:21], tmpL4[02:00]} :
                (k5 == 'b111) ? {tmpL4[02:00], tmpL4[20:18], tmpL4[17:15], tmpL4[14:12], tmpL4[11:09], tmpL4[08:06], tmpL4[05:03], tmpL4[23:21]} :
                                3'bx ;

assign tmpR5 =  (k5 == 'b000) ? {tmpR4[23:21], tmpR4[20:18], tmpR4[17:15], tmpR4[14:12], tmpR4[11:09], tmpR4[08:06], tmpR4[05:03], tmpR4[02:00]} :
                (k5 == 'b001) ? {tmpR4[23:21], tmpR4[20:18], tmpR4[17:15], tmpR4[14:12], tmpR4[11:09], tmpR4[08:06], tmpR4[02:00], tmpR4[05:03]} :
                (k5 == 'b010) ? {tmpR4[23:21], tmpR4[20:18], tmpR4[17:15], tmpR4[14:12], tmpR4[11:09], tmpR4[02:00], tmpR4[05:03], tmpR4[08:06]} :
                (k5 == 'b011) ? {tmpR4[23:21], tmpR4[20:18], tmpR4[17:15], tmpR4[14:12], tmpR4[02:00], tmpR4[08:06], tmpR4[05:03], tmpR4[11:09]} :
                (k5 == 'b100) ? {tmpR4[23:21], tmpR4[20:18], tmpR4[17:15], tmpR4[02:00], tmpR4[11:09], tmpR4[08:06], tmpR4[05:03], tmpR4[14:12]} :
                (k5 == 'b101) ? {tmpR4[23:21], tmpR4[20:18], tmpR4[02:00], tmpR4[14:12], tmpR4[11:09], tmpR4[08:06], tmpR4[05:03], tmpR4[17:15]} :
                (k5 == 'b110) ? {tmpR4[23:21], tmpR4[02:00], tmpR4[17:15], tmpR4[14:12], tmpR4[11:09], tmpR4[08:06], tmpR4[05:03], tmpR4[20:18]} :
                (k5 == 'b111) ? {tmpR4[02:00], tmpR4[20:18], tmpR4[17:15], tmpR4[14:12], tmpR4[11:09], tmpR4[08:06], tmpR4[05:03], tmpR4[23:21]} :
                                3'bx ;

// number 7
assign k6 = shift_key[05:03];
assign tmpL6 =  (k6 == 'b000) ? {tmpL5[23:21], tmpL5[20:18], tmpL5[17:15], tmpL5[14:12], tmpL5[11:09], tmpL5[08:06], tmpL5[05:03], tmpL5[02:00]} :
                (k6 == 'b001) ? {tmpL5[20:18], tmpL5[23:21], tmpL5[17:15], tmpL5[14:12], tmpL5[11:09], tmpL5[08:06], tmpL5[05:03], tmpL5[02:00]} :
                (k6 == 'b010) ? {tmpL5[17:15], tmpL5[20:18], tmpL5[23:21], tmpL5[14:12], tmpL5[11:09], tmpL5[08:06], tmpL5[05:03], tmpL5[02:00]} :
                (k6 == 'b011) ? {tmpL5[14:12], tmpL5[20:18], tmpL5[17:15], tmpL5[23:21], tmpL5[11:09], tmpL5[08:06], tmpL5[05:03], tmpL5[02:00]} :
                (k6 == 'b100) ? {tmpL5[11:09], tmpL5[20:18], tmpL5[17:15], tmpL5[14:12], tmpL5[23:21], tmpL5[08:06], tmpL5[05:03], tmpL5[02:00]} :
                (k6 == 'b101) ? {tmpL5[08:06], tmpL5[20:18], tmpL5[17:15], tmpL5[14:12], tmpL5[11:09], tmpL5[23:21], tmpL5[05:03], tmpL5[02:00]} :
                (k6 == 'b110) ? {tmpL5[05:03], tmpL5[20:18], tmpL5[17:15], tmpL5[14:12], tmpL5[11:09], tmpL5[08:06], tmpL5[23:21], tmpL5[02:00]} :
                (k6 == 'b111) ? {tmpL5[02:00], tmpL5[20:18], tmpL5[17:15], tmpL5[14:12], tmpL5[11:09], tmpL5[08:06], tmpL5[05:03], tmpL5[23:21]} :
                                3'bx ;

assign tmpR6 =  (k6 == 'b000) ? {tmpR5[23:21], tmpR5[20:18], tmpR5[17:15], tmpR5[14:12], tmpR5[11:09], tmpR5[08:06], tmpR5[05:03], tmpR5[02:00]} :
                (k6 == 'b001) ? {tmpR5[23:21], tmpR5[20:18], tmpR5[17:15], tmpR5[14:12], tmpR5[11:09], tmpR5[08:06], tmpR5[02:00], tmpR5[05:03]} :
                (k6 == 'b010) ? {tmpR5[23:21], tmpR5[20:18], tmpR5[17:15], tmpR5[14:12], tmpR5[11:09], tmpR5[02:00], tmpR5[05:03], tmpR5[08:06]} :
                (k6 == 'b011) ? {tmpR5[23:21], tmpR5[20:18], tmpR5[17:15], tmpR5[14:12], tmpR5[02:00], tmpR5[08:06], tmpR5[05:03], tmpR5[11:09]} :
                (k6 == 'b100) ? {tmpR5[23:21], tmpR5[20:18], tmpR5[17:15], tmpR5[02:00], tmpR5[11:09], tmpR5[08:06], tmpR5[05:03], tmpR5[14:12]} :
                (k6 == 'b101) ? {tmpR5[23:21], tmpR5[20:18], tmpR5[02:00], tmpR5[14:12], tmpR5[11:09], tmpR5[08:06], tmpR5[05:03], tmpR5[17:15]} :
                (k6 == 'b110) ? {tmpR5[23:21], tmpR5[02:00], tmpR5[17:15], tmpR5[14:12], tmpR5[11:09], tmpR5[08:06], tmpR5[05:03], tmpR5[20:18]} :
                (k6 == 'b111) ? {tmpR5[02:00], tmpR5[20:18], tmpR5[17:15], tmpR5[14:12], tmpR5[11:09], tmpR5[08:06], tmpR5[05:03], tmpR5[23:21]} :
                                3'bx ;

// number 8
assign k7 = shift_key[02:00];
assign tmpL7 =  (k7 == 'b000) ? {tmpL6[23:21], tmpL6[20:18], tmpL6[17:15], tmpL6[14:12], tmpL6[11:09], tmpL6[08:06], tmpL6[05:03], tmpL6[02:00]} :
                (k7 == 'b001) ? {tmpL6[20:18], tmpL6[23:21], tmpL6[17:15], tmpL6[14:12], tmpL6[11:09], tmpL6[08:06], tmpL6[05:03], tmpL6[02:00]} :
                (k7 == 'b010) ? {tmpL6[17:15], tmpL6[20:18], tmpL6[23:21], tmpL6[14:12], tmpL6[11:09], tmpL6[08:06], tmpL6[05:03], tmpL6[02:00]} :
                (k7 == 'b011) ? {tmpL6[14:12], tmpL6[20:18], tmpL6[17:15], tmpL6[23:21], tmpL6[11:09], tmpL6[08:06], tmpL6[05:03], tmpL6[02:00]} :
                (k7 == 'b100) ? {tmpL6[11:09], tmpL6[20:18], tmpL6[17:15], tmpL6[14:12], tmpL6[23:21], tmpL6[08:06], tmpL6[05:03], tmpL6[02:00]} :
                (k7 == 'b101) ? {tmpL6[08:06], tmpL6[20:18], tmpL6[17:15], tmpL6[14:12], tmpL6[11:09], tmpL6[23:21], tmpL6[05:03], tmpL6[02:00]} :
                (k7 == 'b110) ? {tmpL6[05:03], tmpL6[20:18], tmpL6[17:15], tmpL6[14:12], tmpL6[11:09], tmpL6[08:06], tmpL6[23:21], tmpL6[02:00]} :
                (k7 == 'b111) ? {tmpL6[02:00], tmpL6[20:18], tmpL6[17:15], tmpL6[14:12], tmpL6[11:09], tmpL6[08:06], tmpL6[05:03], tmpL6[23:21]} :
                                3'bx ;

assign tmpR7 =  (k7 == 'b000) ? {tmpR6[23:21], tmpR6[20:18], tmpR6[17:15], tmpR6[14:12], tmpR6[11:09], tmpR6[08:06], tmpR6[05:03], tmpR6[02:00]} :
                (k7 == 'b001) ? {tmpR6[23:21], tmpR6[20:18], tmpR6[17:15], tmpR6[14:12], tmpR6[11:09], tmpR6[08:06], tmpR6[02:00], tmpR6[05:03]} :
                (k7 == 'b010) ? {tmpR6[23:21], tmpR6[20:18], tmpR6[17:15], tmpR6[14:12], tmpR6[11:09], tmpR6[02:00], tmpR6[05:03], tmpR6[08:06]} :
                (k7 == 'b011) ? {tmpR6[23:21], tmpR6[20:18], tmpR6[17:15], tmpR6[14:12], tmpR6[02:00], tmpR6[08:06], tmpR6[05:03], tmpR6[11:09]} :
                (k7 == 'b100) ? {tmpR6[23:21], tmpR6[20:18], tmpR6[17:15], tmpR6[02:00], tmpR6[11:09], tmpR6[08:06], tmpR6[05:03], tmpR6[14:12]} :
                (k7 == 'b101) ? {tmpR6[23:21], tmpR6[20:18], tmpR6[02:00], tmpR6[14:12], tmpR6[11:09], tmpR6[08:06], tmpR6[05:03], tmpR6[17:15]} :
                (k7 == 'b110) ? {tmpR6[23:21], tmpR6[02:00], tmpR6[17:15], tmpR6[14:12], tmpR6[11:09], tmpR6[08:06], tmpR6[05:03], tmpR6[20:18]} :
                (k7 == 'b111) ? {tmpR6[02:00], tmpR6[20:18], tmpR6[17:15], tmpR6[14:12], tmpR6[11:09], tmpR6[08:06], tmpR6[05:03], tmpR6[23:21]} :
                                3'bx ;

// final
assign permutation_key1 = tmpL7;
assign permutation_key2 = tmpR7;

endmodule