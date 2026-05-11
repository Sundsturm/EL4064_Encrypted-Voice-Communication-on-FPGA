% Main Script to Integrate All Functions

clear all; close all;

% Global setup of fixed-point simulation
F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');

% Basic Parameters
Fs = 32000;              % Sampling frequency
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
% Also fixed-point conversion
inputsignal = [(4*rand(1, 1280))-2, ...   % Initial noise
               tones(2, :), ...          % Tone '#'
               tones(2, :), ...          % Tone '#'
               tones(1, :), ...          % Tone '3'
               tones(2, :), ...          % Tone '#'
               4*(rand(1, 1280))-2];      % Final noise
inputsignal = fi(inputsignal, 1, 16, 14, 'fimath', F); %Q2.14


% Frame parameters
frame_size = 40;                         % Frame size
batch_size = 16;                         % Batch size

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
check_saturation(mult_sinsignal, 'MULT SIN');
check_saturation(mult_cossignal, 'MULT COS');

% Step 2: Accumulate data for framing
[acc_sinsignal, acc_cossignal] = accu(mult_sinsignal, mult_cossignal, frame_size);
check_saturation(acc_sinsignal, 'ACC SIN');
check_saturation(acc_cossignal, 'ACC COS');


% Step 3: Calculate total power from sin and cos accumulations
total_power = total_calc(acc_sinsignal, acc_cossignal);
check_saturation(total_power, 'TOTAL POWER');

% Step 4: Perform sliding window batch summation
batch_sums = sliding(total_power, batch_size);
check_saturation(batch_sums, 'BATCH SUM');

% Step 4 Bonus: Range checking
max_val = max(double(batch_sums(:)));
min_val = min(double(batch_sums(:)));

disp(['Max. batch sums: ', num2str(max_val)])
disp(['Min. batch sums: ', num2str(min_val)])

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
% =========================
% Derived parameters
% =========================
samples_per_batch = frame_size * batch_size;
time_per_frame = frame_size / Fs;         % seconds
time_per_batch = samples_per_batch / Fs;  % seconds

% =========================
% Visualization
% =========================
figure;
hold on;

for freq_idx = 1:3
    plot(1:size(batch_sums, 1), double(batch_sums(:, freq_idx)), ...
        'DisplayName', ['Frequency ', num2str(dtmf_freqs(freq_idx)), ' Hz'], ...
        'LineWidth', 2);
end

xlabel('Sliding Window Index');
ylabel('Accumulated Power (Batch)');

% Dynamic title with system configuration
title({
    'Sliding Window Batch Accumulation (Fixed-Point Simulation)'
    ['Frame Size = ', num2str(frame_size), ' samples | Batch Size = ', num2str(batch_size), ' frames']
    ['Samples/Batch = ', num2str(samples_per_batch), ...
     ' | Frame Time = ', num2str(time_per_frame*1e3, '%.2f'), ' ms', ...
     ' | Batch Time = ', num2str(time_per_batch*1e3, '%.2f'), ' ms']
});

legend('show','Location','best');
grid on;

% =========================
% Annotasi tambahan (textbox)
% =========================
annotation('textbox', [0.15 0.75 0.3 0.15], ...
    'String', { ...
    ['Fs = ', num2str(Fs), ' Hz'], ...
    ['Fixed-point: Q2.14 -> Q2.14 -> Q8.8 -> Q12.4 -> Q14.2'], ...
    ['Max = ', num2str(max_val)], ...
    ['Min = ', num2str(min_val)]}, ...
    'FitBoxToText','on', ...
    'BackgroundColor','white');

hold off;
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
