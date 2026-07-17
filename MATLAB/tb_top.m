% =========================================================================
%  tb_main_integration.m
%  Master Testbench Integrasi End-to-End
%  Sistem Pengiriman Sekuens DTMF Satu Arah — Rekonstruksi Kunci 24-bit
% =========================================================================
%  Arsitektur Aliran Data:
%
%    [generate_full_sequence]  -->  sinyal Tx (7680 sampel)
%            |
%            v
%    [mock_frame_sync]         -->  goertzel_enable_start_idx (2561)
%            |
%            v
%    [receiver_pipeline]       -->  reconstructed_key (24-bit)
%            |
%            v
%    [Verifikasi Hex]          -->  PASS / FAIL
%
%  Spesifikasi Timing:
%    Fs          = 32.000 Hz
%    Durasi nada = 20 ms  = 640 sampel (TANPA JEDA)
%    Preamble    = 4 nada x 640 = 2560 sampel  ( '#','#','3','#' )
%    Payload     = 8 nada x 640 = 5120 sampel  ( 8 segmen 3-bit )
%    Total Tx    = 12 nada      = 7680 sampel
%
%  Dependensi (harus ada di MATLAB path):
%    DTMF/goertzel_detector.m  |  DTMF/comparator.m
%    DTMF/decision.m           |  DTMF/shift_add.m
%
%  Author  : tb_main_integration  (Lead DSP Engineer — integrasi)
%  Version : 1.0  (2026-05-25)
% =========================================================================

clear; clc; close all;

% ── Tambahkan path subsistem ke MATLAB search path ──────────────────────
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'DTMF-Receiver-RX'));
% (Frame Sync Kean belum diintegrasikan — digantikan mock di bawah)

% =========================================================================
%  PARAMETER GLOBAL SISTEM
% =========================================================================
Fs          = 32000;    % Frekuensi sampling (Hz)
T_TONE      = 0.020;    % Durasi 1 nada (detik) = 20 ms
N_TONE      = Fs * T_TONE;   % 640 sampel per nada  (HARUS BILANGAN BULAT)
N_PREAMBLE  = 4 * N_TONE;    % 2560 sampel preamble
N_PAYLOAD   = 8 * N_TONE;    % 5120 sampel payload
N_TOTAL     = N_PREAMBLE + N_PAYLOAD; % 7680 sampel total

% Periksa integritas aritmetika parameter
assert(N_TONE      == 640,  'KESALAHAN: N_TONE harus tepat 640 sampel!');
assert(N_PREAMBLE  == 2560, 'KESALAHAN: N_PREAMBLE harus tepat 2560 sampel!');
assert(N_TOTAL     == 7680, 'KESALAHAN: N_TOTAL harus tepat 7680 sampel!');

% =========================================================================
%  SKENARIO UJI MASTER
% =========================================================================
KEY_24BIT = uint32(hex2dec('3A7C9B1D'));  % Kunci uji (dapat diganti)

fprintf('\n');
fprintf('=========================================================\n');
fprintf('  MASTER TESTBENCH — Integrasi End-to-End DTMF 24-bit  \n');
fprintf('=========================================================\n');
fprintf('  Kunci Asal (Hex)  : 0x%s\n', dec2hex(KEY_24BIT, 6));
fprintf('  Kunci Asal (Dec)  : %d\n',   KEY_24BIT);
fprintf('  Kunci Asal (Biner): %s\n',   dec2bin(KEY_24BIT, 24));
fprintf('---------------------------------------------------------\n');

% =========================================================================
%  BLOK 1 — PENGIRIM (TRANSMITTER)
%  Fungsi  : generate_full_sequence(key_24bit)
%  Keluaran: sinyal_tx  — array 1 x 7680 (KONTINU, TANPA JEDA)
% =========================================================================
fprintf('\n[BLOK 1] Membangkitkan Sekuens Sinyal Tx Penuh...\n');
sinyal_tx = generate_full_sequence(KEY_24BIT, Fs, N_TONE);

% Verifikasi panjang sinyal
assert(length(sinyal_tx) == N_TOTAL, ...
    sprintf('KESALAHAN: Sinyal Tx harus %d sampel, bukan %d!', N_TOTAL, length(sinyal_tx)));
fprintf('[BLOK 1] Sinyal Tx berhasil dibangkitkan: %d sampel (%.1f ms)\n', ...
    length(sinyal_tx), length(sinyal_tx)/Fs*1000);

% =========================================================================
%  BLOK 2 — TIRUAN FRAME SYNC (MOCK — menggantikan cross-correlation Kean)
%  Fungsi  : mock_frame_sync(sinyal_input)
%  Keluaran: goertzel_enable_start_idx — indeks awal payload (1-based)
% =========================================================================
fprintf('\n[BLOK 2] Menjalankan Mock Frame Sync...\n');
goertzel_enable_start_idx = mock_frame_sync(sinyal_tx, N_PREAMBLE);

% Verifikasi indeks trigger
EXPECTED_IDX = N_PREAMBLE + 1;   % = 2561 (1-based)
assert(goertzel_enable_start_idx == EXPECTED_IDX, ...
    sprintf('KESALAHAN KRITIS: goertzel_enable_start_idx harus %d, bukan %d!', ...
    EXPECTED_IDX, goertzel_enable_start_idx));
fprintf('[BLOK 2] goertzel_enable AKTIF mulai indeks ke-%d (sampel ke-2561)\n', ...
    goertzel_enable_start_idx);

% =========================================================================
%  BLOK 3 — PENERIMA (RECEIVER PIPELINE)
%  Fungsi  : receiver_pipeline(sinyal_input, goertzel_enable_start_idx)
%  Keluaran: reconstructed_key — uint32 kunci 24-bit hasil rekonstruksi
% =========================================================================
fprintf('\n[BLOK 3] Menjalankan Receiver Pipeline...\n');
reconstructed_key = receiver_pipeline(sinyal_tx, goertzel_enable_start_idx, Fs, N_TONE);

% =========================================================================
%  VERIFIKASI AKHIR
% =========================================================================
fprintf('\n=========================================================\n');
fprintf('  HASIL VERIFIKASI AKHIR\n');
fprintf('---------------------------------------------------------\n');
    key_24bit_active = bitand(KEY_24BIT, uint32(16777215)); % Ambil 24-bit aktif (0xFFFFFF)
    fprintf('  Kunci Asal           (Hex) : 0x%s\n', dec2hex(KEY_24BIT, 6));
    fprintf('  Kunci Asal (24-bit)  (Hex) : 0x%s\n', dec2hex(key_24bit_active, 6));
    fprintf('  Kunci Rekonstruksi   (Hex) : 0x%s\n', dec2hex(reconstructed_key, 6));
    fprintf('  Kunci Asal (24-bit)  (Bin) : %s\n',   dec2bin(key_24bit_active, 24));
    fprintf('  Kunci Rekonstruksi   (Bin) : %s\n',   dec2bin(reconstructed_key, 24));
    fprintf('---------------------------------------------------------\n');

    if key_24bit_active == reconstructed_key
        fprintf('  STATUS : [PASS] SUKSES — Kunci 100%% berhasil direkonstruksi!\n');
        fprintf('           Tidak ada bit tergeser (zero sample-slip).\n');
    else
        % Hitung jumlah bit yang salah (Hamming distance)
        xor_val  = bitxor(key_24bit_active, reconstructed_key);
        n_errors = sum(dec2bin(xor_val, 24) == '1');
        fprintf('  STATUS : [FAIL] GAGAL — %d bit tidak cocok (XOR: 0x%s)\n', ...
            n_errors, dec2hex(xor_val, 6));
    end
    fprintf('=========================================================\n\n');

% =========================================================================
%  VISUALISASI — Sinyal Tx Lengkap dengan Anotasi Segmen
% =========================================================================
plot_tx_signal(sinyal_tx, Fs, N_TONE, KEY_24BIT);


% #########################################################################
% =========================================================================
%  DEFINISI FUNGSI LOKAL
% =========================================================================
% #########################################################################

% =========================================================================
%  FUNGSI 1: generate_full_sequence
% =========================================================================
function sinyal_tx = generate_full_sequence(key_24bit, Fs, N_TONE)
% GENERATE_FULL_SEQUENCE  Membangkitkan sekuens DTMF lengkap 12 nada:
%   4 nada Preamble  : '#','#','3','#'
%   8 nada Payload   : 8 segmen 3-bit dari kunci 24-bit
%
% Input:
%   key_24bit  — uint32, kunci 24-bit
%   Fs         — frekuensi sampling (Hz)
%   N_TONE     — jumlah sampel per nada (640)
%
% Output:
%   sinyal_tx  — array 1×7680 (double), KONTINU TANPA JEDA

    t = (0 : N_TONE - 1) / Fs;   % Vektor waktu per nada (1×640)

    % Fungsi anonim pembangkit 1 nada DTMF (640 sampel)
    gen_tone = @(f_low, f_high) 0.5*sin(2*pi*f_low*t) + 0.5*sin(2*pi*f_high*t);

    % ── Frekuensi Preamble ──────────────────────────────────────────────
    % '#' = 941 Hz + 1477 Hz
    % '3' = 697 Hz + 1477 Hz
    F_HASH_LOW  = 941;   F_HASH_HIGH = 1477;
    F_THREE_LOW = 697;   F_THREE_HIGH = 1477;

    tone_hash  = gen_tone(F_HASH_LOW,  F_HASH_HIGH);   % 1×640
    tone_three = gen_tone(F_THREE_LOW, F_THREE_HIGH);   % 1×640

    % ── Preamble: '#','#','3','#' ────────────────────────────────────────
    fprintf('  [TX] Membangkitkan Preamble: #  #  3  #\n');
    preamble = [tone_hash, tone_hash, tone_three, tone_hash]; % 1×2560

    % ── Tabel Pemetaan 3-bit → Frekuensi (sesuai decision.m / decision.vhd) ──
    %   Nilai | DTMF | f_low | f_high
    %     0   |  '1' |  697  |  1209
    %     1   |  '2' |  697  |  1336
    %     2   |  '4' |  770  |  1209
    %     3   |  '5' |  770  |  1336
    %     4   |  '7' |  852  |  1209
    %     5   |  '8' |  852  |  1336
    %     6   |  '*' |  941  |  1209
    %     7   |  '0' |  941  |  1336
    freq_map = [
        697, 1209;   % 000 → '1'
        697, 1336;   % 001 → '2'
        770, 1209;   % 010 → '4'
        770, 1336;   % 011 → '5'
        852, 1209;   % 100 → '7'
        852, 1336;   % 101 → '8'
        941, 1209;   % 110 → '*'
        941, 1336    % 111 → '0'
    ];

    % ── Payload: 8 segmen 3-bit (MSB → LSB) ─────────────────────────────
    fprintf('  [TX] Membangkitkan Payload 8 Segmen (kunci: 0x%s):\n', ...
        dec2hex(key_24bit, 6));
    payload = zeros(1, 8 * N_TONE);  % Pre-alokasi 1×5120
    for i = 7:-1:0
        seg_idx  = 8 - i;                                          % 1..8
        seg_val  = bitand(bitshift(uint32(key_24bit), -i*3), 7);  % 0..7
        f_low    = freq_map(seg_val + 1, 1);
        f_high   = freq_map(seg_val + 1, 2);
        tone_seg = gen_tone(f_low, f_high);

        payload_start = (seg_idx - 1) * N_TONE + 1;
        payload_end   = seg_idx * N_TONE;
        payload(payload_start : payload_end) = tone_seg;

        fprintf('    Segmen %d/8 → 3-bit=%d (%s) | %d Hz + %d Hz\n', ...
            seg_idx, seg_val, dec2bin(seg_val, 3), f_low, f_high);
    end

    % ── Gabungkan Preamble + Payload (KONTINU) ───────────────────────────
    sinyal_tx = [preamble, payload];   % 1×7680

    fprintf('  [TX] Total sinyal Tx: %d sampel (Preamble=%d | Payload=%d)\n', ...
        length(sinyal_tx), length(preamble), length(payload));
end


% =========================================================================
%  FUNGSI 2: mock_frame_sync
% =========================================================================
function goertzel_enable_start_idx = mock_frame_sync(sinyal_input, N_PREAMBLE)
% MOCK_FRAME_SYNC  Tiruan modul Frame Synchronization milik Kean.
%
%   Di tahap integrasi ini, logika cross-correlation penuh belum digabung.
%   Fungsi ini mensimulasikan hasil akhir Frame Sync dengan pengetahuan
%   deterministik bahwa preamble menempati tepat N_PREAMBLE = 2560 sampel
%   pertama, sehingga payload dimulai pada indeks 2561 (1-based).
%
%   Antarmuka yang didefinisikan di sini meniru sinyal kontrol goertzel_enable
%   pada arsitektur FPGA: nilai true (logika tinggi) menyatakan bahwa
%   blok Goertzel pada receiver boleh mulai memproses data.
%
%   Catatan untuk integrasi nyata (tahap berikutnya):
%     Ganti baris "goertzel_enable_start_idx = N_PREAMBLE + 1" dengan
%     panggilan ke fungsi cross-correlation Kean. Interface keluarannya
%     harus tetap berupa indeks sampel 1-based di dalam sinyal_input.
%
% Input:
%   sinyal_input  — sinyal Tx penuh (1×7680)
%   N_PREAMBLE    — jumlah sampel preamble (2560)
%
% Output:
%   goertzel_enable_start_idx — indeks 1-based awal payload (2561)

    fprintf('  [FRAME SYNC MOCK] Preamble ditentukan secara deterministik.\n');
    fprintf('  [FRAME SYNC MOCK] Preamble : indeks 1 s.d. %d (%d sampel)\n', ...
        N_PREAMBLE, N_PREAMBLE);

    % ── Sinyal kontrol goertzel_enable aktif SETELAH preamble selesai ──
    % Dalam domain FPGA: rising edge goertzel_enable ≡ sampel ke-(N_PREAMBLE+1)
    goertzel_enable_start_idx = N_PREAMBLE + 1;   % = 2561

    fprintf('  [FRAME SYNC MOCK] goertzel_enable := TRUE  @ indeks %d\n', ...
        goertzel_enable_start_idx);

    % ── Sanity-check: panjang sinyal harus cukup untuk payload ──────────
    n_remaining = length(sinyal_input) - N_PREAMBLE;
    fprintf('  [FRAME SYNC MOCK] Sisa sampel untuk payload  : %d sampel\n', ...
        n_remaining);
    if n_remaining < 8 * 640
        warning('[FRAME SYNC] Sinyal terlalu pendek untuk 8 nada payload!');
    end
end


% =========================================================================
%  FUNGSI 3: receiver_pipeline
% =========================================================================
function reconstructed_key = receiver_pipeline(sinyal_input, ...
                                               goertzel_enable_start_idx, ...
                                               Fs, N_TONE)
% RECEIVER_PIPELINE  Pipeline penerima DTMF: memotong payload, menjalankan
%   Goertzel → Comparator → Decision → Shift-Add Accumulator sebanyak
%   tepat 8 iterasi mulai dari goertzel_enable_start_idx.
%
%   Ekivalen perilaku top-level dari reconstruct_key.m, namun bekerja
%   pada jendela sinyal yang sudah di-gate oleh Frame Sync (bukan dari
%   awal sinyal penuh).
%
% Input:
%   sinyal_input              — sinyal penuh (1×7680)
%   goertzel_enable_start_idx — indeks 1-based awal payload (2561)
%   Fs                        — frekuensi sampling (Hz)
%   N_TONE                    — jumlah sampel per nada (640)
%
% Output:
%   reconstructed_key — uint32, kunci 24-bit hasil rekonstruksi

    N_SEGMENTS = 8;                     % Tepat 8 iterasi pemotongan
    reconstructed_key = uint32(0);      % Inisialisasi Shift-Add Accumulator

    fprintf('  [RX] goertzel_enable AKTIF → mulai proses dari indeks %d\n', ...
        goertzel_enable_start_idx);
    fprintf('  [RX] Melakukan %d iterasi pemotongan @%d sampel/chunk:\n', ...
        N_SEGMENTS, N_TONE);

    for seg = 1 : N_SEGMENTS
        % ── 1. Pemotongan Chunk (640 sampel) ──────────────────────────
        %   Indeks chunk ke-i dimulai di:
        %     goertzel_enable_start_idx + (seg-1)*N_TONE
        %   Tidak ada sample-slip: setiap chunk persis N_TONE sampel.
        chunk_start = goertzel_enable_start_idx + (seg - 1) * N_TONE;
        chunk_end   = chunk_start + N_TONE - 1;

        % Guard terhadap out-of-bounds
        if chunk_end > length(sinyal_input)
            error('[RX] Indeks chunk ke-%d melebihi panjang sinyal! (%d > %d)', ...
                seg, chunk_end, length(sinyal_input));
        end

        chunk = sinyal_input(chunk_start : chunk_end);

        fprintf('\n  -- Segmen %d/8 (sampel %d:%d) --------------------\n', ...
            seg, chunk_start, chunk_end);

        % ── 2. Goertzel Detector ──────────────────────────────────────
        %   Menghitung daya di Low Group [697,770,852,941] Hz
        %   dan High Group [1209,1336,1477] Hz
        [power_low, power_high] = goertzel_detector(chunk, Fs);

        % ── 3. Comparator — Cari Frekuensi Dominan ───────────────────
        [f_low_det, f_high_det] = comparator(power_low, power_high);

        % ── 4. Decision — Terjemahkan ke Nilai 3-bit ─────────────────
        decode_val = decision(f_low_det, f_high_det);

        % ── 5. Shift-Add Accumulator ──────────────────────────────────
        %   Geser kunci ke kiri 3-bit, tambahkan nilai 3-bit baru
        reconstructed_key = shift_add(reconstructed_key, decode_val);

        fprintf('  Akumulasi setelah segmen %d : 0x%s  (biner: %s)\n', ...
            seg, dec2hex(reconstructed_key, 6), ...
            dec2bin(reconstructed_key, min(seg*3, 24)));
    end

    fprintf('\n  [RX] Pipeline selesai. Kunci terekonstruksi: 0x%s\n', ...
        dec2hex(reconstructed_key, 6));
end


% =========================================================================
%  FUNGSI 4: plot_tx_signal  (Visualisasi)
% =========================================================================
function plot_tx_signal(sinyal_tx, Fs, N_TONE, key_24bit)
% PLOT_TX_SIGNAL  Memvisualisasikan sinyal Tx 7680 sampel dengan anotasi
%   batas segmen, label preamble/payload, dan informasi kunci.

    N_TOTAL = length(sinyal_tx);
    t_axis  = (0 : N_TOTAL - 1) / Fs * 1000;   % Sumbu waktu dalam ms

    % ── Label setiap segmen ──────────────────────────────────────────────
    seg_labels = {'#', '#', '3', '#'};  % Preamble
    freq_map = [
        697, 1209; 697, 1336; 770, 1209; 770, 1336;
        852, 1209; 852, 1336; 941, 1209; 941, 1336
    ];
    for i = 7:-1:0
        seg_val = bitand(bitshift(uint32(key_24bit), -i*3), 7);
        dtmf_chars = {'1','2','4','5','7','8','*','0'};
        seg_labels{end+1} = dtmf_chars{seg_val + 1}; %#ok<AGROW>
    end

    figure('Name','Sinyal Tx DTMF Lengkap (7680 Sampel)', ...
           'NumberTitle','off', 'Color','white', 'Position',[100 100 1200 500]);

    plot(t_axis, sinyal_tx, 'Color',[0.1 0.45 0.8], 'LineWidth', 0.8);
    hold on;

    % ── Warna zona preamble vs payload ──────────────────────────────────
    N_PRE_ms = (4 * N_TONE / Fs) * 1000;   % 80 ms
    fill([0, N_PRE_ms, N_PRE_ms, 0], [-1.1, -1.1, 1.1, 1.1], ...
        [0.95 0.88 0.70], 'FaceAlpha', 0.25, 'EdgeColor','none');
    fill([N_PRE_ms, t_axis(end), t_axis(end), N_PRE_ms], ...
        [-1.1, -1.1, 1.1, 1.1], ...
        [0.70 0.90 0.80], 'FaceAlpha', 0.25, 'EdgeColor','none');

    % ── Garis batas tiap nada + label ───────────────────────────────────
    for k = 1 : 11
        x_ms = k * N_TONE / Fs * 1000;
        xline(x_ms, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.7);
    end
    for k = 1 : 12
        x_center_ms = (k - 0.5) * N_TONE / Fs * 1000;
        if k <= 4
            clr = [0.6 0.3 0.0];
            lbl = sprintf('[P%d]\n''%s''', k, seg_labels{k});
        else
            clr = [0.0 0.45 0.2];
            lbl = sprintf('[D%d]\n''%s''', k-4, seg_labels{k});
        end
        text(x_center_ms, 0.92, lbl, 'HorizontalAlignment','center', ...
            'FontSize',7.5, 'Color', clr, 'FontWeight','bold');
    end

    % ── Dekorasi ─────────────────────────────────────────────────────────
    xlabel('Waktu (ms)',  'FontSize', 11);
    ylabel('Amplitudo',  'FontSize', 11);
    title(sprintf(['Sinyal Tx Lengkap — Kunci 0x%s | ' ...
        '12 nada × 20 ms = 240 ms (7680 sampel @ %d Hz)'], ...
        dec2hex(key_24bit, 6), Fs), 'FontSize', 12, 'FontWeight','bold');

    legend({'Sinyal Tx', 'Zona Preamble (4×20 ms)', 'Zona Payload (8×20 ms)'}, ...
        'Location','southeast', 'FontSize', 9);
    xlim([0, t_axis(end)]);
    ylim([-1.15, 1.15]);
    grid on;
    hold off;
end


% =========================================================================
%  FUNGSI LOKAL 5: shift_add
% =========================================================================
function reconstructed_key = shift_add(reconstructed_key, decode_val)
% SHIFT_ADD  Fungsi lokal untuk mengumpulkan segmen kunci 3-bit.
%   Memetakan kode DTMF 4-bit kembali ke nilai 3-bit asalnya,
%   kemudian menggeser reconstructed_key ke kiri 3 bit dan menambahkannya.

    switch decode_val
        case 1,  val_3bit = uint32(0); % '1'
        case 2,  val_3bit = uint32(1); % '2'
        case 4,  val_3bit = uint32(2); % '4'
        case 5,  val_3bit = uint32(3); % '5'
        case 7,  val_3bit = uint32(4); % '7'
        case 8,  val_3bit = uint32(5); % '8'
        case 14, val_3bit = uint32(6); % '*'
        case 0,  val_3bit = uint32(7); % '0'
        otherwise
            error('shift_add: Kode DTMF %d tidak valid untuk pemetaan 3-bit!', decode_val);
    end

    reconstructed_key = bitshift(reconstructed_key, 3) + val_3bit;
end
