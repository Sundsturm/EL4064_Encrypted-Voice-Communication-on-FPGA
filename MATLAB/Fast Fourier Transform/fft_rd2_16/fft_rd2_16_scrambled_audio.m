clc;

WAV_SRC = '../input_audio_32kHz.wav';
WAV_SCRAMBLED = 'output_scrambled.wav';
WAV_RECON = 'out_recon.wav';

% input audio
[yt, Fs] = audioread(WAV_SRC); 

f_total = [];
f_total_ifft = [];
f_original = [];
for counter = 0:floor(length(yt)/N)-1
    xn = yt(N*counter+1:N*(counter+1));

    f_window = fft16(xn);

    f_scramble = f_window;
    f_original = cat(1, f_total, f_window);

    % 1 2 3 4 5 6 7 8 
    % VVV
    % 5 6 7 8 4 3 2 1
    f_scramble(1) = f_window(8);
    f_scramble(2) = f_window(7);
    f_scramble(3) = f_window(6);
    f_scramble(4) = f_window(5);
    f_scramble(5) = f_window(4);
    f_scramble(6) = f_window(3);
    f_scramble(7) = f_window(2);
    f_scramble(8) = f_window(1);

    f_total = cat(1, f_total, f_scramble);
    f_total_ifft = cat(1, f_total_ifft, real(ifft(f_scramble)));
end

%%% 

xn_scrambled_audio = f_total_ifft;
audiowrite(WAV_SCRAMBLED, xn_scrambled_audio, Fs);

%%%

% reconstructed audio
[yt2, Fs2] = audioread(WAV_SCRAMBLED);
f_scrambled = [];
f_recon = [];
f_recon_ifft = [];
for counter = 0:floor(length(yt2)/N)-1
    xn = yt2(N*counter+1:N*(counter+1));

    f_window = fft16(xn);

    f_scrambled = cat(1, f_scrambled, f_window);
    f_new = f_window;

    % 1 2 3 4 5 6 7 8 
    % VVV
    % 5 6 7 8 4 3 2 1
    f_new(1) = f_window(8);
    f_new(2) = f_window(7);
    f_new(3) = f_window(6);
    f_new(4) = f_window(5);
    f_new(5) = f_window(4);
    f_new(6) = f_window(3);
    f_new(7) = f_window(2);
    f_new(8) = f_window(1);

    f_recon = cat(1, f_recon, f_new);
    f_recon_ifft = cat(1, f_recon_ifft, real(ifft(f_new)));
end

%%% 

xn_recon_audio = f_recon_ifft;
audiowrite(WAV_RECON, xn_recon_audio, Fs);

%%%

t = 1601:1616;
t = t.';

% original fft audio
subplot(411);
plot(t, abs(real(f_original(1601:1616))));
hold on;
plot(t, abs(imag(f_original(1601:1616))));
hold off;
title('FFT before scrambling');

% scrambled fft
subplot(412); 
plot(t, abs(real(f_total(1601:1616))));
hold on;
plot(t, abs(imag(f_total(1601:1616))));
hold off;
title('FFT after scrambling');

% scrambled fft->ifft->fft
subplot(413);
plot(t, abs(real(f_scrambled(1601:1616))));
hold on;
plot(t, abs(imag(f_scrambled(1601:1616))));
hold off;
title('FFT->IFFT->FFT after scrambling');

% reconstructed fft
subplot(414); 
plot(t, abs(real(f_recon(1601:1616))));
hold on;
plot(t, abs(imag(f_recon(1601:1616))));
hold off;
title('FFT after reconstruction');

% function declaration
function y = fft16(x)
[x1, x2, x3, x4, y] = deal(zeros(16, 1));

% 8 x 2 computations
for mm = 0:1:7
    twiddle = exp(-2*pi*1i*mm*1/16);
    x1(mm+1) = x(mm+1)  + x(mm+9);
    x1(mm+9) = (x(mm+1) - x(mm+9)) * twiddle;
end

% 4 x 4 computations
for mm = 0:1:3
   	twiddle = exp(-2*pi*1i*mm*1/8);
   	x2(mm+1)  = x1(mm+1)  + x1(mm+5);
   	x2(mm+5)  = (x1(mm+1) - x1(mm+5)) * twiddle;
   	x2(mm+9)  = (x1(mm+9) + x1(mm+13));
   	x2(mm+13)  = (x1(mm+9) - x1(mm+13)) * twiddle;
end

% 2 x 8 computations
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

% 16 computations
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
y(1) = x4(1);
y(2) = x4(9);
y(3) = x4(5);
y(4) = x4(13);
y(5) = x4(3);
y(6) = x4(11);
y(7) = x4(7);
y(8) = x4(15);
y(9) = x4(2);
y(10) = x4(10);
y(11) = x4(6);
y(12) = x4(14);
y(13) = x4(4);
y(14) = x4(12);
y(15) = x4(8);
y(16) = x4(16);

end