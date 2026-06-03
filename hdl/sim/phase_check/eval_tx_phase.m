% eval_tx_phase.m
% Skrip MATLAB untuk Mengevaluasi Kontinuitas Fase DTMF Continuous Blast

clc; clear; close all;

%% 1. Parameter Sistem
fs = 32000;                     % Frekuensi sampling = 32 kHz
t_symbol = 0.020;               % Durasi 1 simbol = 20 ms
samples_per_symbol = fs * t_symbol; % = 640 sampel per simbol

%% 2. Membaca Data Output Testbench
filename = 'tx_waveform_output.txt';
if ~isfile(filename)
    error('File "%s" tidak ditemukan. Silakan jalankan simulasi Verilog terlebih dahulu.', filename);
end

data = load(filename);
num_samples = length(data);
t = (0:num_samples-1) / fs;     % Vektor waktu dalam detik

%% 3. Deteksi Patahan Fase (Discontinuity)
% Pada arsitektur DDS murni, fase bersifat selalu kontinu (smooth), 
% sehingga tidak ada lonjakan tajam pada amplitudo meskipun frekuensi berubah.
% Kita mendeteksi anomali (lonjakan) melalui turunan pertama (perbedaan amplitudo antar sampel).
dy = diff(data); 

discontinuity_found = false;
num_symbols = floor(num_samples / samples_per_symbol);

% Siapkan plot visual
figure('Name', 'Evaluasi DTMF TX (Phase Continuity)', 'Position', [100, 100, 1200, 600]);
plot(t * 1000, data, 'b-', 'LineWidth', 1);
hold on;
title('DTMF TX Continuous Blast Waveform (Uji Transisi Fase Mulus)');
xlabel('Waktu (ms)');
ylabel('Amplitudo Audio (Signed 16-bit)');
grid on;

% Threshold deteksi patahan tajam
% Jika perbedaan 1 sampel ke sampel lain tiba-tiba melonjak di luar batas normal
% frekuensi diferensial DTMF, maka itu dicurigai sebagai patahan fase (glitch).
max_normal_diff = 15000; 

for i = 1:num_symbols-1
    boundary_idx = i * samples_per_symbol; % Titik potong transisi tepat per 20 ms
    
    % Tandai garis batas transisi simbol di plot
    xline(boundary_idx / fs * 1000, 'k--', 'LineWidth', 1.5, 'Label', sprintf('Transisi %d', i));
    
    % Cek area sekitar batas (-5 hingga +5 sampel)
    idx_range = (boundary_idx - 5) : (boundary_idx + 5);
    idx_range = idx_range(idx_range > 0 & idx_range < length(dy)); % Pastikan aman dari Index out of bounds
    
    local_dy = dy(idx_range);
    
    if any(abs(local_dy) > max_normal_diff)
        % Tandai dengan lingkaran merah besar jika terdapat patahan
        plot(boundary_idx / fs * 1000, data(boundary_idx), 'ro', 'MarkerSize', 12, 'LineWidth', 2);
        fprintf('WARNING: Patahan fase / spike tajam terdeteksi di sekitar t = %.1f ms!\n', boundary_idx / fs * 1000);
        discontinuity_found = true;
    end
end

if ~discontinuity_found
    fprintf('SUCCESS VERIFIED: Transisi sinyal antar 12 simbol mulus sempurna, tidak ditemukan patahan fase (Glitch-Free DDS).\n');
end
hold off;
