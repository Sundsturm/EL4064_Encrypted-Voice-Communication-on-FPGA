module ReverseBitOrder #(
    parameter   WIDTH = 16,
    parameter   DEPTH = 128
)(
    input               clock,
    input               di_en,
    input [WIDTH-1:0]   di_re,
    input [WIDTH-1:0]   di_im,

    output              do_en,
    output reg [6:0]    do_count,
    output[WIDTH-1:0]   do_re,
    output[WIDTH-1:0]   do_im
);

reg [WIDTH-1:0] buf_re  [0:DEPTH-1];
reg [WIDTH-1:0] buf_im  [0:DEPTH-1];
reg [1:0]       sync    [0:DEPTH-1];
reg [6:0]       di_count;
reg init_di_count;

// initialize sync signal
integer m;
initial begin 
    for (m = DEPTH - 1; m > -1; m  = m - 1) begin 
        sync[m]   <= 1'b0;
    end

    init_di_count <= 1'b0;
end

// count input data
always @(posedge di_en) begin 
    //di_count <= 1'b0;
    init_di_count <= 1'b1;
    #28;
    init_di_count <= 1'b0;
end

always @(posedge clock) begin 
    if (init_di_count) begin
        di_count <= 1'b0;
    end else begin
        di_count <= di_count + 1'b1;
    end
    do_count <= di_count;
end

integer n;
always @(posedge clock) begin
    /*
    indices = [ ... 
        1 65 33 97 17 81 49 113 ...
        121 57 89 25 105 41 74 9 ...
        5 3 125 61 93 29 109 45 77 13 ...
        117 53 85 21 101 37 69 ...
        67 35 99 19 83 51 115 ...
        11 75 43 107 27 ...
        91 59 123 7 71 39 103 23 87 ...
        55 119 15 79 47 111 31 95 63 ...
        128 64 96 32  112 48 80 16  120 ...
        56 88 24  104 40 72 8  124 60 ...
        92 28  108 44 76 12  116 52 84 ...
        20  100 36 68 4  126 62 94 30 ...
        110 46 78 14  118 54 86 22  102 ...
        38 70 6  122 58 90 26  106 42 ...
        74 10  114 50 82 18 98 34 66 2 127
    ];

    */

    for (n = DEPTH - 1; n > 0; n = n - 1) begin 
        buf_re[n] <= buf_re[n - 1];
        buf_im[n] <= buf_im[n - 1];
        sync[n]   <= sync[n - 1];
    end
    
    buf_re[0] <= di_re;
    buf_im[0] <= di_im;

    if (di_en == 1'b0 | di_en == 1'b1) begin
        sync[0]   <= di_en;
    end else begin
        sync[0]   <= 1'b0;
    end

    ///

    if (di_count == 1'b0) begin
        
        buf_re[127] <= buf_re[127];
        buf_im[127] <= buf_im[127];
        sync[127]   <= sync[127];
        
        buf_re[126] <= buf_re[63];
        buf_im[126] <= buf_im[63];
        sync[126]   <= sync[63];
        
        buf_re[125] <= buf_re[95];
        buf_im[125] <= buf_im[95];
        sync[125]   <= sync[95];
        
        buf_re[124] <= buf_re[31];
        buf_im[124] <= buf_im[31];
        sync[124]   <= sync[31];
        
        buf_re[123] <= buf_re[111];
        buf_im[123] <= buf_im[111];
        sync[123]   <= sync[111];
        
        buf_re[122] <= buf_re[47];
        buf_im[122] <= buf_im[47];
        sync[122]   <= sync[47];
        
        buf_re[121] <= buf_re[79];
        buf_im[121] <= buf_im[79];
        sync[121]   <= sync[79];
        
        buf_re[120] <= buf_re[15];
        buf_im[120] <= buf_im[15];
        sync[120]   <= sync[15];
        
        buf_re[119] <= buf_re[7];
        buf_im[119] <= buf_im[7];
        sync[119]   <= sync[7];
        
        buf_re[118] <= buf_re[71];
        buf_im[118] <= buf_im[71];
        sync[118]   <= sync[71];
        
        buf_re[117] <= buf_re[39];
        buf_im[117] <= buf_im[39];
        sync[117]   <= sync[39];
        
        buf_re[116] <= buf_re[103];
        buf_im[116] <= buf_im[103];
        sync[116]   <= sync[103];
        
        buf_re[115] <= buf_re[23];
        buf_im[115] <= buf_im[23];
        sync[115]   <= sync[23];
        
        buf_re[114] <= buf_re[87];
        buf_im[114] <= buf_im[87];
        sync[114]   <= sync[87];
        
        buf_re[113] <= buf_re[54];
        buf_im[113] <= buf_im[54];
        sync[113]   <= sync[54];
        
        buf_re[112] <= buf_re[119];
        buf_im[112] <= buf_im[119];
        sync[112]   <= sync[119];
        
        buf_re[111] <= buf_re[123];
        buf_im[111] <= buf_im[123];
        sync[111]   <= sync[123];
        
        buf_re[110] <= buf_re[125];
        buf_im[110] <= buf_im[125];
        sync[110]   <= sync[125];
        
        buf_re[109] <= buf_re[3];
        buf_im[109] <= buf_im[3];
        sync[109]   <= sync[3];
        
        buf_re[108] <= buf_re[67];
        buf_im[108] <= buf_im[67];
        sync[108]   <= sync[67];
        
        buf_re[107] <= buf_re[35];
        buf_im[107] <= buf_im[35];
        sync[107]   <= sync[35];
        
        buf_re[106] <= buf_re[99];
        buf_im[106] <= buf_im[99];
        sync[106]   <= sync[99];
        
        buf_re[105] <= buf_re[19];
        buf_im[105] <= buf_im[19];
        sync[105]   <= sync[19];
        
        buf_re[104] <= buf_re[83];
        buf_im[104] <= buf_im[83];
        sync[104]   <= sync[83];
        
        buf_re[103] <= buf_re[51];
        buf_im[103] <= buf_im[51];
        sync[103]   <= sync[51];
        
        buf_re[102] <= buf_re[115];
        buf_im[102] <= buf_im[115];
        sync[102]   <= sync[115];
        
        buf_re[101] <= buf_re[11];
        buf_im[101] <= buf_im[11];
        sync[101]   <= sync[11];
        
        buf_re[100] <= buf_re[75];
        buf_im[100] <= buf_im[75];
        sync[100]   <= sync[75];
        
        buf_re[99] <= buf_re[43];
        buf_im[99] <= buf_im[43];
        sync[99]   <= sync[43];
        
        buf_re[98] <= buf_re[107];
        buf_im[98] <= buf_im[107];
        sync[98]   <= sync[107];
        
        buf_re[97] <= buf_re[27];
        buf_im[97] <= buf_im[27];
        sync[97]   <= sync[27];
        
        buf_re[96] <= buf_re[91];
        buf_im[96] <= buf_im[91];
        sync[96]   <= sync[91];
        
        buf_re[95] <= buf_re[59];
        buf_im[95] <= buf_im[59];
        sync[95]   <= sync[59];
        
        buf_re[94] <= buf_re[61];
        buf_im[94] <= buf_im[61];
        sync[94]   <= sync[61];
        
        buf_re[93] <= buf_re[93];
        buf_im[93] <= buf_im[93];
        sync[93]   <= sync[93];
        
        buf_re[92] <= buf_re[29];
        buf_im[92] <= buf_im[29];
        sync[92]   <= sync[29];
        
        buf_re[91] <= buf_re[109];
        buf_im[91] <= buf_im[109];
        sync[91]   <= sync[109];
        
        buf_re[90] <= buf_re[45];
        buf_im[90] <= buf_im[45];
        sync[90]   <= sync[45];
        
        buf_re[89] <= buf_re[77];
        buf_im[89] <= buf_im[77];
        sync[89]   <= sync[77];
        
        buf_re[88] <= buf_re[13];
        buf_im[88] <= buf_im[13];
        sync[88]   <= sync[13];
        
        buf_re[87] <= buf_re[117];
        buf_im[87] <= buf_im[117];
        sync[87]   <= sync[117];
        
        buf_re[86] <= buf_re[53];
        buf_im[86] <= buf_im[53];
        sync[86]   <= sync[53];
        
        buf_re[85] <= buf_re[85];
        buf_im[85] <= buf_im[85];
        sync[85]   <= sync[85];
        
        buf_re[84] <= buf_re[21];
        buf_im[84] <= buf_im[21];
        sync[84]   <= sync[21];
        
        buf_re[83] <= buf_re[101];
        buf_im[83] <= buf_im[101];
        sync[83]   <= sync[101];
        
        buf_re[82] <= buf_re[37];
        buf_im[82] <= buf_im[37];
        sync[82]   <= sync[37];
        
        buf_re[81] <= buf_re[69];
        buf_im[81] <= buf_im[69];
        sync[81]   <= sync[69];
        
        buf_re[80] <= buf_re[5];
        buf_im[80] <= buf_im[5];
        sync[80]   <= sync[5];
        
        buf_re[79] <= buf_re[121];
        buf_im[79] <= buf_im[121];
        sync[79]   <= sync[121];
        
        buf_re[78] <= buf_re[57];
        buf_im[78] <= buf_im[57];
        sync[78]   <= sync[57];
        
        buf_re[77] <= buf_re[89];
        buf_im[77] <= buf_im[89];
        sync[77]   <= sync[89];
        
        buf_re[76] <= buf_re[25];
        buf_im[76] <= buf_im[25];
        sync[76]   <= sync[25];
        
        buf_re[75] <= buf_re[105];
        buf_im[75] <= buf_im[105];
        sync[75]   <= sync[105];
        
        buf_re[74] <= buf_re[41];
        buf_im[74] <= buf_im[41];
        sync[74]   <= sync[41];
        
        buf_re[73] <= buf_re[73];
        buf_im[73] <= buf_im[73];
        sync[73]   <= sync[73];
        
        buf_re[72] <= buf_re[9];
        buf_im[72] <= buf_im[9];
        sync[72]   <= sync[9];
        
        buf_re[71] <= buf_re[113];
        buf_im[71] <= buf_im[113];
        sync[71]   <= sync[113];
        
        buf_re[70] <= buf_re[49];
        buf_im[70] <= buf_im[49];
        sync[70]   <= sync[49];
        
        buf_re[69] <= buf_re[81];
        buf_im[69] <= buf_im[81];
        sync[69]   <= sync[81];
        
        buf_re[68] <= buf_re[17];
        buf_im[68] <= buf_im[17];
        sync[68]   <= sync[17];
        
        buf_re[67] <= buf_re[97];
        buf_im[67] <= buf_im[97];
        sync[67]   <= sync[97];
        
        buf_re[66] <= buf_re[33];
        buf_im[66] <= buf_im[33];
        sync[66]   <= sync[33];
        
        buf_re[65] <= buf_re[65];
        buf_im[65] <= buf_im[65];
        sync[65]   <= sync[65];
        
        buf_re[64] <= buf_re[0];
        buf_im[64] <= buf_im[0];
        sync[64]   <= sync[0];
        
        buf_re[63] <= buf_re[64];
        buf_im[63] <= buf_im[64];
        sync[63]   <= sync[64];
        
        buf_re[62] <= buf_re[32];
        buf_im[62] <= buf_im[32];
        sync[62]   <= sync[32];
        
        buf_re[61] <= buf_re[96];
        buf_im[61] <= buf_im[96];
        sync[61]   <= sync[96];
        
        buf_re[60] <= buf_re[16];
        buf_im[60] <= buf_im[16];
        sync[60]   <= sync[16];
        
        buf_re[59] <= buf_re[80];
        buf_im[59] <= buf_im[80];
        sync[59]   <= sync[80];
        
        buf_re[58] <= buf_re[48];
        buf_im[58] <= buf_im[48];
        sync[58]   <= sync[48];
        
        buf_re[57] <= buf_re[112];
        buf_im[57] <= buf_im[112];
        sync[57]   <= sync[112];
        
        buf_re[56] <= buf_re[8];
        buf_im[56] <= buf_im[8];
        sync[56]   <= sync[8];
        
        buf_re[55] <= buf_re[72];
        buf_im[55] <= buf_im[72];
        sync[55]   <= sync[72];
        
        buf_re[54] <= buf_re[40];
        buf_im[54] <= buf_im[40];
        sync[54]   <= sync[40];
        
        buf_re[53] <= buf_re[104];
        buf_im[53] <= buf_im[104];
        sync[53]   <= sync[104];
        
        buf_re[52] <= buf_re[24];
        buf_im[52] <= buf_im[24];
        sync[52]   <= sync[24];
        
        buf_re[51] <= buf_re[88];
        buf_im[51] <= buf_im[88];
        sync[51]   <= sync[88];
        
        buf_re[50] <= buf_re[56];
        buf_im[50] <= buf_im[56];
        sync[50]   <= sync[56];
        
        buf_re[49] <= buf_re[120];
        buf_im[49] <= buf_im[120];
        sync[49]   <= sync[120];
        
        buf_re[48] <= buf_re[4];
        buf_im[48] <= buf_im[4];
        sync[48]   <= sync[4];
        
        buf_re[47] <= buf_re[68];
        buf_im[47] <= buf_im[68];
        sync[47]   <= sync[68];
        
        buf_re[46] <= buf_re[36];
        buf_im[46] <= buf_im[36];
        sync[46]   <= sync[36];
        
        buf_re[45] <= buf_re[100];
        buf_im[45] <= buf_im[100];
        sync[45]   <= sync[100];
        
        buf_re[44] <= buf_re[20];
        buf_im[44] <= buf_im[20];
        sync[44]   <= sync[20];
        
        buf_re[43] <= buf_re[84];
        buf_im[43] <= buf_im[84];
        sync[43]   <= sync[84];
        
        buf_re[42] <= buf_re[52];
        buf_im[42] <= buf_im[52];
        sync[42]   <= sync[52];
        
        buf_re[41] <= buf_re[116];
        buf_im[41] <= buf_im[116];
        sync[41]   <= sync[116];
        
        buf_re[40] <= buf_re[12];
        buf_im[40] <= buf_im[12];
        sync[40]   <= sync[12];
        
        buf_re[39] <= buf_re[76];
        buf_im[39] <= buf_im[76];
        sync[39]   <= sync[76];
        
        buf_re[38] <= buf_re[44];
        buf_im[38] <= buf_im[44];
        sync[38]   <= sync[44];
        
        buf_re[37] <= buf_re[108];
        buf_im[37] <= buf_im[108];
        sync[37]   <= sync[108];
        
        buf_re[36] <= buf_re[28];
        buf_im[36] <= buf_im[28];
        sync[36]   <= sync[28];
        
        buf_re[35] <= buf_re[92];
        buf_im[35] <= buf_im[92];
        sync[35]   <= sync[92];
        
        buf_re[34] <= buf_re[60];
        buf_im[34] <= buf_im[60];
        sync[34]   <= sync[60];
        
        buf_re[33] <= buf_re[124];
        buf_im[33] <= buf_im[124];
        sync[33]   <= sync[124];
        
        buf_re[32] <= buf_re[2];
        buf_im[32] <= buf_im[2];
        sync[32]   <= sync[2];
        
        buf_re[31] <= buf_re[66];
        buf_im[31] <= buf_im[66];
        sync[31]   <= sync[66];
        
        buf_re[30] <= buf_re[34];
        buf_im[30] <= buf_im[34];
        sync[30]   <= sync[34];
        
        buf_re[29] <= buf_re[98];
        buf_im[29] <= buf_im[98];
        sync[29]   <= sync[98];
        
        buf_re[28] <= buf_re[18];
        buf_im[28] <= buf_im[18];
        sync[28]   <= sync[18];
        
        buf_re[27] <= buf_re[82];
        buf_im[27] <= buf_im[82];
        sync[27]   <= sync[82];
        
        buf_re[26] <= buf_re[50];
        buf_im[26] <= buf_im[50];
        sync[26]   <= sync[50];
        
        buf_re[25] <= buf_re[114];
        buf_im[25] <= buf_im[114];
        sync[25]   <= sync[114];
        
        buf_re[24] <= buf_re[10];
        buf_im[24] <= buf_im[10];
        sync[24]   <= sync[10];
        
        buf_re[23] <= buf_re[74];
        buf_im[23] <= buf_im[74];
        sync[23]   <= sync[74];
        
        buf_re[22] <= buf_re[42];
        buf_im[22] <= buf_im[42];
        sync[22]   <= sync[42];
        
        buf_re[21] <= buf_re[106];
        buf_im[21] <= buf_im[106];
        sync[21]   <= sync[106];
        
        buf_re[20] <= buf_re[26];
        buf_im[20] <= buf_im[26];
        sync[20]   <= sync[26];
        
        buf_re[19] <= buf_re[90];
        buf_im[19] <= buf_im[90];
        sync[19]   <= sync[90];
        
        buf_re[18] <= buf_re[58];
        buf_im[18] <= buf_im[58];
        sync[18]   <= sync[58];
        
        buf_re[17] <= buf_re[122];
        buf_im[17] <= buf_im[122];
        sync[17]   <= sync[122];
        
        buf_re[16] <= buf_re[6];
        buf_im[16] <= buf_im[6];
        sync[16]   <= sync[6];
        
        buf_re[15] <= buf_re[70];
        buf_im[15] <= buf_im[70];
        sync[15]   <= sync[70];
        
        buf_re[14] <= buf_re[38];
        buf_im[14] <= buf_im[38];
        sync[14]   <= sync[38];
        
        buf_re[13] <= buf_re[102];
        buf_im[13] <= buf_im[102];
        sync[13]   <= sync[102];
        
        buf_re[12] <= buf_re[22];
        buf_im[12] <= buf_im[22];
        sync[12]   <= sync[22];
        
        buf_re[11] <= buf_re[86];
        buf_im[11] <= buf_im[86];
        sync[11]   <= sync[86];
        
        buf_re[10] <= buf_re[54];
        buf_im[10] <= buf_im[54];
        sync[10]   <= sync[54];
        
        buf_re[9] <= buf_re[118];
        buf_im[9] <= buf_im[118];
        sync[9]   <= sync[118];
        
        buf_re[8] <= buf_re[14];
        buf_im[8] <= buf_im[14];
        sync[8]   <= sync[14];
        
        buf_re[7] <= buf_re[78];
        buf_im[7] <= buf_im[78];
        sync[7]   <= sync[78];
        
        buf_re[6] <= buf_re[46];
        buf_im[6] <= buf_im[46];
        sync[6]   <= sync[46];
        
        buf_re[5] <= buf_re[110];
        buf_im[5] <= buf_im[110];
        sync[5]   <= sync[110];
        
        buf_re[4] <= buf_re[30];
        buf_im[4] <= buf_im[30];
        sync[4]   <= sync[30];
        
        buf_re[3] <= buf_re[94];
        buf_im[3] <= buf_im[94];
        sync[3]   <= sync[94];
        
        buf_re[2] <= buf_re[62];
        buf_im[2] <= buf_im[62];
        sync[2]   <= sync[62];
        
        buf_re[1] <= buf_re[126];
        buf_im[1] <= buf_im[126];
        sync[1]   <= sync[126];
        
        buf_re[0] <= buf_re[1];
        buf_im[0] <= buf_im[1];
        sync[0]   <= sync[1];

    end
end

assign  do_re = buf_re[DEPTH-1];
assign  do_im = buf_im[DEPTH-1];
assign  do_en = sync[DEPTH-1];

endmodule