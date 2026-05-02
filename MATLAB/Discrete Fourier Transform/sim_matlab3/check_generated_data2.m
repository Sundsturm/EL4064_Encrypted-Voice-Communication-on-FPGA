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

% slice audio data into batches of N-sized samples each
xn = zeros(ceil(length(yt)/N), N); % should be 177
counter = 1;
for m = N:N:length(yt)
    xn(counter, :) = yt(N*(counter - 1) + 1:m, 1);
    counter = counter + 1;
end

% FFT using built-in MATLAB method
fft_bi = zeros(counter, N);
for m = 1:counter
    fft_bi(m, :) = fft(xn(m, :));
end

% DFT using matrix multiplication
dft_matmult = zeros(counter, N);
for m = 1:counter
    dft_matmult(m, :) = xn(m, :) * WNnk;
end

% plot
figure;
plot(abs(dft_matmult(100, :)));
hold on;
plot(abs(fft_bi(100, :)));
hold off;
