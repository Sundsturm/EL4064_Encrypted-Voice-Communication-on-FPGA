% seperti goertzel2, tetapi menggunakan formula dari textbook DSP (Tan, Jiang, 2018)
% belum menguji input dengan padding kosong/noise

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

% INPUT
inputX = tones(1,:);
inputName = '697 Hz';

fprintf('input: %s (%d samples); filter checks for 697 Hz\n',inputName,length(inputX));
Y1 = goertzel3(inputX, 697, Fs);

fprintf('input: %s (%d samples); filter checks for 941 Hz\n',inputName,length(inputX));
Y2 = goertzel3(inputX, 941, Fs);

fprintf('input: %s (%d samples); filter checks for 1336 Hz\n',inputName,length(inputX));
Y3 = goertzel3(inputX, 1336, Fs);

% plot
tiledlayout(4,1)
p1 = nexttile
plot(inputX)
title(sprintf('Input tone %s',inputName));
p2 = nexttile
plot(Y1)
title('Y1 - 697 Hz')
p3 = nexttile
plot(Y2)
title('Y2 - 941 Hz')
p4 = nexttile
plot(Y3)
title('Y3 - 1336 Hz')
%linkaxes([p2 p3 p4],'xy')

% goertzel implementation
function Y = goertzel3(X, f, fs)
    k = (f/fs)*length(X);
    Y = zeros(size(X));

    for m = 3:length(Y)
        Y(m) = (2 * cos(2*pi*k) * Y(m-1)) - Y(m) + X(m);
    end
end