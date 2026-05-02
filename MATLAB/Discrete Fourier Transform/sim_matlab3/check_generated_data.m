clear variables
close all

N = 640;

% read WNnk
WNnk_real = importdata('WNnk_real.txt');
WNnk_imag = importdata('WNnk_imag.txt');
WNnk = reshape(WNnk_real + WNnk_imag, [N, N]);

% input audio
[yt, Fs] = audioread('input_audio_32kHz.wav'); 
xn = yt((N*100)+1:N*101).'; % Z(100, :);

% matrix mult
Xk = xn * WNnk;
figure;
plot(abs(Xk));

% quick ifft check
figure;
plot(ifft(Xk));
hold on;
plot(xn);
hold off;