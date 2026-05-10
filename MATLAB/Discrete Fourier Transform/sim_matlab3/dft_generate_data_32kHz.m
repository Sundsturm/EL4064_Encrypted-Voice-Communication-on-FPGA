
% 48 kHz -> scramble per 960 samples
% 32 kHz -> 640 samples
% WNnk LUT size: 640 x 640

clear variables
close all

% generate look-up table for WNnk (real + imag)
file_WNnk_real = fopen('WNnk_real.txt', 'w');
file_WNnk_imag = fopen('WNnk_imag.txt', 'w');

N = 640;
n = 0:1:N-1;           % row vector for n
k = 0:1:N-1;           % row vector for k
nk = n'*k;             % creates an N by N matrix of nk values
WN = exp(-1i*2*pi/N);  % Wn factor 
WNnk = WN .^ nk;       % DFT matrix

WNnk_real = real(WNnk);
WNnk_real = reshape(WNnk_real.', [1, N*N]); % flatten

WNnk_imag = imag(WNnk);
WNnk_imag = reshape(WNnk_imag.', [1, N*N]); % flatten

for i = 1:N*N
    fprintf(file_WNnk_real, '%0.25f\n', WNnk_real(i));
    fprintf(file_WNnk_imag, '%0.25f\n', WNnk_imag(i));
end

fclose(file_WNnk_real);
fclose(file_WNnk_imag);


%{
[yt, Fs] = audioread('input_audio_32kHz.wav'); 
xn = yt((N*100)+1:N*101).';

% matrix mult
Xk = xn * WNnk;
plot(abs(Xk));
%}
