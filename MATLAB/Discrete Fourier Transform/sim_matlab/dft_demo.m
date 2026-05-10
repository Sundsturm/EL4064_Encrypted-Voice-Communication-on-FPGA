
[yt, Fs] = audioread('input_16kHz.wav'); 
L = 320;  

% Z(100, :)
% 320-points
Y = fft(yt(32001:32320).');

figure;
plot(abs(imag(Y)), "LineWidth", 1)
title("abs(imag(fft(y)))");

figure;
plot(abs(real(Y)), "LineWidth", 1)
title("abs(real(fft(y)))");

figure;
plot(abs(Y), "LineWidth", 1)
title("abs(fft(y))");

ynew = ifft(Y);

figure;
plot(yt(32001:32320).');
hold on;
plot(ynew);
hold off;
title("y(32001:32320), original vs FFT->IFFT");
subtitle("There should be a perfect overlap (all red)")