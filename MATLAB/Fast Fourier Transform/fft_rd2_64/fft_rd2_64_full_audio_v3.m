close all;
clc;

% new in v3: fixed point

N = 64;
WAV_SRC = '../input_audio_32kHz.wav';

% input audio
[yt, Fs] = audioread(WAV_SRC); 

N_OF_WINDOWS = floor(length(yt)/N);
t = (0:(N * N_OF_WINDOWS) - 1).';

[f_bi, f_man_re, f_man_im] = deal([]);
for counter = 0:N_OF_WINDOWS-1

    xn = yt(N*counter + 1:N * (counter+1));

    f_bi = cat(1, f_bi, fft(xn));

    [f_man_1, f_man_2] = fft64(xn);
    f_man_re = cat(1, f_man_re, f_man_1);
    f_man_im = cat(1, f_man_im, f_man_2);
end

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
function [y_re, y_im] = fft64(x_fp)

    N = 64;
    WORD = 16;
    FRAC = 10;

    [x1_re, x2_re, x3_re, x4_re, x5_re, x6_re, y_re] = deal(zeros(64, 1));
    [x1_im, x2_im, x3_im, x4_im, x5_im, x6_im, y_im] = deal(zeros(64, 1));
    
    % convert input array to fixed point
    xn = zeros(N);
    for idx = 1:N
        xn(idx) = fi(x_fp(idx), 1, WORD, FRAC);
    end
    
    % stage 1
    for m = 0:1:(N/2 - 1)
    
        twiddle_re = cos(-2 * pi * m * 1/N);
        twiddle_im = sin(-2 * pi * m * 1/N);
    
        x1_re(m + 1) = xn(m + 1) + xn(m + 33);
        x1_re(m + 33) = (xn(m + 1) - xn(m + 33)) * twiddle_re;
        x1_im(m + 33) = (xn(m + 1) - xn(m + 33)) * twiddle_im;
    end
    
    % stage 2
    for m = 0:1:(N/4 - 1)
    
        twiddle_re = cos(-2 * pi * m * 2/N);
        twiddle_im = sin(-2 * pi * m * 2/N);
    
        for shiftB = (N/4+1):(N/4):(N*3/4+1)
            shiftA = shiftB - (N/4);

            x2_re(m + shiftA) = x1_re(m + shiftA) + x1_re(m + shiftB);
            x2_im(m + shiftA) = x1_im(m + shiftA) + x1_im(m + shiftB);
            x2_re(m + shiftB) = (x1_re(m + shiftA) - x1_re(m + shiftB)) * twiddle_re;
            x2_im(m + shiftB) = (x1_im(m + shiftA) - x1_im(m + shiftB)) * twiddle_im;
        end
    end
    
    % stage 3 -> N = 64, M = 16
    for m = 0:1:(N/8 - 1)
    
        twiddle_re = cos(-2 * pi * m * 4/N);
        twiddle_im = sin(-2 * pi * m * 4/N);
    
        for shiftB = (N/8+1):(N/8):(N*7/8+1)
            shiftA = shiftB - (N/8);

            x3_re(m + shiftA) = x2_re(m + shiftA) + x2_re(m + shiftB);
            x3_im(m + shiftA) = x2_im(m + shiftA) + x2_im(m + shiftB);
            x3_re(m + shiftB) = (x2_re(m + shiftA) - x2_re(m + shiftB)) * twiddle_re;
            x3_im(m + shiftB) = (x2_im(m + shiftA) - x2_im(m + shiftB)) * twiddle_im;
        end
    end
    
    % stage 4 -> N = 64, M = 8
    for m = 0:1:(N/16 - 1)
    
        twiddle_re = cos(-2 * pi * m * 8/N);
        twiddle_im = sin(-2 * pi * m * 8/N);
        
        for shiftB = (N/16+1):(N/16):(N*15/16+1)
            shiftA = shiftB - (N/16);

            x4_re(m + shiftA) = x3_re(m + shiftA) + x3_re(m + shiftB);
            x4_im(m + shiftA) = x3_im(m + shiftA) + x3_im(m + shiftB);
            x4_re(m + shiftB) = (x3_re(m + shiftA) - x3_re(m + shiftB)) * twiddle_re;
            x4_im(m + shiftB) = (x3_im(m + shiftA) - x3_im(m + shiftB)) * twiddle_im;
        end
    end
    
    % stage 5 -> N = 64, M = 4
    for m = 0:1:(N/32 - 1)
        twiddle_re = cos(-2 * pi * m * 16/N);
        twiddle_im = sin(-2 * pi * m * 16/N);
        
        for shiftB = (N/32+1):(N/32):(N*31/32+1)
            shiftA = shiftB - (N/32);

            x5_re(m + shiftA) = x4_re(m + shiftA) + x4_re(m + shiftB);
            x5_im(m + shiftA) = x4_im(m + shiftA) + x4_im(m + shiftB);
            x5_re(m + shiftB) = (x4_re(m + shiftA) - x4_re(m + shiftB)) * twiddle_re;
            x5_im(m + shiftB) = (x4_im(m + shiftA) - x4_im(m + shiftB)) * twiddle_im;
        end
    end
    
    % stage 6 -> N = 64, M = 1/2
    twiddle_re = cos(-2 * pi * m * 32/N);
    twiddle_im = sin(-2 * pi * m * 32/N);
    
    for shiftB = (N/64+1):(N/64):(N*63/64+1)
        shiftA = shiftB - (N/64);

        x6_re(shiftA) = x5_re(shiftA) + x5_re(shiftB);
        x6_im(shiftA) = x5_im(shiftA) + x5_im(shiftB);
        x6_re(shiftB) = (x5_re(shiftA) - x5_re(shiftB)) * twiddle_re;
        x6_im(shiftB) = (x5_im(shiftA) - x5_im(shiftB)) * twiddle_im;
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