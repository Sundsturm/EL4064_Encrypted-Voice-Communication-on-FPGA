clc;

N = 64;
t = 0:(N*floor(length(yt)/N)-1);
t = t.';
WAV_SRC = '../input_audio_32kHz.wav';

% input audio
[yt, Fs] = audioread(WAV_SRC); 
f_bi = [];
f_man = [];
for counter = 0:floor(length(yt)/N)-1
    xn = yt(N*counter+1:N*(counter+1));

    f_bi = cat(1, f_bi, fft(xn));
    f_man = cat(1, f_man, fft64(xn));
end

size(f_bi)

% built-in function
subplot(211);
plot(t, abs(real(f_bi)));
hold on;
plot(t, abs(imag(f_bi)));
hold off;
title('built-in FFT');

% manual function
subplot(212); 
plot(t, abs(real(f_man)));
hold on;
plot(t, abs(imag(f_man)));
hold off;
title('manual FFT');
title(['manual FFT - diff = ', num2str(sum(abs(f_bi-f_man))), ', (mean ', num2str(sum(abs(f_bi-f_man))/floor(length(yt)/N)), ')']);

% function declaration
function y = fft64(xn)

[x1, x2, x3, x4, x5, x6, y] = deal(zeros(64, 1));

% stage 1 -> N = 64, M = 64
for mm = 0:1:31

    twiddle = exp(-2 * pi * 1i * mm * 1/64);

    % index 1 with 33, 2 with 34, and so on
    x1(mm+1) = xn(mm+1) + xn(mm+33);
    x1(mm+33) = (xn(mm+1) - xn(mm+33)) * twiddle;
end

% stage 2 -> N = 64, M = 32
for mm = 0:1:15

    twiddle = exp(-2 * pi * 1i * mm * 1/32);

    % index 1 with 17, 2 with 18, and so on
    x2(mm+1) = x1(mm+1) + x1(mm+17);
    x2(mm+17) = (x1(mm+1) - x1(mm+17)) * twiddle;
    x2(mm+33) = (x1(mm+33) + x1(mm+49));
    x2(mm+49) = (x1(mm+33) - x1(mm+49)) * twiddle;
end

% stage 3 -> N = 64, M = 16
for mm = 0:1:7

    twiddle = exp(-2 * pi * 1i * mm * 1/16);

    x3(mm+1) = x2(mm+1) + x2(mm+9);
    x3(mm+9) = (x2(mm+1) - x2(mm+9)) * twiddle;
    x3(mm+17) = x2(mm+17) + x2(mm+25);
    x3(mm+25) = (x2(mm+17) - x2(mm+25)) * twiddle;
    x3(mm+33) = x2(mm+33) + x2(mm+41);
    x3(mm+41) = (x2(mm+33) - x2(mm+41)) * twiddle;
    x3(mm+49) = x3(mm+49) + x3(mm+57);
    x3(mm+57) = (x3(mm+49) - x3(mm+57)) * twiddle;
end

% stage 4 -> N = 64, M = 8
for mm = 0:1:3

    twiddle = exp(-2 * pi * 1i * mm * 1/8);

    x4(mm+1) = x3(mm+1) + x3(mm+5);
    x4(mm+5) = (x3(mm+1) - x3(mm+5)) * twiddle;
    x4(mm+9) = x3(mm+9) + x3(mm+13);
    x4(mm+13) = (x3(mm+9) - x3(mm+13)) * twiddle;
    x4(mm+17) = x3(mm+17) + x3(mm+21);
    x4(mm+21) = (x3(mm+17) - x3(mm+21)) * twiddle;
    x4(mm+25) = x3(mm+25) + x3(mm+29);
    x4(mm+29) = (x3(mm+25) - x3(mm+29)) * twiddle;
    x4(mm+33) = x3(mm+33) + x3(mm+37);
    x4(mm+37) = (x3(mm+33) - x3(mm+37)) * twiddle;
    x4(mm+41) = x3(mm+41) + x3(mm+45);
    x4(mm+45) = (x3(mm+41) - x3(mm+45)) * twiddle;
    x4(mm+49) = x3(mm+49) + x3(mm+53);
    x4(mm+53) = (x3(mm+49) - x3(mm+53)) * twiddle;
    x4(mm+57) = x3(mm+57) + x3(mm+61);
    x4(mm+61) = (x3(mm+57) - x3(mm+61)) * twiddle;
end

% stage 5 -> N = 64, M = 4
for mm = 0:1:1
    twiddle = exp(-2 * pi * 1i * mm * 1/4);

    x5(mm+1) = x4(mm+1) + x4(mm+3);
    x5(mm+3) = (x4(mm+1) - x4(mm+3)) * twiddle;
    x5(mm+5) = x4(mm+5) + x4(mm+7);
    x5(mm+7) = (x4(mm+5) - x4(mm+7)) * twiddle;
    x5(mm+9) = x4(mm+9) + x4(mm+11);
    x5(mm+11) = (x4(mm+9) - x4(mm+11)) * twiddle;
    x5(mm+13) = x4(mm+13) + x4(mm+15);
    x5(mm+15) = (x4(mm+13) - x4(mm+15)) * twiddle;
    x5(mm+17) = x4(mm+17) + x4(mm+19);
    x5(mm+19) = (x4(mm+17) - x4(mm+19)) * twiddle;
    x5(mm+21) = x4(mm+21) + x4(mm+23);
    x5(mm+23) = (x4(mm+21) - x4(mm+23)) * twiddle;
    x5(mm+25) = x4(mm+25) + x4(mm+27);
    x5(mm+27) = (x4(mm+25) - x4(mm+27)) * twiddle;
    x5(mm+29) = x4(mm+29) + x4(mm+31);
    x5(mm+31) = (x4(mm+29) - x4(mm+31)) * twiddle;
    x5(mm+33) = x4(mm+33) + x4(mm+35);
    x5(mm+35) = (x4(mm+33) - x4(mm+35)) * twiddle;
    x5(mm+37) = x4(mm+37) + x4(mm+39);
    x5(mm+39) = (x4(mm+37) - x4(mm+39)) * twiddle;
    x5(mm+41) = x4(mm+41) + x4(mm+43);
    x5(mm+43) = (x4(mm+41) - x4(mm+43)) * twiddle;
    x5(mm+45) = x4(mm+45) + x4(mm+47);
    x5(mm+47) = (x4(mm+45) - x4(mm+47)) * twiddle;
    x5(mm+49) = x4(mm+49) + x4(mm+51);
    x5(mm+51) = (x4(mm+49) - x4(mm+51)) * twiddle;
    x5(mm+53) = x4(mm+53) + x4(mm+55);
    x5(mm+55) = (x4(mm+53) - x4(mm+55)) * twiddle;
    x5(mm+57) = x4(mm+57) + x4(mm+59);
    x5(mm+59) = (x4(mm+57) - x4(mm+59)) * twiddle;
    x5(mm+61) = x4(mm+61) + x4(mm+63);
    x5(mm+63) = (x4(mm+61) - x4(mm+63)) * twiddle;
end

% stage 6 -> N = 64, M = 1/2
twiddle = exp(-2 * pi * 1i * mm * 1/2);

x6(01) = x5(01) + x5(02);
x6(02) = (x5(01) - x5(02)) * twiddle;
x6(03) = x5(03) + x5(04);
x6(04) = (x5(03) - x5(04)) * twiddle;
x6(05) = x5(05) + x5(06);
x6(06) = (x5(05) - x5(06)) * twiddle;
x6(07) = x5(07) + x5(08);
x6(08) = (x5(07) - x5(08)) * twiddle;
x6(09) = x5(09) + x5(10);
x6(10) = (x5(09) - x5(10)) * twiddle;
x6(11) = x5(11) + x5(12);
x6(12) = (x5(11) - x5(12)) * twiddle;
x6(13) = x5(13) + x5(14);
x6(14) = (x5(13) - x5(14)) * twiddle;
x6(15) = x5(15) + x5(16);
x6(16) = (x5(15) - x5(16)) * twiddle;
x6(17) = x5(17) + x5(18);
x6(18) = (x5(17) - x5(18)) * twiddle;
x6(19) = x5(19) + x5(20);
x6(20) = (x5(19) - x5(20)) * twiddle;
x6(21) = x5(21) + x5(22);
x6(22) = (x5(21) - x5(22)) * twiddle;
x6(23) = x5(23) + x5(24);
x6(24) = (x5(23) - x5(24)) * twiddle;
x6(25) = x5(25) + x5(26);
x6(26) = (x5(25) - x5(26)) * twiddle;
x6(27) = x5(27) + x5(28);
x6(28) = (x5(27) - x5(28)) * twiddle;
x6(29) = x5(29) + x5(30);
x6(30) = (x5(29) - x5(30)) * twiddle;
x6(31) = x5(31) + x5(32);
x6(32) = (x5(31) - x5(32)) * twiddle;
x6(33) = x5(33) + x5(34);
x6(34) = (x5(33) - x5(34)) * twiddle;
x6(35) = x5(35) + x5(36);
x6(36) = (x5(35) - x5(36)) * twiddle;
x6(37) = x5(37) + x5(38);
x6(38) = (x5(37) - x5(38)) * twiddle;
x6(39) = x5(39) + x5(40);
x6(40) = (x5(39) - x5(40)) * twiddle;
x6(41) = x5(41) + x5(42);
x6(42) = (x5(41) - x5(42)) * twiddle;
x6(43) = x5(43) + x5(44);
x6(44) = (x5(43) - x5(44)) * twiddle;
x6(45) = x5(45) + x5(46);
x6(46) = (x5(45) - x5(46)) * twiddle;
x6(47) = x5(47) + x5(48);
x6(48) = (x5(47) - x5(48)) * twiddle;
x6(49) = x5(49) + x5(50);
x6(50) = (x5(49) - x5(50)) * twiddle;
x6(51) = x5(51) + x5(52);
x6(52) = (x5(51) - x5(52)) * twiddle;
x6(53) = x5(53) + x5(54);
x6(54) = (x5(53) - x5(54)) * twiddle;
x6(55) = x5(55) + x5(56);
x6(56) = (x5(55) - x5(56)) * twiddle;
x6(57) = x5(57) + x5(58);
x6(58) = (x5(57) - x5(58)) * twiddle;
x6(59) = x5(59) + x5(60);
x6(60) = (x5(59) - x5(60)) * twiddle;
x6(61) = x5(61) + x5(62);
x6(62) = (x5(61) - x5(62)) * twiddle;
x6(63) = x5(63) + x5(64);
x6(64) = (x5(63) - x5(64)) * twiddle;

% reorder
%{ FFT order for N=64:
% [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64]
% [1 3 5 7 9 11 13 15 17 19 21 23 25 27 29 31 33 35 37 39 41 43 45 47 49 51 53 55 57 59 61 63] [2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48 50 52 54 56 58 60 62 64]
% [1 5 9 13 17 21 25 29 33 37 41 45 49 53 57 61] [3 7 11 15 19 23 27 31 35 39 43 47 51 55 59 63] [2 6 10 14 18 22 26 30 34 38 42 46 50 54 58 62] [4 8 12 16 20 24 28 32 36 40 44 48 52 56 60 64]
% [1 9 17 25 33 41 49 57] [5 13 21 29 37 45 53 61] [3 11 19 27 35 43 51 59] [7 15 23 31 39 47 55 63] [2 10 18 26 34 42 50 58] [6 14 22 30 38 46 54 62] [4 12 20 28 36 44 52 60] [8 16 24 32 40 48 56 64]
% [1 17 33 49] [9 25 41 57] [5 21 37 53] [13 29 45 61] [3 19 35 51] [11 27 43 59] [7 23 39 55] [15 31 47 63] [2 18 34 50] [10 26 42 58] [6 22 38 54] [14 30 46 62] [4 20 36 52] [12 28 44 60] [8 24 40 56] [16 32 48 64]
% 1 33 17 49 9 41 25 57 5 37 21 53 13 45 29 61 3 35 19 51 11 43 27 59 7 39 23 55 15 47 31 63 2 34 18 50 10 42 26 58 6 38 22 54 14 46 30 62 4 36 20 52 12 44 28 60 8 40 24 56 16 48 32 64
%}

indices = [1 33 17 49 9 41 25 57 5 37 21 53 13 45 29 61 3 35 19 51 11 43 27 59 7 39 23 55 15 47 31 63 2 34 18 50 10 42 26 58 6 38 22 54 14 46 30 62 4 36 20 52 12 44 28 60 8 40 24 56 16 48 32 64];
for i = 1:64
    y(i) = x6(indices(i));
end
end