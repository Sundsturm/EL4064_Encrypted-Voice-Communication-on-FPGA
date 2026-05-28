% Skenario Uji Visualisasi Sisi Penerima (RX Receiver)
% Meliputi: Preamble Detection (IQ Demod) & Dekode Payload (Goertzel)

clear all; close all; clc;

% 1. Tambahkan direktori DTMF Generator ke dalam Path
gen_path = fullfile(fileparts(mfilename('fullpath')), '..', 'DTMF_Generator');
addpath(gen_path);

% Parameter Simulasi
Fs = 32000;
N_noise = 1280; % 40 ms noise awal dan akhir

% Sekuens Uji Wajib:
% Preamble: #, #, 3, #
% Payload 32-bit 0x3A7C9B1D: 3, A, 7, C, 9, B, 1, D
sequence_chars = ['#', '#', '3', '#', '3', 'A', '7', 'C', '9', 'B', '1', 'D'];

fprintf('=== SKENARIO UJI VISUALISASI RX RECEIVER ===\n');
fprintf('Sekuens yang dibangkitkan: %s\n', sequence_chars);

% 2. Bangkitkan Sinyal Continuous DTMF tanpa Jeda Sunyi (Sesuai output Tugas Generator)
[dtmf_sig, ~] = generate_dtmf(sequence_chars);

% Tambahkan Noise (mensimulasikan jeda sebelum dan sesudah pengiriman)
rng(42); % For reproducibility
noise_start = int16((rand(1, N_noise) - 0.5) * 500);
noise_end   = int16((rand(1, N_noise) - 0.5) * 500);
sinyal_masuk = [noise_start, dtmf_sig, noise_end];

% 3. Jalankan Top-Level Receiver
[reconstructed_key, sync_lock_index, batch_sums] = dtmf_receiver_top(sinyal_masuk);

% 4. Visualisasi Energi Sliding Window & Penanda Sinkronisasi
% Konversi batch index ke waktu untuk plotting
batch_size_samples = 40; % dari frame_size fixed point Kean
waktu_batch = ((1:size(batch_sums, 1)) * batch_size_samples) / Fs;

figure('Name', 'Deteksi Preamble IQ Demodulator', 'NumberTitle', 'off', 'Position', [100 100 900 500]);
hold on;
plot(waktu_batch, batch_sums(:,1), 'g-', 'LineWidth', 2, 'DisplayName', '697 Hz (Simbol 3)');
plot(waktu_batch, batch_sums(:,2), 'b-', 'LineWidth', 2, 'DisplayName', '941 Hz (Simbol #)');
plot(waktu_batch, batch_sums(:,3), 'r-', 'LineWidth', 2, 'DisplayName', '1477 Hz (Simbol # & 3)');

% Gambar garis penanda sync_lock_index
sync_time = sync_lock_index / Fs;
xline(sync_time, 'k--', 'LineWidth', 2, 'Label', 'SYNC LOCK INDEX (T=0 Payload)', ...
      'LabelHorizontalAlignment', 'center', 'LabelVerticalAlignment', 'bottom');

% Anotasi Area
patch([0 sync_time sync_time 0], ...
      [0 0 max(batch_sums(:))*1.1 max(batch_sums(:))*1.1], ...
      'blue', 'FaceAlpha', 0.05, 'EdgeColor', 'none', 'DisplayName', 'Area Pencarian Preamble');

patch([sync_time waktu_batch(end) waktu_batch(end) sync_time], ...
      [0 0 max(batch_sums(:))*1.1 max(batch_sums(:))*1.1], ...
      'green', 'FaceAlpha', 0.05, 'EdgeColor', 'none', 'DisplayName', 'Area Payload (Goertzel)');

xlabel('Waktu (s)');
ylabel('Total Accumulated Power (I^2 + Q^2)');
title('Profil Energi Sliding Window Preamble DTMF (IQ Demodulator Fixed-Point)');
legend('Location', 'best');
grid on;
ylim([0 max(batch_sums(:))*1.15]);
xlim([0 max(waktu_batch)]);
hold off;

fprintf('Pengujian Selesai. Mohon cek grafik profil energi yang dihasilkan.\n');
