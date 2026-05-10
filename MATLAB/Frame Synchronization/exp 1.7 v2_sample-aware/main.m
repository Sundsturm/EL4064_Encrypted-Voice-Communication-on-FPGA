clear; close all; clc;

% =========================
% PARAMETER
% =========================
Fs = 32000;
window_size = 320;

duration = 0.02;
N = Fs * duration;
t = (0:N - 1) / Fs;

% =========================
% GENERATE SIGNAL
% =========================
sig_3 = sin(2*pi*697*t) + sin(2*pi*1477*t);
sig_hash = sin(2*pi*941*t) + sin(2*pi*1477*t);

base_signal = [(4*rand(1,1280))-2, ...
               sig_hash, sig_hash, sig_3, sig_hash, ...
               (4*rand(1,1280))-2];

% =========================
% AWGN CONDITIONS
% =========================
snr_values = [20, 10, 5, 0, -10, -20];
num_conditions = length(snr_values);

input_signals = cell(1, num_conditions);

for i = 1:num_conditions
    input_signals{i} = awgn(base_signal, snr_values(i), 'measured');
end

% =========================
% REFERENCE SIGNAL
% =========================
t_ref = (0:window_size-1)/Fs;

ref_cos_697 = cos(2*pi*697*t_ref);
ref_sin_697 = sin(2*pi*697*t_ref);

ref_cos_941 = cos(2*pi*941*t_ref);
ref_sin_941 = sin(2*pi*941*t_ref);

ref_cos_1477 = cos(2*pi*1477*t_ref);
ref_sin_1477 = sin(2*pi*1477*t_ref);

% =========================
% PLOT SETUP
% =========================
figure;

% =========================
% MAIN LOOP PER SNR
% =========================
for i = 1:num_conditions

    inputsignal = input_signals{i};
    N_total = length(inputsignal);
    num_steps = N_total - window_size;

    % Preallocate
    P_697  = zeros(1, num_steps);
    P_941  = zeros(1, num_steps);
    P_1477 = zeros(1, num_steps);

    score_flag = zeros(1, num_steps);
    score_mark = zeros(1, num_steps);

    fprintf('\nProcessing SNR = %d dB\n', snr_values(i));

    % =========================
    % SAMPLE-AWARE LOOP
    % =========================
    for n = 1:num_steps

        segment = inputsignal(n:n+window_size-1);

        % 697 Hz
        [I697, Q697] = accu(segment, ref_cos_697, ref_sin_697);
        P_697(n) = total_calc(I697, Q697);

        % 941 Hz
        [I941, Q941] = accu(segment, ref_cos_941, ref_sin_941);
        P_941(n) = total_calc(I941, Q941);

        % 1477 Hz
        [I1477, Q1477] = accu(segment, ref_cos_1477, ref_sin_1477);
        P_1477(n) = total_calc(I1477, Q1477);

        % Score
        score_flag(n) = P_941(n) + P_1477(n);
        score_mark(n) = P_697(n) + P_1477(n);

    end

    % =========================
    % FLAGGING
    % =========================
    [flag_idx, flag_enable, TH] = flagging(score_flag, Fs);

    % =========================
    % PRECISION
    % =========================
    if flag_enable
        [sync_idx, max_value, detect_enable] = precision(score_mark, flag_idx, Fs);
    end

    % =========================
    % PLOT PER SNR
    % =========================
    subplot(2,3,i);
    plot(score_flag, 'LineWidth', 1.2); hold on;
    plot(score_mark, 'LineWidth', 1.2);

    yline(TH, '--r');

    if flag_enable
        xline(flag_idx, '--g');
    end

    if exist('sync_idx', 'var')
        xline(sync_idx, '--k');
    end

    title(sprintf('SNR = %d dB', snr_values(i)));
    xlabel('Sample Index');
    ylabel('Correlation Power');
    grid on;

    hold off;

end