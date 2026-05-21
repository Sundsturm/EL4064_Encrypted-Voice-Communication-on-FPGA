%% FUNGSI UTAMA DEKODER (TOP LEVEL)
function reconstructed_key = reconstruct_key(sinyal_input)
    % Fungsi untuk mendekode sinyal kontinu 8-segmen menjadi integer 24-bit
    % Ekivalen dengan `top_dtmfencode.vhd`
    
    % Parameter Dasar Sistem
    Fs = 32000;         % Frekuensi sampling 32 kHz
    N = 640;            % Ukuran chunk (tepat 20 ms)
    
    % Validasi input
    if length(sinyal_input) < 8 * N
        error('Panjang sinyal input kurang dari 5120 sampel.');
    end
    
    % Inisialisasi Kunci (Akumulator)
    reconstructed_key = uint32(0);
    
    % Looping sebanyak 8 kali (8 segmen)
    for i = 1:8
        % --- Log Iterasi ---
        fprintf('\n>> Memproses Segmen %d/8...\n', i);
        
        % 1. Pemotongan sinyal (indeks iterasi 1-based)
        idx_start = (i - 1) * N + 1;
        idx_end = i * N;
        chunk = sinyal_input(idx_start:idx_end);
        
        % 2. Modul Goertzel & Comparator
        % Menganalisis daya dan mengembalikan frekuensi dominan
        [power_low, power_high] = goertzel_detector(chunk, Fs);
        [f_low_detected, f_high_detected] = comparator(power_low, power_high);
        
        % 3. Modul Decision (Decoder)
        % Menerjemahkan frekuensi menjadi nilai 3-bit (0-7)
        decode_val = decision(f_low_detected, f_high_detected);
        
        % 4. Modul Shift-Add Accumulator
        % Menggeser kunci saat ini ke kiri 3-bit, dan menempelkan nilai baru
        reconstructed_key = shift_add(reconstructed_key, decode_val);
    end
end
