% Main Script to Integrate All Functions

clear all; close all;

% Global setup of fixed-point simulation
F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');

% Basic Parameters
Fs = 32000;               % Sampling frequency
duration = 0.02;          % Signal duration in seconds
N = Fs * duration;        % Number of samples
t = (0:N - 1) / Fs;       % Time vector

% Generate DTMF tones
dtmf_matrix = [697 941; 1477 0];        % DTMF frequency matrix
dtmf_row = containers.Map({'3', '#'}, {1, 2});
dtmf_col = containers.Map({'3', '#'}, {1, 1});

tones = [
    sin(2 * pi * dtmf_matrix(1, dtmf_row('3')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('3')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('#')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('#')) * t)
];

% Generate base signal (double), then AWGN per condition
base_signal = [(4*rand(1, 1280))-2, ...   % Initial noise
               tones(2, :), ...           % Tone '#'
               tones(2, :), ...           % Tone '#'
               tones(1, :), ...           % Tone '3'
               tones(2, :), ...           % Tone '#'
               4*(rand(1, 1280))-2];      % Final noise

% Plot base signal
figure;
plot(base_signal);
title('Base Signal with Noise and Tones');
xlabel('Sample Number');
ylabel('Amplitude');
grid on;

% AWGN / SNR simulation mode
% true  -> sweep multiple SNR values (like exp 1.7 v2)
% false -> simulate one SNR value only
run_snr_sweep = true;
snr_values_db = [20, 10, 5, 0, -5, -10, -20];
single_snr_db = 10;

if run_snr_sweep
    snr_labels = arrayfun(@(x) sprintf('%+d dB', x), snr_values_db, 'UniformOutput', false);
    awgn_signals = cell(1, numel(snr_values_db));
    for i = 1:numel(snr_values_db)
        awgn_signals{i} = awgn(base_signal, snr_values_db(i), 'measured');
    end
else
    snr_labels = {sprintf('%+d dB', single_snr_db)};
    awgn_signals = {awgn(base_signal, single_snr_db, 'measured')};
end

condition_names = [{'Tanpa AWGN'}, snr_labels];
condition_signals = [{base_signal}, awgn_signals];

% Plot AWGN signals
if ~isempty(awgn_signals)
    num_awgn = numel(awgn_signals);
    ncols = min(3, num_awgn);
    nrows = ceil(num_awgn / ncols);
    figure;
    for i = 1:num_awgn
        subplot(nrows, ncols, i);
        plot(awgn_signals{i});
        title(['After AWGN Signal at ', snr_labels{i}]);
        xlabel('Sample Number');
        ylabel('Amplitude');
        grid on;
    end
end

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

num_conditions = numel(condition_names);
batch_sums_all = cell(1, num_conditions);
max_vals = zeros(1, num_conditions);
min_vals = zeros(1, num_conditions);

for i = 1:num_conditions
    fprintf('\nCurrently processing condition: %s\n', condition_names{i});
    inputsignal = fi(condition_signals{i}, 1, 16, 13, 'fimath', F); % Q3.13

    % Step 1: Multiply input signal with reference sine and cosine
    mult_sinsignal = sin_mult(inputsignal, refsins);
    mult_cossignal = cosines_mult(inputsignal, refcosines);
    check_saturation(mult_sinsignal, ['MULT SIN - ', condition_names{i}]);
    check_saturation(mult_cossignal, ['MULT COS - ', condition_names{i}]);

    % Step 2: Accumulate data for framing
    [acc_sinsignal, acc_cossignal] = accu(mult_sinsignal, mult_cossignal, frame_size);
    check_saturation(acc_sinsignal, ['ACC SIN - ', condition_names{i}]);
    check_saturation(acc_cossignal, ['ACC COS - ', condition_names{i}]);

    % Step 3: Calculate total power from sin and cos accumulations
    total_power = total_calc(acc_sinsignal, acc_cossignal);
    check_saturation(total_power, ['TOTAL POWER - ', condition_names{i}]);

    % Step 4: Perform sliding window batch summation
    batch_sums = sliding(total_power, batch_size);
    check_saturation(batch_sums, ['BATCH SUM - ', condition_names{i}]);
    batch_sums_all{i} = batch_sums;

    % Step 4 Bonus: Range checking
    max_vals(i) = max(double(batch_sums(:)));
    min_vals(i) = min(double(batch_sums(:)));
    disp(['Max. batch sums (', condition_names{i}, '): ', num2str(max_vals(i))])
    disp(['Min. batch sums (', condition_names{i}, '): ', num2str(min_vals(i))])

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
end

% Derived parameters
samples_per_batch = frame_size * batch_size;
time_per_frame = frame_size / Fs;         % seconds
time_per_batch = samples_per_batch / Fs;  % seconds

% Visualization for each condition
figure;
ncols = min(3, num_conditions);
nrows = ceil(num_conditions / ncols);
for i = 1:num_conditions
    subplot(nrows, ncols, i);
    hold on;
    for freq_idx = 1:3
        plot(1:size(batch_sums_all{i}, 1), double(batch_sums_all{i}(:, freq_idx)), ...
            'DisplayName', ['Frequency ', num2str(dtmf_freqs(freq_idx)), ' Hz'], ...
            'LineWidth', 1.5);
    end
    xlabel('Sliding Window Index');
    ylabel('Accumulated Power (Batch)');
    title(['Condition ', condition_names{i}]);
    legend('show', 'Location', 'best');
    grid on;
    hold off;
end

% Detailed visualization for baseline (without AWGN)
figure;
hold on;
for freq_idx = 1:3
    plot(1:size(batch_sums_all{1}, 1), double(batch_sums_all{1}(:, freq_idx)), ...
        'DisplayName', ['Frequency ', num2str(dtmf_freqs(freq_idx)), ' Hz'], ...
        'LineWidth', 3);
end
xlabel('Sliding Window Index');
ylabel('Accumulated Power (Batch)');
title({
    'Sliding Window Batch Accumulation (Fixed-Point Simulation)'
    ['Condition = ', condition_names{1}]
    ['Frame Size = ', num2str(frame_size), ' samples | Batch Size = ', num2str(batch_size), ' frames']
    ['Samples/Batch = ', num2str(samples_per_batch), ...
     ' | Frame Time = ', num2str(time_per_frame*1e3, '%.2f'), ' ms', ...
     ' | Batch Time = ', num2str(time_per_batch*1e3, '%.2f'), ' ms']
});
legend('show', 'Location', 'best');
grid on;
annotation('textbox', [0.15 0.75 0.3 0.15], ...
    'String', { ...
    ['Fs = ', num2str(Fs), ' Hz'], ...
    ['Fixed-point: Q3.13 -> Q3.13 -> Q8.8 -> Q12.4 -> Q14.2'], ...
    ['Max = ', num2str(max_vals(1))], ...
    ['Min = ', num2str(min_vals(1))]}, ...
    'FitBoxToText', 'on', ...
    'BackgroundColor', 'white');
hold off;
