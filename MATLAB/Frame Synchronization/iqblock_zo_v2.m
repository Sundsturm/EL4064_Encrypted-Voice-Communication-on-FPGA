clear; close all;

% =========================
% SIGNAL GENERATION (FIXED)
% =========================
Fs = 32000;
duration = 0.02;
N = Fs * duration;
t = (0:N - 1) / Fs;

% DTMF tones
sig_3 = sin(2*pi*697*t) + sin(2*pi*1477*t);
sig_hash = sin(2*pi*941*t) + sin(2*pi*1477*t);

% Build input signal
inputsignal = [(4*rand(1,1280))-2, ...
               sig_hash, sig_hash, sig_3, sig_hash, ...
               (4*rand(1,1280))-2];

% =========================
% SAMPLE-AWARE DETECTION
% =========================
window_size = 320; % 10 ms
stride = 1;

dtmf_freqs = [697 941 1477];
N_total = length(inputsignal);

% Reference signals
 t_ref = (0:window_size-1)/Fs;
ref_cos = zeros(length(dtmf_freqs), window_size);
ref_sin = zeros(length(dtmf_freqs), window_size);

for i = 1:length(dtmf_freqs)
    ref_cos(i,:) = cos(2*pi*dtmf_freqs(i)*t_ref);
    ref_sin(i,:) = sin(2*pi*dtmf_freqs(i)*t_ref);
end

num_steps = N_total - window_size;
corr_out = zeros(num_steps, length(dtmf_freqs));

% Correlation loop
for n = 1:stride:num_steps
    segment = inputsignal(n:n+window_size-1);

    energy = sum(segment.^2) + 1e-6;   % pindah ke atas

    for f = 1:length(dtmf_freqs)
        I = sum(segment .* ref_cos(f,:));
        Q = sum(segment .* ref_sin(f,:));

        % 🔥 FIX DI SINI
        corr_out(n,f) = (I^2 + Q^2) / (energy * window_size);
    end
end

% =========================
% DETECTION
% =========================
score_flag = corr_out(:,2) + corr_out(:,3);
score_mark = corr_out(:,1) + corr_out(:,3);

TH = 0.7 * max(score_flag); % Adaptive threshold

flag_idx = find(score_flag > TH, 1, 'first');

% DEBUG FLAG
if isempty(flag_idx)
    disp('FLAG TIDAK TERDETEKSI - cek threshold atau sinyal');
else
    fprintf('FLAG terdeteksi di sample %d\n', flag_idx);
end

% MARK DETECTION
if ~isempty(flag_idx)
    search_end = min(flag_idx + round(Fs*0.05), length(score_mark));
    search_range = flag_idx : search_end;

    [~, rel_idx] = max(score_mark(search_range));
    sync_point = search_range(rel_idx);

    fprintf('Sync point ditemukan di sample %d\n', sync_point);
end

% =========================
% PLOT DEBUG
% =========================
figure;

plot(score_flag, 'LineWidth', 1.5); hold on;
plot(score_mark, 'LineWidth', 1.5);

% Tambahkan garis threshold
yline(TH, '--r', 'Threshold');

% Label sumbu
xlabel('Sample Index (n)');
ylabel('Normalized Correlation Power');

% Judul
title('Sample-aware Frame Synchronization Detection');

% Legenda
legend('Flag (#: 941+1477 Hz)', ...
       'Mark (3: 697+1477 Hz)', ...
       'Threshold');

fprintf('Max score_flag: %.2f\n', max(score_flag));
fprintf('Max score_mark: %.2f\n', max(score_mark));

grid on;
