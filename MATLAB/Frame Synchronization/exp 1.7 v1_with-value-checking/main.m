% Main Script to Integrate All Functions

clear all; close all;

% Basic Parameters
Fs = 32000;              % Sampling frequency
duration = 0.02;         % Signal duration in seconds
N = Fs * duration;       % Number of samples
t = (0:N - 1) / Fs;      % Time vector

% Generate DTMF tones
dtmf_matrix = [697 941; 1477 0];        % DTMF frequency matrix
dtmf_row = containers.Map({'3', '#'}, {1, 2}); % DTMF 
dtmf_col = containers.Map({'3', '#'}, {1, 1});

tones = [
    sin(2 * pi * dtmf_matrix(1, dtmf_row('3')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('3')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('#')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('#')) * t)
    ];

% Generate base noise and tones signal
base_signal = [(4*rand(1, 1280))-2, ...   % Initial noise
               tones(2, :), ...          % Tone '#'
               tones(2, :), ...          % Tone '#'
               tones(1, :), ...          % Tone '3'
               tones(2, :),...          % Tone '#'
               4*(rand(1, 1280))-2];      % Final noise

% Plot the base signal
figure;
plot(base_signal);
title('Base Signal with Noise and Tones');
xlabel('Sample Number');
ylabel('Amplitude');
grid on;


% Frame parameters
frame_size = 40;                         % Frame size
batch_size = 16;                         % Batch size

% DTMF frequencies
dtmf_freqs = [697, 941, 1477];

% Precompute reference sines and cosines
[refsin_697, refcos_697] = lut_697();
[refsin_941, refcos_941] = lut_941();
[refsin_1477, refcos_1477] = lut_1477();

refsins = [refsin_697; refsin_941; refsin_1477];
refcosines = [refcos_697; refcos_941; refcos_1477];

fprintf('Currently processing condition without AWGN.\n');
    
% Step 1: Multiply input signal with reference sine and cosine
mult_sinbase = sin_mult(base_signal, refsins);
mult_cosbase = cosines_mult(base_signal, refcosines);
check_range(mult_sinbase, 'MULT SIN');
check_range(mult_cosbase, 'MULT COS');

% Step 2: Accumulate data for framing
[acc_sinbase, acc_cosbase] = accu(mult_sinbase, mult_cosbase, frame_size);
check_range(acc_sinbase, 'ACC SIN');
check_range(acc_cosbase, 'ACC COS');

% Step 3: Calculate total power from sin and cos accumulations
total_power = total_calc(acc_sinbase, acc_cosbase);
check_range(total_power, 'TOTAL POWER');

% Step 4: Perform sliding window batch summation
batch_sums = sliding(total_power, batch_size);
check_range(batch_sums, 'BATCH SUM');

% Step 5: Flagging for specific DTMF frequencies [941 Hz and 1477 Hz]
[detect_enable_941, detect_enable_1477, precision_enable] = flagging(batch_sums);

% Step 6: Precision analysis if flagging detects conditions
if precision_enable
    [max_idx, max_value, detect_enable] = precision(batch_sums);
    if detect_enable
        fprintf('Deteksi selesai dengan precision_enable = 1 dan detect_enable = 1.\n');
    end
else
    fprintf('Tidak terdeteksi sinyal flag.\n');
end

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