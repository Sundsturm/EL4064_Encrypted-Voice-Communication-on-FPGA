% menggunakan kode function Goertzel dari textbook DSP oleh Jiang & Tan
% (failed attempt)

% PARAMETERS
Fs = 16000; 
duration = 0.02;
num_samples = Fs * duration; 
t = (0:num_samples-1) / Fs; 

% DTMF LOOKUP TABLE
dtmf_freqs = [697 770 852 941; 1209 1336 1477 0];
dtmf_row = containers.Map({'1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '*', '#'}, ...
                          {1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4});
dtmf_col = containers.Map({'1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '*', '#'}, ...
                          {1, 2, 3, 1, 2, 3, 1, 2, 3, 2, 1, 3});

tones = [
    sin(2 * pi * dtmf_freqs(1, dtmf_row('1')) * t) + sin(2 * pi * dtmf_freqs(2, dtmf_col('1')) * t);
    sin(2 * pi * dtmf_freqs(1, dtmf_row('2')) * t) + sin(2 * pi * dtmf_freqs(2, dtmf_col('2')) * t);
    sin(2 * pi * dtmf_freqs(1, dtmf_row('3')) * t) + sin(2 * pi * dtmf_freqs(2, dtmf_col('3')) * t);
    sin(2 * pi * dtmf_freqs(1, dtmf_row('4')) * t) + sin(2 * pi * dtmf_freqs(2, dtmf_col('4')) * t);
    sin(2 * pi * dtmf_freqs(1, dtmf_row('5')) * t) + sin(2 * pi * dtmf_freqs(2, dtmf_col('5')) * t);
    sin(2 * pi * dtmf_freqs(1, dtmf_row('6')) * t) + sin(2 * pi * dtmf_freqs(2, dtmf_col('6')) * t);
    sin(2 * pi * dtmf_freqs(1, dtmf_row('7')) * t) + sin(2 * pi * dtmf_freqs(2, dtmf_col('7')) * t);
    sin(2 * pi * dtmf_freqs(1, dtmf_row('8')) * t) + sin(2 * pi * dtmf_freqs(2, dtmf_col('8')) * t);
    sin(2 * pi * dtmf_freqs(1, dtmf_row('9')) * t) + sin(2 * pi * dtmf_freqs(2, dtmf_col('9')) * t);
    sin(2 * pi * dtmf_freqs(1, dtmf_row('0')) * t) + sin(2 * pi * dtmf_freqs(2, dtmf_col('0')) * t);
    sin(2 * pi * dtmf_freqs(1, dtmf_row('*')) * t) + sin(2 * pi * dtmf_freqs(2, dtmf_col('*')) * t);
    sin(2 * pi * dtmf_freqs(1, dtmf_row('#')) * t) + sin(2 * pi * dtmf_freqs(2, dtmf_col('#')) * t)
    ];

% CONFIGURE INPUT
inputX1 = [(4*rand(1, 320))-2, tones(1,:), 4*(rand(1, 320))-2];
inputName1 = '697 Hz v1';

inputX2 = [tones(1,:), 4*(rand(1, 320))-2];
inputName2 = '697 Hz v2';

inputX3 = [(4*rand(1, 320))-2, tones(1,:)];
inputName3 = '697 Hz v3';

goertzelFreq1 = 852;
goertzelFreq2 = 770;
goertzelFreq3 = 697;

% START COMPUTATION
fprintf('input: %s (%d samples); filter checks for %d Hz\n', inputName1, length(inputX1), goertzelFreq1);
out1_v1 = goertzel3(inputX1, goertzelFreq1, Fs);
Y1_v1 = out1_v1(1, :);

fprintf('input: %s (%d samples); filter checks for %d Hz\n', inputName2, length(inputX2), goertzelFreq1);
out1_v2 = goertzel3(inputX2, goertzelFreq1, Fs);
Y1_v2 = out1_v2(1, :);

fprintf('input: %s (%d samples); filter checks for %d Hz\n', inputName3, length(inputX3), goertzelFreq1);
out1_v3 = goertzel3(inputX3, goertzelFreq1, Fs);
Y1_v3 = out1_v3(1, :);
size(Y1_v1)


fprintf('input: %s (%d samples); filter checks for %d Hz\n', inputName1, length(inputX1), goertzelFreq2);
out2_v1 = goertzel3(inputX1, goertzelFreq2, Fs);
Y2_v1 = out2_v1(1, :);

fprintf('input: %s (%d samples); filter checks for %d Hz\n', inputName2, length(inputX2), goertzelFreq2);
out2_v2 = goertzel3(inputX2, goertzelFreq2, Fs);
Y2_v2 = out2_v2(1, :);

fprintf('input: %s (%d samples); filter checks for %d Hz\n', inputName3, length(inputX3), goertzelFreq2);
out2_v3 = goertzel3(inputX3, goertzelFreq2, Fs);
Y2_v3 = out2_v3(1, :);
size(Y2_v1)


fprintf('input: %s (%d samples); filter checks for %d Hz\n', inputName1, length(inputX1), goertzelFreq3);
out3_v1 = goertzel3(inputX1, goertzelFreq3, Fs);
Y3_v1 = out3_v1(1, :);

fprintf('input: %s (%d samples); filter checks for %d Hz\n', inputName2, length(inputX2), goertzelFreq3);
out3_v2 = goertzel3(inputX2, goertzelFreq3, Fs);
Y3_v2 = out3_v2(1, :);

fprintf('input: %s (%d samples); filter checks for %d Hz\n', inputName3, length(inputX3), goertzelFreq3);
out3_v3 = goertzel3(inputX3, goertzelFreq3, Fs);
Y3_v3 = out3_v3(1, :);
size(Y3_v1)
Y3_v1


% PLOTS
% list of plots:
% audio input v1, audio input v2, audio input v3
% goertzel filter for freq 1 for v1, v2, v3
% goertzel filter for freq 2 for v1, v2, v3
% goertzel filter for freq 3 for v1, v2, v3

tiledlayout(4,3)

p1_1 = nexttile;
plot(inputX1)
title(sprintf('%s',inputName1));
p1_2 = nexttile;
plot(inputX2)
title(sprintf('%s',inputName2));
p1_3 = nexttile;
plot(inputX3)
title(sprintf('%s',inputName3));

p2_1 = nexttile;
plot(Y1_v1)
title(sprintf('%d Hz for input v1',goertzelFreq1))
p2_2 = nexttile;
plot(Y1_v2)
title(sprintf('%d Hz for input v2',goertzelFreq1))
p2_3 = nexttile;
plot(Y1_v3)
title(sprintf('%d Hz for input v3',goertzelFreq1))

p3_1 = nexttile;
plot(Y2_v1)
title(sprintf('%d Hz for input v1',goertzelFreq2))
p3_2 = nexttile;
plot(Y2_v2)
title(sprintf('%d Hz for input v2',goertzelFreq2))
p3_3 = nexttile;
plot(Y2_v3)
title(sprintf('%d Hz for input v3',goertzelFreq2))

p4_1 = nexttile;
plot(Y3_v1)
title(sprintf('%d Hz for input v1',goertzelFreq3))
p4_2 = nexttile;
plot(Y3_v2)
title(sprintf('%d Hz for input v2',goertzelFreq3))
p4_3 = nexttile;
plot(Y3_v3)
title(sprintf('%d Hz for input v3',goertzelFreq3))

% Goertzel implementation
% [Xk, Ak] = galg(x,k)
% x = input vector; k = frequency index
% Xk = kth DFT coeficient; Ak = magnitude of the kth DFT coefficient
function [yn, Ak] = goertzel3(x,f,fs)
    k = (f/fs) * length(x);
    N = length(x); 
    x = [x 0];
    vk = zeros(1,N+3);

    for n=1:N+1
        vk(n+2) = 2*cos(2*pi*k/N)*vk(n+1) - vk(n) + x(n);
    end

    yn = vk(N+3) - exp(-2*pi*j*k/N)*vk(N+2);
    Xk = vk(N+3)*vk(N+3) + vk(N+2)*vk(N+2) - 2*cos(2*pi*k/N)*vk(N+3)*vk(N+2);
    Ak = sqrt(Xk)/N;

end
