clear variables
close all

[yt, Fs] = audioread('input_16kHz.wav'); 
xn = yt(32001:32320).';
N = length(xn);

n = 0:1:N-1;           % row vector for n
k = 0:1:N-1;           % row vecor for k
WN = exp(-1i*2*pi/N);  % Wn factor 
nk = n'*k;             % creates a N by N matrix of nk values
WNnk = WN .^ nk;       % DFT matrix
Xk = xn * WNnk;        % row vector for DFT coefficients

disp('The DFT of x(n) is Xk = ');
disp(Xk)
magXk = abs(Xk);       % The magnitude of the DFT
%%Implementing the inverse DFT (IDFT) in matrix notation

n = 0:1:N-1;           
k = 0:1:N-1;           
WN = exp(-1i*2*pi/N);  
nk = n'*k;             
WNnk = WN .^ (-nk);    % IDFS matrix
x_hat = (Xk * WNnk)/N; % row vector for IDFS values
disp('and the IDFT of x(n) is x_hat(n) = ');
disp(real(x_hat))

plot(magXk);
hold on;
%plot(16000/320*(0:320-1), abs(fft(yt(32001:32320).')))
plot(abs(fft(yt(32001:32320).')))
hold off;
title("y(32001:32320), manual (blue) vs built-in implementation (red) of FFT");
subtitle("There should be a perfect overlap (all red)")