clear all; close all;

% PARAMETERS
Fs = 16000; 
duration = 0.05;
N = Fs * duration; 
t = (0:N-1) / Fs; 

% DTMF LOOKUP TABLE
dtmf_freqs = [697 770 852 941 1209 1336 1477];
dtmf_matrix = [697 770 852 941; 1209 1336 1477 0];
dtmf_row = containers.Map({'1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '*', '#'}, ...
                          {1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4});
dtmf_col = containers.Map({'1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '*', '#'}, ...
                          {1, 2, 3, 1, 2, 3, 1, 2, 3, 2, 1, 3});

tones = [
    sin(2 * pi * dtmf_matrix(1, dtmf_row('1')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('1')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('2')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('2')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('3')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('3')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('4')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('4')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('5')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('5')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('6')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('6')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('7')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('7')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('8')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('8')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('9')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('9')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('0')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('0')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('*')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('*')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('#')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('#')) * t)
    ];

% CONFIGURE INPUT HERE
yDTMF = tones(1,:);

% APPLY GOERTZEL ALGORITHM
k_indices = round(dtmf_freqs * N / Fs);
outputs = zeros(length(dtmf_freqs), 1);
filter_outputs = zeros(length(dtmf_freqs), N);
for i = 1:length(dtmf_freqs)
    [yn, outputs(i), filter_output] = goertzel4(yDTMF, k_indices(i));
    filter_outputs(i, :) = filter_output;
end

% PLOT 1
figure;
bar(dtmf_freqs, outputs);
title('DTMF Tone Detection using Goertzel Algorithm');
xlabel('Frequency (Hz)');
ylabel('Magnitude');
xticks(dtmf_freqs);
xticklabels(cellstr(num2str(dtmf_freqs')));
grid on;

% PLOT 2
figure;
for i = 1:length(dtmf_freqs)
    subplot(length(dtmf_freqs), 1, i);
    plot(t, filter_outputs(i, :));
    title(['Filter Output for ', num2str(dtmf_freqs(i)), ' Hz']);
    xlabel('Time (s)');
    ylabel('Amplitude');
    grid on;
end

threshold = 0.1 * max(outputs); % Adjust this threshold as needed
detected_freqs = dtmf_freqs(outputs > threshold);
low_freq = detected_freqs(detected_freqs < 1000);
high_freq = detected_freqs(detected_freqs > 1000);

if length(low_freq) == 1 && length(high_freq) == 1
    disp(['Detected frequencies: ' num2str(low_freq) ' Hz and ' num2str(high_freq) ' Hz']);
end

function [yn, Ak, filter_output] = goertzel4(x, k)
    % Goertzel Algorithm
    % [yn, Ak, filter_output] = goertzel4(x, k)
    % x = input vector; k = frequency index
    % yn = kth DFT coefficient; Ak = magnitude of the kth DFT coefficient
    % filter_output = output of the Goertzel filter for each sample
    N = length(x);
    x = [x 0];
    vk = zeros(1, N+3);
    filter_output = zeros(1, N);
    for n = 1:N+1
        vk(n+2) = 2*cos(2*pi*k/N)*vk(n+1) - vk(n) + x(n);
        if n <= N
            filter_output(n) = vk(n+2);
        end
    end
    yn = vk(N+3) - exp(-2*pi*1i*k/N)*vk(N+2);
    Xk = vk(N+3)*vk(N+3) + vk(N+2)*vk(N+2) - 2*cos(2*pi*k/N)*vk(N+3)*vk(N+2);
    Ak = sqrt(Xk)/N;
end