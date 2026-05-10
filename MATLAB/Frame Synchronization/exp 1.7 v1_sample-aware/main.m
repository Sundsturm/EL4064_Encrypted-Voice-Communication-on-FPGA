clear; close all; clc;

% =========================
% PARAMETER
% =========================
Fs = 32000;
window_size = 320;   % 10 ms window

% =========================
% GENERATE SIGNAL (TEST)
% =========================
duration = 0.02;
N = Fs * duration;
t = (0:N - 1) / Fs;

sig_3 = sin(2*pi*697*t) + sin(2*pi*1477*t);
sig_hash = sin(2*pi*941*t) + sin(2*pi*1477*t);

inputsignal = [(4*rand(1,1280))-2, ...
               sig_hash, sig_hash, sig_3, sig_hash, ...
               (4*rand(1,1280))-2];

N_total = length(inputsignal);

% =========================
% PREPARE LUT (REFERENCE)
% =========================
t_ref = (0:window_size-1)/Fs;

ref_cos_697 = cos(2*pi*697*t_ref);
ref_sin_697 = sin(2*pi*697*t_ref);

ref_cos_941 = cos(2*pi*941*t_ref);
ref_sin_941 = sin(2*pi*941*t_ref);

ref_cos_1477 = cos(2*pi*1477*t_ref);
ref_sin_1477 = sin(2*pi*1477*t_ref);

% =========================
% PREALLOCATE
% =========================
num_steps = N_total - window_size;

P_697  = zeros(1, num_steps);
P_941  = zeros(1, num_steps);
P_1477 = zeros(1, num_steps);

score_flag = zeros(1, num_steps);
score_mark = zeros(1, num_steps);

% =========================
% MAIN LOOP (SAMPLE-AWARE)
% =========================
for n = 1:num_steps

    % Ambil window
    segment = inputsignal(n:n+window_size-1);

    % =========================
    % 697 Hz
    % =========================
    cos_697 = cosines_mult(segment, ref_cos_697);
    sin_697 = sin_mult(segment, ref_sin_697);
    [I697, Q697] = accu(segment, ref_cos_697, ref_sin_697);
    P_697(n) = total_calc(I697, Q697);

    % =========================
    % 941 Hz
    % =========================
    [I941, Q941] = accu(segment, ref_cos_941, ref_sin_941);
    P_941(n) = total_calc(I941, Q941);

    % =========================
    % 1477 Hz
    % =========================
    [I1477, Q1477] = accu(segment, ref_cos_1477, ref_sin_1477);
    P_1477(n) = total_calc(I1477, Q1477);

    % =========================
    % SCORE COMPUTATION
    % =========================
    score_flag(n) = P_941(n) + P_1477(n);
    score_mark(n) = P_697(n) + P_1477(n);

end

% =========================
% FLAG DETECTION
% =========================
[flag_idx, flag_enable, TH] = flagging(score_flag, Fs);

% =========================
% PRECISION (SYNC POINT)
% =========================
if flag_enable
    [sync_idx, max_value, detect_enable] = precision(score_mark, flag_idx, Fs);
end

% =========================
% PLOT
% =========================
figure;

plot(score_flag, 'LineWidth', 1.5); hold on;
plot(score_mark, 'LineWidth', 1.5);

yline(TH, '--r', 'Threshold');

if flag_enable
    xline(flag_idx, '--g', 'Flag');
end

if exist('sync_idx', 'var')
    xline(sync_idx, '--k', 'Sync Point');
end

xlabel('Sample Index');
ylabel('Correlation Power');
title('Sample-Aware Frame Synchronization');

legend('Flag (#)', 'Mark (3)', 'Threshold');

grid on;

% =========================
% DEBUG OUTPUT
% =========================
fprintf('\n=== DEBUG INFO ===\n');
fprintf('Max score_flag: %.4f\n', max(score_flag));
fprintf('Max score_mark: %.4f\n', max(score_mark));