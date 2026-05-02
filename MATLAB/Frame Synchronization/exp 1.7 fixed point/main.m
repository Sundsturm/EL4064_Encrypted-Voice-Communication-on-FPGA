% Main Script to Integrate All Functions

clear all; close all;

% Basic Parameters
Fs = 16000;              % Sampling frequency
duration = 0.02;         % Signal duration in seconds
N = Fs * duration;       % Number of samples
t = (0:N - 1) / Fs;      % Time vector

% Generate DTMF tones
dtmf_matrix = [697 941; 1477 0];        % DTMF frequency matrix
dtmf_row = containers.Map({'3', '#'}, {1, 2});
dtmf_col = containers.Map({'3', '#'}, {1, 1});

tones = [
    sin(2 * pi * dtmf_matrix(1, dtmf_row('3')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('3')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('#')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('#')) * t)
    ];

% Generate input signal with noise and DTMF symbols
inputsignal = [(4*rand(1, 640))-2, ...   % Initial noise
               tones(2, :), ...          % Tone '#'
               tones(2, :), ...          % Tone '#'
               tones(1, :), ...          % Tone '3'
               tones(2, :), ...          % Tone '#'
               4*(rand(1, 640))-2];      % Final noise

% Frame parameters
frame_size = 32;                         % Frame size
batch_size = 20;                         % Batch size

% DTMF frequencies
dtmf_freqs = [697, 941, 1477];

% Generate lookup table for reference sines and cosines
[refsin_697, refcos_697] = lut_697();
[refsin_941, refcos_941] = lut_941();
[refsin_1477, refcos_1477] = lut_1477();

refsins = [
    refsin_697;  % Freq 697 Hz
    refsin_941;  % Freq 941 Hz
    refsin_1477  % Freq 1477 Hz
];

refcosines = [
    refcos_697;  % Freq 697 Hz
    refcos_941;  % Freq 941 Hz
    refcos_1477  % Freq 1477 Hz
];

% Step 1: Multiply input signal with reference sine and cosine
mult_sinsignal = sin_mult(inputsignal, refsins);
mult_cossignal = cosines_mult(inputsignal, refcosines);

% Step 2: Accumulate data for framing
[acc_sinsignal, acc_cossignal] = accu(mult_sinsignal, mult_cossignal, frame_size);

% Step 3: Calculate total power from sin and cos accumulations
total_power = total_calc(acc_sinsignal, acc_cossignal);

% Step 4: Perform sliding window batch summation
batch_sums = sliding(total_power, batch_size);

% Step 5: Flagging for specific DTMF frequencies [941 Hz and 1477 Hz]
[detect_enable_941, detect_enable_1477, precision_enable] = flagging(batch_sums);

% Step 6: Precision analysis if flagging detects conditions
if precision_enable
    [max_idx, max_value, detect_enable] = precision(batch_sums);
    if detect_enable
        fprintf('Deteksi selesai dengan precision_enable = 1 dan detect_enable = 1.\n');
    end
end

% Visualization of sliding window results
figure;
hold on;
for freq_idx = 1:3
    plot(1:size(batch_sums, 1), batch_sums(:, freq_idx), 'DisplayName', ['Frequency ', num2str(dtmf_freqs(freq_idx)), ' Hz'], 'LineWidth', 3);
end
xlabel('Sliding Window Index');
ylabel('Accumulated Power (Batch)');
title('Sliding Window Batch Accumulation for DTMF Frequencies');
legend('show');
grid on;
hold off;
