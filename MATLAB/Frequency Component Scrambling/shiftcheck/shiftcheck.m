clc;close all;

N = 64;
WAV_SRC = 'audio1_32kHz.wav';
WAV_SCRAMBLED = 'output1_scrambled.wav';
WAV_RECON = 'out1_recon.wav';
WAV_RECON2 = 'out1_recon_v2.wav';

% input audio
[yt, Fs] = audioread(WAV_SRC); 
f_total = [];
f_total_ifft = [];
f_original = [];

for counter = 0:floor(length(yt)/N)-1
    xn = yt(N*counter+1:N*(counter+1));

    f_window = fft(xn);

    f_scramble = f_window;
    f_original = cat(1, f_original, f_window);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    f_scramble(1) = f_window(5);
    f_scramble(2) = f_window(6);
    f_scramble(3) = f_window(7);
    f_scramble(4) = f_window(8);
    f_scramble(5) = f_window(9);
    f_scramble(6) = f_window(10);
    f_scramble(7) = f_window(4);
    f_scramble(8) = f_window(3);
    f_scramble(9) = f_window(2);
    f_scramble(10) = f_window(1);

    f_scramble(55) = f_window(64);
    f_scramble(56) = f_window(63); 
    f_scramble(57) = f_window(62); 
    f_scramble(58) = f_window(61);
    f_scramble(59) = f_window(60); 
    f_scramble(60) = f_window(59); 
    f_scramble(61) = f_window(58);
    f_scramble(62) = f_window(57); 
    f_scramble(63) = f_window(56);
    f_scramble(64) = f_window(55); 

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

    f_window = fft(xn);

    f_scrambled = cat(1, f_scrambled, f_window);
    f_new = f_window;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    f_new(1) = f_window(10);
    f_new(2) = f_window(9);
    f_new(3) = f_window(8);
    f_new(4) = f_window(7);
    f_new(5) = f_window(6);
    f_new(6) = f_window(5);
    f_new(7) = f_window(4);
    f_new(8) = f_window(3);
    f_new(9) = f_window(2);
    f_new(10) = f_window(1);

    f_new(55) = f_window(64);
    f_new(56) = f_window(63); 
    f_new(57) = f_window(62); 
    f_new(58) = f_window(61);
    f_new(59) = f_window(60); 
    f_new(60) = f_window(59); 
    f_new(61) = f_window(58);
    f_new(62) = f_window(57); 
    f_new(63) = f_window(56);
    f_new(64) = f_window(55); 

    f_recon = cat(1, f_recon, f_new);
    f_recon_ifft = cat(1, f_recon_ifft, real(ifft(f_new)));
end
% % %
xn_recon_audio = f_recon_ifft;
audiowrite(WAV_RECON, xn_recon_audio, Fs);
% % %
sz = length(yt2);
yt2_v2 = cat(1, yt2(32:sz), yt2(1:32)); % geser sebanyak 32
yt2 = yt2_v2;
f_scrambled = [];
f_recon = [];
f_recon_ifft = [];
for counter = 0:floor(length(yt2)/N)-1
    xn = yt2(N*counter+1:N*(counter+1));

    f_window = fft(xn);

    f_scrambled = cat(1, f_scrambled, f_window);
    f_new = f_window;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    f_new(1) = f_window(15);
    f_new(2) = f_window(14);
    f_new(3) = f_window(13);
    f_new(4) = f_window(12);
    f_new(5) = f_window(11);
    f_new(6) = f_window(10);
    f_new(7) = f_window(4);
    f_new(8) = f_window(3);
    f_new(9) = f_window(2);
    f_new(10) = f_window(1);

    f_new(55) = f_window(64);
    f_new(56) = f_window(63); 
    f_new(57) = f_window(62); 
    f_new(58) = f_window(61);
    f_new(59) = f_window(60); 
    f_new(60) = f_window(59); 
    f_new(61) = f_window(58);
    f_new(62) = f_window(57); 
    f_new(63) = f_window(56);
    f_new(64) = f_window(55); 

    f_recon = cat(1, f_recon, f_new);
    f_recon_ifft = cat(1, f_recon_ifft, real(ifft(f_new)));
end

xn_recon_audio = f_recon_ifft;
audiowrite(WAV_RECON2, xn_recon_audio, Fs);

%%%

t = 6401:6464;
t = t.';

% original fft audio
subplot(411);
plot(t, abs(real(f_original(6401:6464))));
hold on;
plot(t, abs(imag(f_original(6401:6464))));
hold off;
title('FFT before scrambling');

% scrambled fft
subplot(412); 
plot(t, abs(real(f_total(6401:6464))));
hold on;
plot(t, abs(imag(f_total(6401:6464))));
hold off;
title('FFT after scrambling');

% scrambled fft->ifft->fft
subplot(413);
plot(t, abs(real(f_scrambled(6401:6464))));
hold on;
plot(t, abs(imag(f_scrambled(6401:6464))));
hold off;
title('FFT->IFFT->FFT after scrambling');

% reconstructed fft
subplot(414); 
plot(t, abs(real(f_recon(6401:6464))));
hold on;
plot(t, abs(imag(f_recon(6401:6464))));
hold off;
title('FFT after reconstruction');
