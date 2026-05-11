% =========================================================================
% Script Generator MATLAB Golden Model - Sekuens DTMF dengan AWGN
% Target: 32 kHz Sampling Rate, 20 ms (640 sampel) per Nada & Silence
% =========================================================================

% 1. Parameter Dasar Sistem
Fs = 32000;         % Frekuensi sampling 32 kHz
t_dur = 0.02;       % Durasi 20 ms per frame
N = Fs * t_dur;     % Total 640 sampel
t = (0:N-1) / Fs;   % Vektor waktu

% 2. Fungsi Pembangkit Sinyal DTMF
% Menjumlahkan gelombang sinusoidal low dan high group
gen_dtmf = @(f_low, f_high) 0.5 * sin(2*pi*f_low*t) + 0.5 * sin(2*pi*f_high*t);

% Array untuk Jeda (Silence)
silence = zeros(1, N);

% 3. Pembentukan Sekuens Preamble (Flag dan Mark)
% Nada '#' (Flag) = 941 Hz + 1477 Hz
% Nada '3' (Mark) = 697 Hz + 1477 Hz
tone_flag = gen_dtmf(941, 1477);
tone_mark = gen_dtmf(697, 1477);

% 4. Pembentukan Sekuens Payload (Contoh Kunci 24-bit)
% Berdasarkan pemetaan RTL (decision.vhd): 
% 000=1, 001=2, 010=4, 011=5, 100=7, 101=8, 110=*, 111=0
tone_p1 = gen_dtmf(697, 1336); % Nada '2' (001)
tone_p2 = gen_dtmf(770, 1209); % Nada '4' (010)
tone_p3 = gen_dtmf(770, 1336); % Nada '5' (011)
tone_p4 = gen_dtmf(852, 1209); % Nada '7' (100)
tone_p5 = gen_dtmf(852, 1336); % Nada '8' (101)
tone_p6 = gen_dtmf(941, 1209); % Nada '*' (110)
tone_p7 = gen_dtmf(941, 1336); % Nada '0' (111)
tone_p8 = gen_dtmf(697, 1209); % Nada '1' (000)

% 5. Penggabungan Sinyal Sesuai Aturan Timing FSM
signal = [tone_flag, silence, tone_mark, silence, ...
          tone_p1, silence, tone_p2, silence, ...
          tone_p3, silence, tone_p4, silence, ...
          tone_p5, silence, tone_p6, silence, ...
          tone_p7, silence, tone_p8];

% 6. Injeksi Additive White Gaussian Noise (AWGN)
% Menggunakan SNR 10 dB sebagai baseline pengujian
snr_db = 10;
noisy_signal = awgn(signal, snr_db, 'measured');

% Normalisasi sinyal agar terhindar dari clipping
noisy_signal = noisy_signal / max(abs(noisy_signal));

% 7. Konversi Data Menjadi Fixed-Point 16-bit
% Mengubah ke representasi signed integer 16-bit (-32768 hingga 32767)
signal_int16 = int16(noisy_signal * (2^15 - 1));

% 8. Ekspor ke File Heksadesimal untuk Testbench ModelSim
filename = 'audio_test.txt';
fileID = fopen(filename, 'w');
for i = 1:length(signal_int16)
    % Konversi nilai ke string heksadesimal 4-digit
    hex_val = dec2hex(typecast(signal_int16(i), 'uint16'), 4);
    fprintf(fileID, '%s\n', hex_val);
end
fclose(fileID);

disp(['Berhasil! File ', filename, ' telah di-generate dan siap digunakan.']);