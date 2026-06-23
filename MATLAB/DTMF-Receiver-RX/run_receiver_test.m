% =========================================================================
% run_receiver_test.m
% Testbench Standalone DTMF Receiver
% =========================================================================

clear all; close all; clc; %#ok<CLALL>

fprintf('=========================================================\n');
fprintf('  TESTBENCH STANDALONE DTMF RECEIVER\n');
fprintf('=========================================================\n');

% -------------------------------------------------------------------------
% Parameter Sistem
% -------------------------------------------------------------------------
Fs = 32000;  % Sampling rate (Hz)
N  = 640;    % Sampel per simbol = 20 ms @ 32 kHz
t  = (0:N-1).' / Fs;  % Vektor waktu per simbol (kolom)


% -------------------------------------------------------------------------
% Tabel Frekuensi DTMF Standar (4x4)
%
%          1209 Hz  1336 Hz  1477 Hz  1633 Hz
%  697 Hz    1        2        3        A
%  770 Hz    4        5        6        B
%  852 Hz    7        8        9        C
%  941 Hz    *        0        #        D
% -------------------------------------------------------------------------
% (Lookup dilakukan via fungsi get_dtmf_freqs di bawah)

% -------------------------------------------------------------------------
% Sekuens Uji: tepat 8 simbol DTMF
%    Simbol yang valid: '0'-'9', 'A','B','C','D','*','#'
%    Jumlah simbol HARUS tetap 8.
% -------------------------------------------------------------------------
sequence_chars = {'#', '#', '1', '5', '*', '7', 'A', 'C'};
N_SYM = numel(sequence_chars);

% Validasi: harus tepat 8 simbol
assert(N_SYM == 8, ...
    'sequence_chars harus berisi tepat 8 simbol DTMF (saat ini: %d simbol).', N_SYM);

% Hitung EXPECTED_KEY secara otomatis dari sequence_chars
% (menggunakan mapping 4-bit yang sama dengan decision.m)
EXPECTED_KEY = uint32(0);
for k = 1:N_SYM
    code = dtmf_char_to_code(sequence_chars{k});
    EXPECTED_KEY = bitor(bitshift(EXPECTED_KEY, 4), uint32(code));
end

fprintf('\n[1] Membangkitkan Sinyal DTMF Secara Matematis\n');
fprintf('    Sekuens  : %s\n', strjoin(sequence_chars, '-'));
fprintf('    Expected : 0x%0*X  (%d simbol x 4-bit)\n\n', N_SYM, EXPECTED_KEY, N_SYM);

% -------------------------------------------------------------------------
% Bangkitkan Sinyal DTMF (superposisi dua sinusoidal per simbol)
% -------------------------------------------------------------------------
payload_signal = int16([]);
sym_freqs = zeros(N_SYM, 2);  % Simpan [f_low, f_high] tiap simbol untuk plotting

AMPLITUDE = 10000; % Amplitudo sebelum normalisasi (range int16: -32768..32767)

for k = 1:N_SYM
    ch = sequence_chars{k};
    [f_low, f_high] = get_dtmf_freqs(ch);
    sym_freqs(k, :) = [f_low, f_high];

    % Superposisi dua sinusoidal
    raw = sin(2*pi*f_low*t) + sin(2*pi*f_high*t);

    % Normalisasi ke int16
    raw_norm = raw / max(abs(raw)) * AMPLITUDE;
    payload_signal = [payload_signal; int16(round(raw_norm))]; %#ok<AGROW>
end

fprintf('    Total sampel: %d (= %d simbol x %d sampel)\n', ...
        length(payload_signal), N_SYM, N);

% -------------------------------------------------------------------------
% Jalankan DTMF Receiver (Pure)
% -------------------------------------------------------------------------
fprintf('\n[2] Menjalankan DTMF Receiver...\n');
[reconstructed_key, decode_table] = dtmf_receiver_top(payload_signal);

% -------------------------------------------------------------------------
% Verifikasi
% -------------------------------------------------------------------------
fprintf('[3] Verifikasi Hasil\n');
fprintf('    Expected : 0x%08X\n', EXPECTED_KEY);
fprintf('    Got      : 0x%08X\n', reconstructed_key);
if reconstructed_key == EXPECTED_KEY
    fprintf('    Status   : [PASS] Hasil decode sesuai ekspektasi!\n\n');
else
    fprintf('    Status   : [FAIL] Hasil decode TIDAK sesuai!\n\n');
end

% -------------------------------------------------------------------------
% Tabel 32-bit: Bit Value | Dominant Energy | DTMF Symbol
% -------------------------------------------------------------------------
fprintf('[4] Tabel Representasi 32-bit Output\n');
fprintf('%s\n', repmat('-', 1, 72));
fprintf('%-8s | %-10s | %-10s | %-16s | %-8s | %s\n', ...
        'Nibble', 'Bit Pos', 'Bit Value', 'Dominant Energy', 'DTMF Sym', 'Hex Code');
fprintf('%s\n', repmat('-', 1, 72));

% Iterasi per nibble (4-bit) = per simbol
for i = 1:N_SYM
    dt        = decode_table(i);
    nibble_hi = 32 - (i-1)*4;   % Bit position MSB of this nibble (bit 31 down)
    nibble_lo = nibble_hi - 3;  % Bit position LSB

    % Format energi: tampilkan yang lebih besar antara low dan high
    dom_energy = max(dt.energy_low, dt.energy_high);

    fprintf('  %d      | Bit %2d-%2d  | %s       | E = %10.3e  | %-8s | 0x%X\n', ...
            i, nibble_hi-1, nibble_lo, dt.bits, dom_energy, dt.dtmf_char, dt.dtmf_code);
end

fprintf('%s\n', repmat('-', 1, 72));
fprintf('  Full 32-bit: 0x%08X\n', reconstructed_key);
fprintf('%s\n\n', repmat('-', 1, 72));

% -------------------------------------------------------------------------
% Tabel Detail: Energi per Frekuensi per Simbol
% -------------------------------------------------------------------------
fprintf('[5] Tabel Detail Energi Goertzel per Simbol\n');
fprintf('%s\n', repmat('-', 1, 78));
fprintf('%-6s | %-4s | %-7s | %-7s | %-12s | %-7s | %-7s | %-12s\n', ...
        'Simbol', 'Char', 'f_low', 'f_high', 'E_low (dom)', ...
        'f_low', 'f_high', 'E_high (dom)');
fprintf('%s\n', repmat('-', 1, 78));
for i = 1:N_SYM
    dt = decode_table(i);
    fprintf('  %d    | %-4s | %4d Hz | %4d Hz | E=%9.3e  | %4d Hz | %4d Hz | E=%9.3e\n', ...
            i, dt.dtmf_char, sym_freqs(i,1), sym_freqs(i,2), ...
            dt.energy_low, dt.dominant_low_hz, dt.dominant_high_hz, dt.energy_high);
end
fprintf('%s\n\n', repmat('-', 1, 78));

% -------------------------------------------------------------------------
% Visualisasi
% -------------------------------------------------------------------------
fprintf('[6] Membuat Visualisasi...\n');

% --- Gambar 1: Waveform Sinyal DTMF Input ---
figure('Name', 'DTMF Receiver Testbench - Sinyal Input', ...
       'NumberTitle', 'off', 'Position', [50 550 1100 280]);
t_total = (0:length(payload_signal)-1) / Fs * 1000; % ms
plot(t_total, double(payload_signal), 'b-', 'LineWidth', 0.8);
for k = 1:N_SYM
    xline(k*N/Fs*1000, 'r--', 'LineWidth', 1);
end
title('Sinyal DTMF Input (8 Simbol, Dibangkitkan Secara Matematis)');
xlabel('Waktu (ms)');
ylabel('Amplitudo (int16)');
legend(sprintf('Payload: %s', strjoin(sequence_chars, '-')), 'Location', 'best');
grid on;

% Anotasi simbol di atas waveform
for k = 1:N_SYM
    x_mid = (k - 0.5) * N / Fs * 1000;
    y_pos = max(double(payload_signal)) * 0.85;
    text(x_mid, y_pos, sequence_chars{k}, 'HorizontalAlignment', 'center', ...
         'FontSize', 12, 'FontWeight', 'bold', 'Color', 'red');
end

% --- Gambar 2: Energi Goertzel per Simbol ---
figure('Name', 'DTMF Receiver Testbench - Energi Goertzel', ...
       'NumberTitle', 'off', 'Position', [50 200 1100 320]);

energy_low_dom  = [decode_table.energy_low];
energy_high_dom = [decode_table.energy_high];
x_sym = 1:N_SYM;
sym_labels = sequence_chars;

bar_data = [energy_low_dom(:), energy_high_dom(:)];
b = bar(x_sym, bar_data, 'grouped');
b(1).FaceColor = [0.2 0.6 0.9];
b(2).FaceColor = [0.9 0.4 0.2];

% Anotasi nilai energi di atas bar
for k = 1:N_SYM
    dt = decode_table(k);
    text(k - 0.15, energy_low_dom(k) * 1.05, ...
         sprintf('%dHz', dt.dominant_low_hz), 'FontSize', 7, ...
         'HorizontalAlignment', 'center', 'Color', [0.1 0.3 0.7]);
    text(k + 0.15, energy_high_dom(k) * 1.05, ...
         sprintf('%dHz', dt.dominant_high_hz), 'FontSize', 7, ...
         'HorizontalAlignment', 'center', 'Color', [0.7 0.2 0.1]);
end

set(gca, 'XTick', x_sym, 'XTickLabel', ...
    arrayfun(@(k) sprintf('%s\n(0x%X)', sequence_chars{k}, decode_table(k).dtmf_code), ...
             x_sym, 'UniformOutput', false));
xlabel('Simbol DTMF (Karakter / Kode Hex)');
ylabel('Energi Goertzel (Dominan)');
title('Energi Goertzel Dominan per Simbol — Low Group (Biru) vs High Group (Merah)');
legend({'Frekuensi Low Dominan', 'Frekuensi High Dominan'}, 'Location', 'best');
grid on;

fprintf('Visualisasi selesai. Silakan cek dua figur yang dibuat.\n');

% =========================================================================
% Helper Function
% =========================================================================
function [f_low, f_high] = get_dtmf_freqs(ch)
%GET_DTMF_FREQS Kembalikan [f_low, f_high] Hz untuk karakter DTMF
    switch ch
        case '1', f_low = 697;  f_high = 1209;
        case '2', f_low = 697;  f_high = 1336;
        case '3', f_low = 697;  f_high = 1477;
        case 'A', f_low = 697;  f_high = 1633;
        case '4', f_low = 770;  f_high = 1209;
        case '5', f_low = 770;  f_high = 1336;
        case '6', f_low = 770;  f_high = 1477;
        case 'B', f_low = 770;  f_high = 1633;
        case '7', f_low = 852;  f_high = 1209;
        case '8', f_low = 852;  f_high = 1336;
        case '9', f_low = 852;  f_high = 1477;
        case 'C', f_low = 852;  f_high = 1633;
        case '*', f_low = 941;  f_high = 1209;
        case '0', f_low = 941;  f_high = 1336;
        case '#', f_low = 941;  f_high = 1477;
        case 'D', f_low = 941;  f_high = 1633;
        otherwise
            error('Karakter DTMF tidak dikenal: %s', ch);
    end
end

function code = dtmf_char_to_code(ch)
%DTMF_CHAR_TO_CODE Mapping karakter DTMF ke 4-bit code (sama dengan decision.m)
%   Digunakan untuk menghitung EXPECTED_KEY secara otomatis dari sequence_chars.
    switch ch
        case '1', code = uint8(1);   % 0x1
        case '2', code = uint8(2);   % 0x2
        case '3', code = uint8(3);   % 0x3
        case 'A', code = uint8(10);  % 0xA
        case '4', code = uint8(4);   % 0x4
        case '5', code = uint8(5);   % 0x5
        case '6', code = uint8(6);   % 0x6
        case 'B', code = uint8(11);  % 0xB
        case '7', code = uint8(7);   % 0x7
        case '8', code = uint8(8);   % 0x8
        case '9', code = uint8(9);   % 0x9
        case 'C', code = uint8(12);  % 0xC
        case '*', code = uint8(14);  % 0xE
        case '0', code = uint8(0);   % 0x0
        case '#', code = uint8(15);  % 0xF
        case 'D', code = uint8(13);  % 0xD
        otherwise
            error('Karakter DTMF tidak dikenal untuk mapping: %s', ch);
    end
end
