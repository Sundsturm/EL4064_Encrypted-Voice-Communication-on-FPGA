% Define DTMF frequencies
dtmf_freqs = [697 770 852 941; 1209 1336 1477 0];

% Define the DTMF mapping for digits 0-9, *, and #
dtmf_map = containers.Map({'1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '*', '#'}, ...
                          {[1 1], [1 2], [1 3], [2 1], [2 2], [2 3], [3 1], [3 2], [3 3], [4 2], [4 1], [4 3]});

% Parameters
Fs = 8000; % Sampling frequency
duration = 0.015; % Duration of each tone in seconds
num_samples = Fs * duration; % Number of samples per tone
t = (0:num_samples-1) / Fs; % Time vector

% Get the row and column for the digit
row_col = dtmf_map('1');
row = row_col(1);
col = row_col(2);

% Generate the tone
tone = sin(2 * pi * dtmf_freqs(1, row) * t) + sin(2 * pi * dtmf_freqs(2, col) * t);

% Plot the tone
figure;
plot(t, tone);
title('DTMF Tone for Digit 1');
xlabel('Time (seconds)');
ylabel('Amplitude');
grid on;