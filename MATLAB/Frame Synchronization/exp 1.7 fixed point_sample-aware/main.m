clear; close all; clc;

% =========================
% FIXED POINT CONFIG (MATCH VHDL)
% =========================
F = fimath('RoundingMethod','Nearest', ...
           'OverflowAction','Saturate');

T_data  = numerictype(1, 16, 14); % Q2.14
T_mult  = numerictype(1, 16, 14); % Q2.14
T_acc   = numerictype(1, 16, 7); % Q9.7
T_power = numerictype(0, 16, 2);  % Q14.2 (unsigned)

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
% AWGN
% =========================
SNR_dB = 5;
inputsignal = awgn(base_signal, SNR_dB, 'measured');

% =========================
% CONVERT INPUT → Q2.14
% =========================
inputsignal = fi(inputsignal, T_data, F);

% =========================
% REFERENCE (Q2.14)
% =========================
t_ref = (0:window_size-1)/Fs;

ref_cos_697 = fi(cos(2*pi*697*t_ref), T_data, F);
ref_sin_697 = fi(sin(2*pi*697*t_ref), T_data, F);

ref_cos_941 = fi(cos(2*pi*941*t_ref), T_data, F);
ref_sin_941 = fi(sin(2*pi*941*t_ref), T_data, F);

ref_cos_1477 = fi(cos(2*pi*1477*t_ref), T_data, F);
ref_sin_1477 = fi(sin(2*pi*1477*t_ref), T_data, F);

% =========================
% PREALLOCATE
% =========================
N_total = length(inputsignal);
num_steps = N_total - window_size;

score_flag = zeros(1, num_steps);
score_mark = zeros(1, num_steps);

% =========================
% MAIN LOOP
% =========================
for n = 1:num_steps

    if mod(n,100) == 0
        fprintf('Progress: %d / %d\n', n, num_steps);
    end

    segment = inputsignal(n:n+window_size-1);

    % =========================
    % 697 Hz
    % =========================
    I = fi(0, T_acc, F);
    Q = fi(0, T_acc, F);

    for k = 1:window_size
        mult_cos = fi(segment(k) * ref_cos_697(k), T_mult, F);
        mult_sin = fi(segment(k) * ref_sin_697(k), T_mult, F);

        I = I + fi(mult_cos, T_acc, F);
        Q = Q + fi(mult_sin, T_acc, F);
    end

    P_697 = fi(I*I + Q*Q, T_power, F);

    % =========================
    % 941 Hz
    % =========================
    I = fi(0, T_acc, F);
    Q = fi(0, T_acc, F);

    for k = 1:window_size
        mult_cos = fi(segment(k) * ref_cos_941(k), T_mult, F);
        mult_sin = fi(segment(k) * ref_sin_941(k), T_mult, F);

        I = I + fi(mult_cos, T_acc, F);
        Q = Q + fi(mult_sin, T_acc, F);
    end

    P_941 = fi(I*I + Q*Q, T_power, F);

    % =========================
    % 1477 Hz
    % =========================
    I = fi(0, T_acc, F);
    Q = fi(0, T_acc, F);

    for k = 1:window_size
        mult_cos = fi(segment(k) .* ref_cos_1477(k), T_mult, F);
        mult_sin = fi(segment(k) .* ref_sin_1477(k), T_mult, F);

        I = I + fi(mult_cos, T_acc, F);
        Q = Q + fi(mult_sin, T_acc, F);
    end

    P_1477 = fi(I*I + Q*Q, T_power, F);

    % =========================
    % SCORE (convert to double for detection)
    % =========================
    score_flag(n) = double(P_941 + P_1477);
    score_mark(n) = double(P_697 + P_1477);

end

% =========================
% DETECTION
% =========================
[flag_idx, flag_enable, TH] = flagging(score_flag, Fs);

if flag_enable
    [sync_idx, max_value, detect_enable] = precision(score_mark, flag_idx, Fs);
end

% =========================
% PLOT
% =========================
figure;

plot(score_flag, 'LineWidth', 1.5); hold on;
plot(score_mark, 'LineWidth', 1.5);

yline(TH, '--r');

if flag_enable
    xline(flag_idx, '--g');
end

if exist('sync_idx','var')
    xline(sync_idx, '--k');
end

title(sprintf('Fixed-Point (Hardware Match) + AWGN (%d dB)', SNR_dB));
xlabel('Sample Index');
ylabel('Correlation Power');
legend('Flag (#)', 'Mark (3)', 'Threshold');

grid on;

% =========================
% DEBUG
% =========================
fprintf('\n=== FIXED POINT DEBUG ===\n');
fprintf('Max score_flag: %.4f\n', max(score_flag));
fprintf('Max score_mark: %.4f\n', max(score_mark));