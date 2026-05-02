close all;
clc;

% v4: printouts

N = 64;
WORD = 16;
FRAC = 10;

WAV_SRC = '../../input_audio_32kHz.wav';

WRITETO_WAV_DEC = 'v4_printout_wav_decimal.txt';
WRITETO_WAV_BIN = 'v4_printout_wav_binary.txt';

WRITETO_FFT_DEC_R = 'v4_printout_fft_decimal_r.txt';
WRITETO_FFT_DEC_I = 'v4_printout_fft_decimal_i.txt';
WRITETO_FFT_BIN_R = 'v4_printout_fft_binary_r.txt';
WRITETO_FFT_BIN_I = 'v4_printout_fft_binary_i.txt';

WRITETO_TWIDDLE_DEC_R = 'v4_printout_twiddle_decimal_r.txt';
WRITETO_TWIDDLE_DEC_I = 'v4_printout_twiddle_decimal_i.txt';
WRITETO_TWIDDLE_BIN_R = 'v4_printout_twiddle_binary_r.txt';
WRITETO_TWIDDLE_BIN_I = 'v4_printout_twiddle_binary_i.txt';

WRITETO_X1_DEC_R = 'v4_printout_x1_decimal_r.txt';
WRITETO_X1_DEC_I = 'v4_printout_x1_decimal_i.txt';
WRITETO_X1_BIN_R = 'v4_printout_x1_binary_r.txt';
WRITETO_X1_BIN_I = 'v4_printout_x1_binary_i.txt';

WRITETO_X2_DEC_R = 'v4_printout_x2_decimal_r.txt';
WRITETO_X2_DEC_I = 'v4_printout_x2_decimal_i.txt';
WRITETO_X2_BIN_R = 'v4_printout_x2_binary_r.txt';
WRITETO_X2_BIN_I = 'v4_printout_x2_binary_i.txt';

WRITETO_X3_DEC_R = 'v4_printout_x3_decimal_r.txt';
WRITETO_X3_DEC_I = 'v4_printout_x3_decimal_i.txt';
WRITETO_X3_BIN_R = 'v4_printout_x3_binary_r.txt';
WRITETO_X3_BIN_I = 'v4_printout_x3_binary_i.txt';

WRITETO_X4_DEC_R = 'v4_printout_x4_decimal_r.txt';
WRITETO_X4_DEC_I = 'v4_printout_x4_decimal_i.txt';
WRITETO_X4_BIN_R = 'v4_printout_x4_binary_r.txt';
WRITETO_X4_BIN_I = 'v4_printout_x4_binary_i.txt';

WRITETO_X5_DEC_R = 'v4_printout_x5_decimal_r.txt';
WRITETO_X5_DEC_I = 'v4_printout_x5_decimal_i.txt';
WRITETO_X5_BIN_R = 'v4_printout_x5_binary_r.txt';
WRITETO_X5_BIN_I = 'v4_printout_x5_binary_i.txt';

WRITETO_X6_DEC_R = 'v4_printout_x6_decimal_r.txt';
WRITETO_X6_DEC_I = 'v4_printout_x6_decimal_i.txt';
WRITETO_X6_BIN_R = 'v4_printout_x6_binary_r.txt';
WRITETO_X6_BIN_I = 'v4_printout_x6_binary_i.txt';

% input audio
[yt, Fs] = audioread(WAV_SRC);

%writelines_dec_and_bin(WRITETO_WAV_DEC, WRITETO_WAV_BIN, yt, WORD, FRAC);

N_OF_WINDOWS = floor(length(yt)/N);
t = (0:(N * N_OF_WINDOWS) - 1).';

[f_bi, f_man_re, f_man_im] = deal([]);
for counter = 0:N_OF_WINDOWS-1
    disp([num2str(counter), '/', num2str(N_OF_WINDOWS-1)]);
    xn = yt(N*counter + 1:N * (counter+1));

    f_bi = cat(1, f_bi, fft(xn));

    [f_man_1, f_man_2, twiddle_r, twiddle_i, ...
        x1_r, x1_i, x2_r, x2_i, x3_r, x3_i, ...
        x4_r, x4_i, x5_r, x5_i, x6_r, x6_i] = fft64(xn, WORD, FRAC);

    f_man_re = cat(1, f_man_re, f_man_1);
    f_man_im = cat(1, f_man_im, f_man_2);
end

writelines_dec_and_bin(WRITETO_FFT_DEC_R, WRITETO_FFT_BIN_R, f_man_re, WORD, FRAC);
writelines_dec_and_bin(WRITETO_FFT_DEC_I, WRITETO_FFT_BIN_I, f_man_im, WORD, FRAC);

writelines_dec_and_bin(WRITETO_TWIDDLE_DEC_R, WRITETO_TWIDDLE_BIN_R, twiddle_r, WORD, FRAC);
writelines_dec_and_bin(WRITETO_TWIDDLE_DEC_I, WRITETO_TWIDDLE_BIN_I, twiddle_i, WORD, FRAC);

writelines_dec_and_bin(WRITETO_X1_DEC_R, WRITETO_X1_BIN_R, x1_r, WORD, FRAC);
writelines_dec_and_bin(WRITETO_X1_DEC_I, WRITETO_X1_BIN_I, x1_i, WORD, FRAC);
writelines_dec_and_bin(WRITETO_X2_DEC_R, WRITETO_X2_BIN_R, x2_r, WORD, FRAC);
writelines_dec_and_bin(WRITETO_X2_DEC_I, WRITETO_X2_BIN_I, x2_i, WORD, FRAC);
writelines_dec_and_bin(WRITETO_X3_DEC_R, WRITETO_X3_BIN_R, x3_r, WORD, FRAC);
writelines_dec_and_bin(WRITETO_X3_DEC_I, WRITETO_X3_BIN_I, x3_i, WORD, FRAC);
writelines_dec_and_bin(WRITETO_X4_DEC_R, WRITETO_X4_BIN_R, x4_r, WORD, FRAC);
writelines_dec_and_bin(WRITETO_X4_DEC_I, WRITETO_X4_BIN_I, x4_i, WORD, FRAC);
writelines_dec_and_bin(WRITETO_X5_DEC_R, WRITETO_X5_BIN_R, x5_r, WORD, FRAC);
writelines_dec_and_bin(WRITETO_X5_DEC_I, WRITETO_X5_BIN_I, x5_i, WORD, FRAC);
writelines_dec_and_bin(WRITETO_X6_DEC_R, WRITETO_X6_BIN_R, x6_r, WORD, FRAC);
writelines_dec_and_bin(WRITETO_X6_DEC_I, WRITETO_X6_BIN_I, x6_i, WORD, FRAC);

% built-in function
subplot(211);
plot(t, abs(real(f_bi)));
hold on;
plot(t, abs(imag(f_bi)));
hold off;
title('built-in FFT');

% manual function
subplot(212); 
plot(t, abs(f_man_re));
hold on;
plot(t, abs(f_man_im));
hold off;
title('manual FFT');
title([ ...
    'manual FFT - diff = ', ...
    num2str(sum(abs(f_bi-(f_man_re + f_man_im*1i)))), ...
    ', (mean ', ...
    num2str(sum(abs(f_bi-(f_man_re + f_man_im*1i)))/floor(length(yt)/N)), ...
    ')']);

% FFT64 function declaration
function [y_re, y_im, twiddle_r, twiddle_i, x1_re, x1_im, x2_re, ...
    x2_im, x3_re, x3_im, x4_re, x4_im, x5_re, x5_im, x6_re, x6_im] = fft64(x_fp, word, frac)

    N = 64;
    WORD = word;
    FRAC = frac;
    
    [twiddle_r, twiddle_i] = deal([]);
    [x1_re, x2_re, x3_re, x4_re, x5_re, x6_re, y_re] = deal(zeros(64, 1));
    [x1_im, x2_im, x3_im, x4_im, x5_im, x6_im, y_im] = deal(zeros(64, 1));
    
    % convert input array to fixed point
    xn = zeros(N);
    for idx = 1:N
        xn(idx) = fi(x_fp(idx), 1, WORD, FRAC);
    end
    
    % stage 1
    for m = 0:1:(N/2 - 1)
    
        twiddle_re = fi(cos(-2 * pi * m * 1/N), 1, WORD, FRAC);
        twiddle_im = fi(sin(-2 * pi * m * 1/N), 1, WORD, FRAC);

        twiddle_r = [twiddle_r twiddle_re];
        twiddle_i = [twiddle_i twiddle_im];
    
        x1_re(m + 1) = fi(xn(m + 1) + xn(m + 33), 1, WORD, FRAC);
        x1_re(m + 33) = fi((xn(m + 1) - xn(m + 33)) * twiddle_re, 1, WORD, FRAC);
        x1_im(m + 33) = fi((xn(m + 1) - xn(m + 33)) * twiddle_im, 1, WORD, FRAC);
    end
    
    % stage 2
    for m = 0:1:(N/4 - 1)

        twiddle_re = fi(cos(-2 * pi * m * 2/N), 1, WORD, FRAC);
        twiddle_im = fi(sin(-2 * pi * m * 2/N), 1, WORD, FRAC);

        twiddle_r = [twiddle_r twiddle_re];
        twiddle_i = [twiddle_i twiddle_im];
    
        for shiftB = (N/4+1):(N/4):(N*3/4+1)
            shiftA = shiftB - (N/4);

            x2_re(m + shiftA) = fi(x1_re(m + shiftA) + x1_re(m + shiftB), 1, WORD, FRAC);
            x2_im(m + shiftA) = fi(x1_im(m + shiftA) + x1_im(m + shiftB), 1, WORD, FRAC);
            x2_re(m + shiftB) = fi((x1_re(m + shiftA) - x1_re(m + shiftB)) * twiddle_re, 1, WORD, FRAC);
            x2_im(m + shiftB) = fi((x1_im(m + shiftA) - x1_im(m + shiftB)) * twiddle_im, 1, WORD, FRAC);
        end
    end
    
    % stage 3 -> N = 64, M = 16
    for m = 0:1:(N/8 - 1)
    
        twiddle_re = fi(cos(-2 * pi * m * 4/N), 1, WORD, FRAC);
        twiddle_im = fi(sin(-2 * pi * m * 4/N), 1, WORD, FRAC);

        twiddle_r = [twiddle_r twiddle_re];
        twiddle_i = [twiddle_i twiddle_im];
    
        for shiftB = (N/8+1):(N/8):(N*7/8+1)
            shiftA = shiftB - (N/8);

            x3_re(m + shiftA) = fi(x2_re(m + shiftA) + x2_re(m + shiftB), 1, WORD, FRAC);
            x3_im(m + shiftA) = fi(x2_im(m + shiftA) + x2_im(m + shiftB), 1, WORD, FRAC);
            x3_re(m + shiftB) = fi((x2_re(m + shiftA) - x2_re(m + shiftB)) * twiddle_re, 1, WORD, FRAC);
            x3_im(m + shiftB) = fi((x2_im(m + shiftA) - x2_im(m + shiftB)) * twiddle_im, 1, WORD, FRAC);
        end
    end
    
    % stage 4 -> N = 64, M = 8
    for m = 0:1:(N/16 - 1)
    
        twiddle_re = fi(cos(-2 * pi * m * 8/N), 1, WORD, FRAC);
        twiddle_im = fi(sin(-2 * pi * m * 8/N), 1, WORD, FRAC);

        twiddle_r = [twiddle_r twiddle_re];
        twiddle_i = [twiddle_i twiddle_im];
        
        for shiftB = (N/16+1):(N/16):(N*15/16+1)
            shiftA = shiftB - (N/16);

            x4_re(m + shiftA) = fi(x3_re(m + shiftA) + x3_re(m + shiftB), 1, WORD, FRAC);
            x4_im(m + shiftA) = fi(x3_im(m + shiftA) + x3_im(m + shiftB), 1, WORD, FRAC);
            x4_re(m + shiftB) = fi((x3_re(m + shiftA) - x3_re(m + shiftB)) * twiddle_re, 1, WORD, FRAC);
            x4_im(m + shiftB) = fi((x3_im(m + shiftA) - x3_im(m + shiftB)) * twiddle_im, 1, WORD, FRAC);
        end
    end
    
    % stage 5 -> N = 64, M = 4
    for m = 0:1:(N/32 - 1)

        twiddle_re = fi(cos(-2 * pi * m * 16/N), 1, WORD, FRAC);
        twiddle_im = fi(sin(-2 * pi * m * 16/N), 1, WORD, FRAC);

        twiddle_r = [twiddle_r twiddle_re];
        twiddle_i = [twiddle_i twiddle_im];
        
        for shiftB = (N/32+1):(N/32):(N*31/32+1)
            shiftA = shiftB - (N/32);

            x5_re(m + shiftA) = fi(x4_re(m + shiftA) + x4_re(m + shiftB), 1, WORD, FRAC);
            x5_im(m + shiftA) = fi(x4_im(m + shiftA) + x4_im(m + shiftB), 1, WORD, FRAC);
            x5_re(m + shiftB) = fi((x4_re(m + shiftA) - x4_re(m + shiftB)) * twiddle_re, 1, WORD, FRAC);
            x5_im(m + shiftB) = fi((x4_im(m + shiftA) - x4_im(m + shiftB)) * twiddle_im, 1, WORD, FRAC);
        end
    end
    
    % stage 6 -> N = 64, M = 1/2

    twiddle_re = fi(cos(-2 * pi * m * 32/N), 1, WORD, FRAC);
    twiddle_im = fi(sin(-2 * pi * m * 32/N), 1, WORD, FRAC);

    twiddle_r = [twiddle_r twiddle_re];
    twiddle_i = [twiddle_i twiddle_im];
    
    for shiftB = (N/64+1):(N/64):(N*63/64+1)
        shiftA = shiftB - (N/64);

        x6_re(shiftA) = fi(x5_re(shiftA) + x5_re(shiftB), 1, WORD, FRAC);
        x6_im(shiftA) = fi(x5_im(shiftA) + x5_im(shiftB), 1, WORD, FRAC);
        x6_re(shiftB) = fi((x5_re(shiftA) - x5_re(shiftB)) * twiddle_re, 1, WORD, FRAC);
        x6_im(shiftB) = fi((x5_im(shiftA) - x5_im(shiftB)) * twiddle_im, 1, WORD, FRAC);
    end
    
    % reorder
    % FFT order for N=64:
    % [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64]
    % [1 3 5 7 9 11 13 15 17 19 21 23 25 27 29 31 33 35 37 39 41 43 45 47 49 51 53 55 57 59 61 63] [2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48 50 52 54 56 58 60 62 64]
    % [1 5 9 13 17 21 25 29 33 37 41 45 49 53 57 61] [3 7 11 15 19 23 27 31 35 39 43 47 51 55 59 63] [2 6 10 14 18 22 26 30 34 38 42 46 50 54 58 62] [4 8 12 16 20 24 28 32 36 40 44 48 52 56 60 64]
    % [1 9 17 25 33 41 49 57] [5 13 21 29 37 45 53 61] [3 11 19 27 35 43 51 59] [7 15 23 31 39 47 55 63] [2 10 18 26 34 42 50 58] [6 14 22 30 38 46 54 62] [4 12 20 28 36 44 52 60] [8 16 24 32 40 48 56 64]
    % [1 17 33 49] [9 25 41 57] [5 21 37 53] [13 29 45 61] [3 19 35 51] [11 27 43 59] [7 23 39 55] [15 31 47 63] [2 18 34 50] [10 26 42 58] [6 22 38 54] [14 30 46 62] [4 20 36 52] [12 28 44 60] [8 24 40 56] [16 32 48 64]
    % 1 33 17 49 9 41 25 57 5 37 21 53 13 45 29 61 3 35 19 51 11 43 27 59 7 39 23 55 15 47 31 63 2 34 18 50 10 42 26 58 6 38 22 54 14 46 30 62 4 36 20 52 12 44 28 60 8 40 24 56 16 48 32 64
    %
    
    indices = [1 33 17 49 9 41 25 57 5 37 21 53 13 45 29 61 3 35 19 51 ...
        11 43 27 59 7 39 23 55 15 47 31 63 2 34 18 50 10 42 26 58 6 38 ...
        22 54 14 46 30 62 4 36 20 52 12 44 28 60 8 40 24 56 16 48 32 64];

    for i = 1:N
        y_re(i) = x6_re(indices(i));
        y_im(i) = x6_im(indices(i));
    end
end

function writelines_dec_and_bin(fn_dec, fn_bin, decimal_arr, word, frac)
    f_dec = fopen(fn_dec, 'w');
    f_bin = fopen(fn_bin, 'w');
    q = quantizer([word frac]);

    for i = 1:length(decimal_arr)
        dec_element = fi(decimal_arr(i), 1, word, frac);
        bin_element = ['0b' num2bin(q, double(decimal_arr(i)))];

        fprintf(f_dec, num2str(dec_element));
        fprintf(f_dec, '\n');

        fprintf(f_bin, bin_element);
        fprintf(f_bin, '\n');
    end
end
