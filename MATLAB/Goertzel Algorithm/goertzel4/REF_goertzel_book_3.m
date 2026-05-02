% DTMF tone generator and detector using Goertzel Algorithm
clear all; close all;

N = 205;
fs = 8000;
t = [0:1:N-1] / fs;
x = zeros(1, length(t));
x(1) = 1; % Impulse function

% Generation of tones
y697 = filter([0 sin(2*pi*697/fs)], [1 -2*cos(2*pi*697/fs) 1], x);
y770 = filter([0 sin(2*pi*770/fs)], [1 -2*cos(2*pi*770/fs) 1], x);
y852 = filter([0 sin(2*pi*852/fs)], [1 -2*cos(2*pi*852/fs) 1], x);
y941 = filter([0 sin(2*pi*941/fs)], [1 -2*cos(2*pi*941/fs) 1], x);
y1209 = filter([0 sin(2*pi*1209/fs)], [1 -2*cos(2*pi*1209/fs) 1], x);
y1336 = filter([0 sin(2*pi*1336/fs)], [1 -2*cos(2*pi*1336/fs) 1], x);
y1477 = filter([0 sin(2*pi*1477/fs)], [1 -2*cos(2*pi*1477/fs) 1], x);

% Select key input
key = input('Input key (1-9, *, 0, #): ', 's');
yDTMF = [];
switch key
    case '1', yDTMF = y697 + y1209;
    case '2', yDTMF = y697 + y1336;
    case '3', yDTMF = y697 + y1477;
    case '4', yDTMF = y770 + y1209;
    case '5', yDTMF = y770 + y1336;
    case '6', yDTMF = y770 + y1477;
    case '7', yDTMF = y852 + y1209;
    case '8', yDTMF = y852 + y1336;
    case '9', yDTMF = y852 + y1477;
    case '*', yDTMF = y941 + y1209;
    case '0', yDTMF = y941 + y1336;
    case '#', yDTMF = y941 + y1477;
    otherwise, disp('Invalid input'); return;
end

% DTMF detector using Goertzel algorithm
freqs = [697, 770, 852, 941, 1209, 1336, 1477];
k_indices = round(freqs * N / fs);

% Apply Goertzel algorithm for each frequency
outputs = zeros(length(freqs), 1);
filter_outputs = zeros(length(freqs), N);
for i = 1:length(freqs)
    [yn, outputs(i), filter_output] = galg(yDTMF, k_indices(i));
    filter_outputs(i, :) = filter_output;
end

% Plot the magnitude outputs
figure;
bar(freqs, outputs);
title('DTMF Tone Detection using Goertzel Algorithm');
xlabel('Frequency (Hz)');
ylabel('Magnitude');
xticks(freqs);
xticklabels(cellstr(num2str(freqs')));
grid on;

% Plot each filter's output
figure;
for i = 1:length(freqs)
    subplot(length(freqs), 1, i);
    plot(t, filter_outputs(i, :));
    title(['Filter Output for ', num2str(freqs(i)), ' Hz']);
    xlabel('Time (s)');
    ylabel('Amplitude');
    grid on;
end

% Determine which frequencies are present
threshold = 0.1 * max(outputs); % Adjust this threshold as needed
detected_freqs = freqs(outputs > threshold);

% Determine the pressed key based on detected frequencies
low_freq = detected_freqs(detected_freqs < 1000);
high_freq = detected_freqs(detected_freqs > 1000);

if length(low_freq) == 1 && length(high_freq) == 1
    disp(['Detected frequencies: ' num2str(low_freq) ' Hz and ' num2str(high_freq) ' Hz']);
    disp(['Detected key: ' key]);
else
    disp('Could not reliably detect the pressed key');
end

function [yn, Ak, filter_output] = galg(x, k)
    % Goertzel Algorithm
    % [yn, Ak, filter_output] = galg(x, k)
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