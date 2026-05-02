
Z = readmatrix("botol_fft_z.csv");

temp1 = Z(1, :);
ex = 1;
experiments = [
    0 1 2 3 4 5 6 7;
    4 5 6 7 0 1 2 3
    ];

length(experiments)