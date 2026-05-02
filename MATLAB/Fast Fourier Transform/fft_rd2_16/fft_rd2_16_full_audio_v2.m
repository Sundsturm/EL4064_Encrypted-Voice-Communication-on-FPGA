
% new in v2: separate imaginary and real parts
clc;

N = 16;
t = 0:(N*floor(length(yt)/N)-1);
WAV_SRC = '../input_audio_32kHz.wav';

% input audio
[yt, Fs] = audioread(WAV_SRC); 
res_fft_bi = [];
res_fft_man_r = [];
res_fft_man_i = [];
for counter = 0:floor(length(yt)/N)-1
    xn = yt(N*counter+1:N*(counter+1));

    res_fft_bi = cat(1, res_fft_bi, fft(xn));
    [res_r, res_i] = fft16(xn);
    res_fft_man_r = cat(1, res_fft_man_r, res_r);
    res_fft_man_i = cat(1, res_fft_man_i, res_i);
end

% built-in function
subplot(211);
plot(t, abs(real(res_fft_bi)));
hold on;
plot(t, abs(imag(res_fft_bi)));
hold off;
title('built-in FFT');

% manual function
subplot(212); 
plot(t, abs(res_fft_man_r));
hold on;
plot(t, abs(res_fft_man_i));
hold off;
res_fft_man = res_fft_man_r + i*(res_fft_man_i);
title(['manual FFT - diff = ', num2str(abs(sum(res_fft_man-res_fft_bi)))]);

% FFT function declaration
function [y_r, y_i] = fft16(x)
[x1, x2, x3, x4, y_r, y_i] = deal(zeros(16, 1));

for mm = 0:1:7
    twiddle = exp(-2*pi*1i*mm*1/16);

    x1(mm+1) = x(mm+1)  + x(mm+9);
    x1(mm+9) = (x(mm+1) - x(mm+9)) * twiddle;
end

for mm = 0:1:3
   	twiddle = exp(-2*pi*1i*mm*1/8);
   	x2(mm+1)  = x1(mm+1)  + x1(mm+5);
   	x2(mm+5)  = (x1(mm+1) - x1(mm+5)) * twiddle;
   	x2(mm+9)  = (x1(mm+9) + x1(mm+13));
   	x2(mm+13)  = (x1(mm+9) - x1(mm+13)) * twiddle;
end

for mm = 0:1:1
   	twiddle = exp(-2*pi*1i*mm*1/4);

   	x3(mm+1)  = x2(mm+1)  + x2(mm+3);
   	x3(mm+3)  = (x2(mm+1) - x2(mm+3)) * twiddle;
   	x3(mm+5)  = (x2(mm+5) + x2(mm+7));
   	x3(mm+7)  = (x2(mm+5) - x2(mm+7)) * twiddle;
   	x3(mm+9)  = (x2(mm+9) + x2(mm+11));
   	x3(mm+11)  = (x2(mm+9) - x2(mm+11)) * twiddle;  
   	x3(mm+13)  = (x2(mm+13) + x2(mm+15));
   	x3(mm+15)  = (x2(mm+13) - x2(mm+15)) * twiddle; 	
end

twiddle = exp(-2*pi*1i*0*1/2);

x4(1) = x3(1)  + x3(2);
x4(2) = (x3(1)  - x3(2)) * twiddle;
x4(3) = x3(3)  + x3(4);
x4(4) = (x3(3)  - x3(4)) * twiddle;
x4(5) = x3(5)  + x3(6);
x4(6) = (x3(5)  - x3(6)) * twiddle;
x4(7) = x3(7)  + x3(8);
x4(8) = (x3(7)  - x3(8)) * twiddle;
x4(9) = x3(9)  + x3(10);
x4(10) = (x3(9)  - x3(10)) * twiddle;
x4(11) = x3(11)  + x3(12);
x4(12) = (x3(11)  - x3(12)) * twiddle;
x4(13) = x3(13)  + x3(14);
x4(14) = (x3(13)  - x3(14)) * twiddle;
x4(15) = x3(15)  + x3(16);
x4(16) = (x3(15)  - x3(16)) * twiddle;
         
%reorder
y_r(1) = real(x4(1));
y_r(2) = real(x4(9));
y_r(3) = real(x4(5));
y_r(4) = real(x4(13));
y_r(5) = real(x4(3));
y_r(6) = real(x4(11));
y_r(7) = real(x4(7));
y_r(8) = real(x4(15));
y_r(9) = real(x4(2));
y_r(10) = real(x4(10));
y_r(11) = real(x4(6));
y_r(12) = real(x4(14));
y_r(13) = real(x4(4));
y_r(14) = real(x4(12));
y_r(15) = real(x4(8));
y_r(16) = real(x4(16));

y_i(1) = imag(x4(1));
y_i(2) = imag(x4(9));
y_i(3) = imag(x4(5));
y_i(4) = imag(x4(13));
y_i(5) = imag(x4(3));
y_i(6) = imag(x4(11));
y_i(7) = imag(x4(7));
y_i(8) = imag(x4(15));
y_i(9) = imag(x4(2));
y_i(10) = imag(x4(10));
y_i(11) = imag(x4(6));
y_i(12) = imag(x4(14));
y_i(13) = imag(x4(4));
y_i(14) = imag(x4(12));
y_i(15) = imag(x4(8));
y_i(16) = imag(x4(16));

end
