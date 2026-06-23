function [reconstructed_key, decode_table, goertzel_enable] = dtmf_transmission(payload_symbols)
%DTMF_TRANSMISSION  Top-level pipeline: DTMF Generator + Frame Sync + DTMF Receiver
%
%   Mengorkestrasi tiga modul dalam satu alur transmisi end-to-end:
%
%     [1] DTMF Generator (generate_dtmf.m)
%         Membangkitkan sinyal sinusoidal 12 simbol DTMF:
%         4 simbol sync point "##3#" (predefined) + 8 simbol payload dari user.
%
%     [2] Frame Synchronization (frame_sync.m) — exp 1.7 fixed point v6
%         Menerima sinyal penuh (12 simbol) dalam format fi Q3.13.
%         Mendeteksi pola "##3#" dan mengeluarkan goertzel_enable.
%         Konversi int16 -> fi dilakukan di sini (top-level), mencerminkan
%         bahwa interface hardware RTL yang menangani konversi format,
%         bukan masing-masing IP core.
%
%     [3] DTMF Receiver (dtmf_receiver_top.m)
%         Menerima sinyal yang sama (12 simbol, int16), tetapi hanya
%         memproses irisan payload setelah goertzel_enable dikonfirmasi.
%         Payload diekstrak secara deterministik di sampel ke-2561 s/d 7680
%         (= 4 simbol sync x 640 sampel/simbol), tanpa leading noise.
%         Mendekode 8 simbol payload -> output 32-bit (tiap 4-bit = 1 simbol).
%
%   Input:
%       payload_symbols  - String 8 simbol DTMF valid (0-9, A-D, *, #)
%                          Contoh: '3A7C9B1D'
%
%   Output:
%       reconstructed_key - uint32, hasil decode 32-bit dari payload
%       decode_table      - struct array (8 elemen), detail decode per simbol:
%                           .symbol_index, .dtmf_char, .dtmf_code, .bits,
%                           .dominant_low_hz, .dominant_high_hz,
%                           .energy_low, .energy_high
%       goertzel_enable   - logical (1 = sync berhasil, 0 = sync gagal)
%
%   Contoh penggunaan:
%       [key, tbl, en] = dtmf_transmission('3A7C9B1D');
%       fprintf('Decoded key: 0x%08X\n', key);
%
%       % Tanpa output argument -> tampilkan hanya ringkasan
%       dtmf_transmission('12345678');

% =========================================================================
% Step 0: Setup path ke sub-modul (relatif terhadap lokasi file ini)
%   Direktori ini   : MATLAB/DTMF/DTMF_Transmission/
%   Generator       : MATLAB/DTMF/DTMF_Generator/
%   Receiver        : MATLAB/DTMF/DTMF_Receiver/
%   Frame Sync      : MATLAB/Frame Synchronization/exp 1.7 fixed point v6/
% =========================================================================
this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, '..', 'DTMF_Generator'));
addpath(fullfile(this_dir, '..', 'DTMF_Receiver'));
addpath(fullfile(this_dir, '..', '..', 'Frame Synchronization', 'exp 1.7 fixed point v6'));

% =========================================================================
% Step 1: Parameter Sistem & Validasi Input
% =========================================================================
SYNC_POINT      = '##3#';   % Sync point predefined (preamble 4 simbol)
SYNC_LEN        = 4;        % Jumlah simbol sync point
PAYLOAD_LEN     = 8;        % Jumlah simbol payload
SAMPLES_PER_SYM = 640;      % 20 ms x 32 kHz = 640 sampel/simbol

% --- Validasi tipe ---
if ~(ischar(payload_symbols) || isstring(payload_symbols))
    error('dtmf_transmission: payload_symbols harus berupa string/char. Contoh: ''3A7C9B1D''');
end
payload_str = upper(char(payload_symbols));

% --- Validasi panjang ---
if numel(payload_str) ~= PAYLOAD_LEN
    error('dtmf_transmission: payload_symbols harus tepat %d simbol (diterima: %d simbol: ''%s'').', ...
          PAYLOAD_LEN, numel(payload_str), payload_str);
end

% --- Validasi karakter ---
valid_chars = '0123456789ABCD*#';
for k = 1:numel(payload_str)
    if ~any(payload_str(k) == valid_chars)
        error('dtmf_transmission: Karakter tidak valid pada posisi %d: ''%s''. Gunakan: 0-9, A-D, *, #', ...
              k, payload_str(k));
    end
end

full_sequence = [SYNC_POINT, payload_str];  % 12 simbol: "##3#" + 8 payload

% =========================================================================
% Print header
% =========================================================================
SEP_DOUBLE = repmat('=', 1, 66);
SEP_SINGLE = repmat('-', 1, 66);

fprintf('\n%s\n', SEP_DOUBLE);
fprintf('  DTMF TRANSMISSION PIPELINE\n');
fprintf('%s\n', SEP_SINGLE);
fprintf('  Sync Point   : %s  (%d simbol)\n', SYNC_POINT, SYNC_LEN);
fprintf('  Payload      : %s  (%d simbol)\n', payload_str, PAYLOAD_LEN);
fprintf('  Full Frame   : %s  (%d simbol)\n', full_sequence, SYNC_LEN + PAYLOAD_LEN);
fprintf('  Total Sampel : %d  (%d simbol x %d sampel/simbol)\n', ...
        (SYNC_LEN + PAYLOAD_LEN) * SAMPLES_PER_SYM, ...
        SYNC_LEN + PAYLOAD_LEN, SAMPLES_PER_SYM);
fprintf('%s\n\n', SEP_DOUBLE);

% =========================================================================
% Step 2: [DTMF Generator] Bangkitkan sinyal 12 simbol
%   Output: dtmf_out (int16, Q3.13), t (vektor waktu)
%   Total sampel = 12 x 640 = 7680
% =========================================================================
fprintf('[1/3] DTMF Generator -- membangkitkan %d simbol...\n', SYNC_LEN + PAYLOAD_LEN);
[dtmf_out, ~] = generate_dtmf(full_sequence);
fprintf('      Sinyal dibangkitkan: %d sampel | Tipe: %s | Format: Q3.13\n\n', ...
        numel(dtmf_out), class(dtmf_out));

% =========================================================================
% Step 3: Konversi int16 -> fi (Q3.13) untuk Frame Synchronization
%
%   generate_dtmf() menghasilkan int16 dalam representasi Q3.13:
%     nilai_riil = int16_value / 2^13 = int16_value / 8192
%
%   Konversi ini dilakukan di top-level (bukan di dalam frame_sync),
%   mencerminkan bahwa pada RTL, hardware interface (ADC/bus) yang
%   mengonversi format fixed-point sebelum masuk ke tiap IP core.
%
%   PENTING — Leading noise sebelum sinyal DTMF:
%   flagging.m mendeteksi '##' menggunakan perbandingan RISE:
%       curr_941 >= 3 * prev_941  (lag 32 frame)
%   Algoritma ini membutuhkan kondisi awal (32 frame / 1280 sampel) yang
%   berdaya rendah sebelum sinyal DTMF dimulai, agar ada kontras yang
%   terukur ketika '##' muncul. Ini konsisten dengan run_frame_sync_demo.m
%   yang juga memprepend 1280 sampel noise acak sebelum preamble.
%
%   Noise hanya ditambahkan ke input_fi (untuk Frame Sync).
%   dtmf_out tetap bersih (untuk DTMF Receiver, payload slice deterministik).
% =========================================================================
F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');

% Leading noise: 32 frame x 40 sampel/frame = 1280 sampel, uniform [-2, 2]
% (identik dengan run_frame_sync_demo.m: (4*rand(1,1280))-2)
LEADING_NOISE_SAMPLES = 32 * 40;   % = 1280 (= 2 simbol DTMF @ 640 spl/simbol)
leading_noise_fp      = (4 * rand(1, LEADING_NOISE_SAMPLES)) - 2;  % double, [-2, 2]

% Gabungkan: [noise | dtmf_out_normalized]
% sine_gen kini menghasilkan amplitudo 8191/tone (= 2^13-1, lihat sine_gen.m).
% Dua tone dijumlah: maks ~16382 int16.
% Dibagi 8192 (= 2^13) -> amplitudo ~2.0 float, sesuai dengan
% run_frame_sync_demo.m (unit sinusoid amplitude 1.0/tone, sum = 2.0). ✓
dtmf_normalized = double(dtmf_out) / 8192;   % int16 Q3.13 -> float, amplitude ~2.0

input_fi = fi([leading_noise_fp, dtmf_normalized], 1, 16, 13, 'fimath', F);

% =========================================================================
% Step 4: [Frame Synchronization] Deteksi sync point "##3#"
%
%   frame_sync() menerima input_fi yang berisi:
%     [1280 spl noise] + [7680 spl sinyal DTMF (12 simbol)]
%   = 8960 sampel total.
%
%   Frame Sync memproses seluruh sinyal dan mengembalikan
%   goertzel_enable = 1 jika pola "##3#" terdeteksi.
%
%   DTMF Receiver (Step 5) tetap menggunakan dtmf_out asli (tanpa noise)
%   untuk ekstraksi payload — posisi payload tetap deterministik.
% =========================================================================
fprintf('[2/3] Frame Synchronization -- mendeteksi sync point "%s"...\n', SYNC_POINT);
fprintf('%s\n', SEP_SINGLE);
goertzel_enable = frame_sync(input_fi);
fprintf('%s\n', SEP_SINGLE);

if goertzel_enable
    fprintf('      [OK] Sync point "%s" TERDETEKSI. goertzel_enable = 1\n\n', SYNC_POINT);
else
    fprintf('      [GAGAL] Sync point TIDAK terdeteksi. goertzel_enable = 0\n\n');
    reconstructed_key = uint32(0);
    decode_table      = [];
    warning('dtmf_transmission:syncFailed', ...
            'Frame sync gagal mendeteksi "%s". DTMF Receiver tidak dijalankan.', SYNC_POINT);
    return;
end

% =========================================================================
% Step 5: [DTMF Receiver] Dekode payload — Opsi B: Deterministic Slice
%
%   Karena generate_dtmf() menghasilkan sinyal tanpa leading noise dan
%   preamble selalu tepat 4 simbol (= 2560 sampel pertama), payload
%   selalu dimulai di sampel ke-2561. Ini adalah informasi timing statis
%   — analog dengan RTL di mana sistem tahu dari desain kapan payload
%   dimulai setelah goertzel_enable di-assert, tanpa perlu frame_sync
%   mengirim sinyal posisi tambahan.
%
%   dtmf_receiver_top() menerima int16 (bukan fi), sehingga payload
%   diambil langsung dari dtmf_out (bukan input_fi).
% =========================================================================
payload_start  = SYNC_LEN * SAMPLES_PER_SYM + 1;            % = 2561
payload_end    = (SYNC_LEN + PAYLOAD_LEN) * SAMPLES_PER_SYM; % = 7680
payload_signal = dtmf_out(payload_start:payload_end);        % int16, 5120 sampel

fprintf('[3/3] DTMF Receiver -- mendekode %d simbol payload...\n', PAYLOAD_LEN);
fprintf('      Payload slice: sampel %d s/d %d (%d sampel = %d simbol x %d)\n', ...
        payload_start, payload_end, numel(payload_signal), PAYLOAD_LEN, SAMPLES_PER_SYM);
fprintf('%s\n', SEP_SINGLE);
[reconstructed_key, decode_table] = dtmf_receiver_top(payload_signal);
fprintf('%s\n', SEP_SINGLE);

% =========================================================================
% Step 6: Ringkasan Akhir & Verifikasi
% =========================================================================
expected_key = compute_expected_key(payload_str);

fprintf('\n%s\n', SEP_DOUBLE);
fprintf('  RINGKASAN HASIL\n');
fprintf('%s\n', SEP_SINGLE);
fprintf('  Payload          : %s\n', payload_str);
fprintf('  Expected Key     : 0x%08X\n', expected_key);
fprintf('  Reconstructed Key: 0x%08X\n', reconstructed_key);
if reconstructed_key == expected_key
    fprintf('  Status           : [PASS] Dekode sesuai ekspektasi!\n');
else
    fprintf('  Status           : [FAIL] Dekode TIDAK sesuai ekspektasi.\n');
end
fprintf('%s\n\n', SEP_DOUBLE);

% Print decode table ringkasan
fprintf('  Tabel Dekode Payload (32-bit output):\n');
fprintf('  %s\n', repmat('-', 1, 54));
fprintf('  %-6s  %-6s  %-8s  %-8s  %-10s\n', 'Simbol', 'Char', 'Bits', 'Code(Hex)', 'HexNibble');
fprintf('  %s\n', repmat('-', 1, 54));
for i = 1:numel(decode_table)
    dt = decode_table(i);
    fprintf('  %-6d  %-6s  %-8s  0x%-6X  [bit%2d-%2d]\n', ...
            i, dt.dtmf_char, dt.bits, dt.dtmf_code, ...
            32 - (i-1)*4 - 1, 32 - i*4);
end
fprintf('  %s\n', repmat('-', 1, 54));
fprintf('  Full 32-bit: 0x%08X\n\n', reconstructed_key);

end % function dtmf_transmission

% =========================================================================
% Helper: Hitung expected key dari payload string (untuk verifikasi)
%   Menggunakan mapping 4-bit yang sama dengan decision.m di DTMF Receiver.
% =========================================================================
function key = compute_expected_key(payload_str)
    key = uint32(0);
    for k = 1:numel(payload_str)
        code = local_char_to_code(payload_str(k));
        key  = bitor(bitshift(key, 4), uint32(code));
    end
end

function code = local_char_to_code(ch)
%LOCAL_CHAR_TO_CODE  Mapping karakter DTMF -> 4-bit code (sesuai decision.m)
    switch upper(ch)
        case '1', code = uint8(1);
        case '2', code = uint8(2);
        case '3', code = uint8(3);
        case 'A', code = uint8(10);
        case '4', code = uint8(4);
        case '5', code = uint8(5);
        case '6', code = uint8(6);
        case 'B', code = uint8(11);
        case '7', code = uint8(7);
        case '8', code = uint8(8);
        case '9', code = uint8(9);
        case 'C', code = uint8(12);
        case '*', code = uint8(14);
        case '0', code = uint8(0);
        case '#', code = uint8(15);
        case 'D', code = uint8(13);
        otherwise
            error('local_char_to_code: Karakter tidak dikenal: ''%s''', ch);
    end
end
