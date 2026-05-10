
clear variables
close all

% generate look-up table for WNnk (real + imag)
file_WNnk_real = fopen('WNnk_real.txt', 'w');
file_WNnk_imag = fopen('WNnk_imag.txt', 'w');

N = 320;
n = 0:1:N-1;           % row vector for n
k = 0:1:N-1;           % row vector for k
nk = n'*k;             % creates an N by N matrix of nk values
WN = exp(-1i*2*pi/N);  % Wn factor 
WNnk = WN .^ nk;       % DFT matrix

WNnk_real = real(WNnk);
reshape(WNnk_real.',1,[]); % flatten

WNnk_imag = imag(WNnk);
reshape(WNnk_imag.',1,[]); % flatten

for i = 1:N*N
    fprintf(file_WNnk_real, '%0.15f\n', WNnk_real(i));
    fprintf(file_WNnk_imag, '%0.15f\n', WNnk_imag(i));
end

fclose(file_WNnk_real);
fclose(file_WNnk_imag);

%[yt, Fs] = audioread('input_16kHz.wav'); 
%xn = yt(32001:32320).';
%N = length(xn);