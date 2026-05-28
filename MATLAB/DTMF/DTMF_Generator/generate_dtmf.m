function [dtmf_out, t] = generate_dtmf(tone_sequence)
%GENERATE_DTMF Pembangkit sinyal Voice-Band Modem berbasis DTMF
%   [dtmf_out, t] = generate_dtmf(tone_sequence)
%
%   Memodelkan perilaku perangkat keras untuk membangkitkan sinyal DTMF 16-simbol
%   tanpa jeda sunyi (silence gap) antarpergantian nada, mempertahankan 
%   fase kontinu (phase continuity) antar simbol.
%
%   Input:
%       tone_sequence - Array atau string sekuens karakter DTMF (0-9, A-D, *, #)
%   Output:
%       dtmf_out      - Array sinyal audio 1D (int16, skala Q3.13)
%       t             - Vektor waktu (domain waktu) untuk plotting

    % Jika dipanggil tanpa argumen, jalankan Skenario Uji Wajib
    if nargin < 1 || isempty(tone_sequence)
        run_mandatory_test();
        return;
    end

    % 1. Parameter Spesifik Utama
    Fs                 = 32000;         % Frekuensi Sampling 32000 Hz
    symbol_time        = 0.020;         % Durasi per nada: Tepat 20 ms
    samples_per_symbol = round(Fs * symbol_time);  % 640 sampel per simbol
    addr_bits          = 9;             % Lebar alamat ROM NCO (menyesuaikan hw)
    data_bits          = 16;            % Resolusi data
    rst                = false;

    % Pemrosesan Input Array/String
    tone_codes    = normalize_sequence(tone_sequence);
    num_symbols   = numel(tone_codes);
    total_samples = num_symbols * samples_per_symbol;

    % 2. Inisialisasi NCO State (Persisten antar iterasi simbol)
    % Struktur state (phase_acc, dll) digunakan untuk menjaga Sifat Transisi
    % agar bersambung mulus di perbatasan 20 ms tanpa zero-padding.
    state_low  = struct();
    state_high = struct();

    % Array pre-alokasi untuk output sinyal (int16 untuk mencerminkan VHDL Q3.13)
    dtmf_out = zeros(1, total_samples, 'int16');

    % 3. Pembangkitan Sinyal DTMF Kontinu per Simbol
    for i = 1:num_symbols
        idx_start = (i - 1) * samples_per_symbol + 1;
        idx_end   = idx_start + samples_per_symbol - 1;

        % Encoder frekuensi untuk Low Group dan High Group
        [phase_incr_low, phase_incr_high] = digit_encoder(tone_codes(i));

        % Generator gelombang sinus dengan LUT + NCO
        % state dilewatkan masuk dan keluar untuk menjamin fase berlanjut mulus
        [data_low,  state_low]  = sine_gen(phase_incr_low,  samples_per_symbol, addr_bits, data_bits, state_low,  rst);
        [data_high, state_high] = sine_gen(phase_incr_high, samples_per_symbol, addr_bits, data_bits, state_high, rst);

        % Penggabungan (Adder) - Menjumlahkan komponen frekuensi rendah dan tinggi
        sum_val = data_low + data_high;

        % Menyimpan nilai akhir ke dalam array keluaran utama
        dtmf_out(idx_start:idx_end) = sum_val;
    end

    % 4. Vektor Waktu untuk kebutuhan plotting
    t = (0:(total_samples - 1)) / Fs;

    % --- Logging Terminal ---
    print_summary(Fs, symbol_time, num_symbols, tone_codes);

    % Jika dipanggil tanpa variabel penampung output (opsional plot basic)
    if nargout == 0
        figure('Name', 'DTMF Output', 'NumberTitle', 'off');
        plot(t, double(dtmf_out)/8192, 'b');
        title('DTMF Output'); xlabel('Waktu (s)'); ylabel('Amplitudo (Skala Q3.13)'); grid on;
        clear dtmf_out t;
    end
end

% -------------------------------------------------------------------------
% Fungsi Bantuan: Cetak ringkasan parameter ke terminal
% -------------------------------------------------------------------------
function print_summary(Fs, symbol_time, num_symbols, tone_codes)
    sep = repmat('-', 1, 62);
    fprintf('\n%s\n', sep);
    fprintf('  DTMF Generator Summary\n');
    fprintf('  Fs = %d Hz | Duration = %d ms/symbol | Total = %d ms\n', ...
            Fs, symbol_time*1000, num_symbols*symbol_time*1000);
    fprintf('%s\n', sep);
    fprintf('  %-4s  %-12s  %-8s  %-10s  %-10s\n', ...
            'Seg', 'Time (ms)', 'Symbol', 'Low (Hz)', 'High (Hz)');
    fprintf('%s\n', sep);
    for i = 1:num_symbols
        [plo, phi] = digit_encoder(tone_codes(i));
        f_low  = round(double(plo)  * 32000 / 2^32);
        f_high = round(double(phi) * 32000 / 2^32);
        ch       = decode_symbol(tone_codes(i));   
        t_start  = (i-1) * symbol_time * 1000;
        t_end    =  i    * symbol_time * 1000;
        fprintf('  %-4d  %4.0f - %4.0f ms   %-8s  %-10d  %-10d\n', ...
                i, t_start, t_end, ch, f_low, f_high);
    end
    fprintf('%s\n\n', sep);
end

% -------------------------------------------------------------------------
% normalize_sequence: Mengonversi berbagai format input menjadi kode 0-15
% -------------------------------------------------------------------------
function tone_codes = normalize_sequence(tone_sequence)
    if isstring(tone_sequence) || ischar(tone_sequence)
        chars = char(tone_sequence);
        tone_codes = zeros(1, numel(chars));
        for k = 1:numel(chars)
            tone_codes(k) = encode_digit(chars(k));
        end
        return;
    end
    if isnumeric(tone_sequence)
        tone_codes = double(tone_sequence(:)).';
        if any(tone_codes < 0 | tone_codes > 15)
            error('Numeric tone_sequence harus memuat nilai valid antara 0 hingga 15.');
        end
        return;
    end
    error('tone_sequence harus berupa array karakter (string) atau array numerik (0-15).');
end

% -------------------------------------------------------------------------
% encode_digit : Mengonversi karakter simbol DTMF menjadi indeks numerik
% Matriks 16 simbol mencakup A, B, C, D (High Group 1633 Hz)
% -------------------------------------------------------------------------
function code = encode_digit(ch)
    switch upper(ch)
        case '1', code = 1;
        case '2', code = 2;
        case '3', code = 3;
        case 'A', code = 10;
        case '4', code = 4;
        case '5', code = 5;
        case '6', code = 6;
        case 'B', code = 11;
        case '7', code = 7;
        case '8', code = 8;
        case '9', code = 9;
        case 'C', code = 12;
        case '*', code = 14;
        case '0', code = 0;
        case '#', code = 15;
        case 'D', code = 13;
        otherwise, error('Karakter tidak didukung: ''%s''.', ch);
    end
end

% -------------------------------------------------------------------------
% digit_encoder : Mengembalikan phase increment (NCO) untuk frekuensi tertentu
% Matriks Frekuensi ITU-T 16 simbol dengan Fs = 32000 Hz.
% -------------------------------------------------------------------------
function [phase_incr_low, phase_incr_high] = digit_encoder(tone_code)
    switch tone_code
        case 1,  low_f = 697; high_f = 1209;
        case 2,  low_f = 697; high_f = 1336;
        case 3,  low_f = 697; high_f = 1477;
        case 10, low_f = 697; high_f = 1633;  % 'A'
        case 4,  low_f = 770; high_f = 1209;
        case 5,  low_f = 770; high_f = 1336;
        case 6,  low_f = 770; high_f = 1477;
        case 11, low_f = 770; high_f = 1633;  % 'B'
        case 7,  low_f = 852; high_f = 1209;
        case 8,  low_f = 852; high_f = 1336;
        case 9,  low_f = 852; high_f = 1477;
        case 12, low_f = 852; high_f = 1633;  % 'C'
        case 14, low_f = 941; high_f = 1209;  % '*'
        case 0,  low_f = 941; high_f = 1336;  % '0'
        case 15, low_f = 941; high_f = 1477;  % '#'
        case 13, low_f = 941; high_f = 1633;  % 'D'
        otherwise, low_f = 0; high_f = 0;
    end
    
    % Kalkulasi Increment Fase untuk ROM berukuran 32-bit (phase accumulator)
    phase_incr_low  = uint32(round(low_f  * 2^32 / 32000));
    phase_incr_high = uint32(round(high_f * 2^32 / 32000));
end

% -------------------------------------------------------------------------
% decode_symbol : Pemetaan balik dari indeks numerik ke karakter DTMF
% -------------------------------------------------------------------------
function ch = decode_symbol(tone_code)
    switch tone_code
        case 1,  ch = '1';
        case 2,  ch = '2';
        case 3,  ch = '3';
        case 10, ch = 'A';
        case 4,  ch = '4';
        case 5,  ch = '5';
        case 6,  ch = '6';
        case 11, ch = 'B';
        case 7,  ch = '7';
        case 8,  ch = '8';
        case 9,  ch = '9';
        case 12, ch = 'C';
        case 14, ch = '*';
        case 0,  ch = '0';
        case 15, ch = '#';
        case 13, ch = 'D';
        otherwise, ch = '?';
    end
end

% -------------------------------------------------------------------------
% Blok Skenario Uji Wajib (Dijalankan saat nargin == 0)
% -------------------------------------------------------------------------
function run_mandatory_test()
    % Sekuens Kasus Riil: 
    % Preamble (#, #, 3, #)
    % Payload 32-bit 0x3A7C9B1D (3, A, 7, C, 9, B, 1, D)
    test_sequence = ['#', '#', '3', '#', '3', 'A', '7', 'C', '9', 'B', '1', 'D'];
    
    fprintf('=== MENJALANKAN SKENARIO UJI WAJIB ===\n');
    fprintf('Sekuens: %s\n', test_sequence);
    
    % Pemanggilan fungsi utama
    [sig, t] = generate_dtmf(test_sequence);
    
    % Visualisasi
    figure('Name', 'Validasi Transisi DTMF Tanpa Silence Gap', 'NumberTitle', 'off', 'Position', [100 100 1000 700]);
    
    % Plot 1: Sinyal Keseluruhan
    % subplot(2,1,1);
    plot(t, double(sig)/8192, 'b'); % Skala dinormalisasi (Q3.13)
    title('Sinyal DTMF Lengkap (Preamble + Payload)');
    xlabel('Waktu (s)');
    ylabel('Amplitudo ternormalisasi');
    grid on;
    hold on;
    symbol_time = 0.020;
    
    % Garis batas antar simbol
    for k = 1:numel(test_sequence)
        xline(k * symbol_time, 'r--', 'LineWidth', 1.0);
        t_mid = (k - 0.5) * symbol_time;
        text(t_mid, max(double(sig)/8192)*1.1, test_sequence(k), 'HorizontalAlignment', 'center', ...
             'FontSize', 11, 'FontWeight', 'bold', 'Color', 'r', 'BackgroundColor', 'w');
    end
    ylim([-2.5 2.5]);
    hold off;
    
    % % Plot 2: Zoom di Transisi Simbol 1 dan 2 (t = 20 ms)
    % % (Bagian ini dikomentari sesuai permintaan)
    % subplot(2,1,2);
    % plot(t, double(sig)/8192, 'b.-', 'MarkerSize', 8);
    % title('Validasi Ketiadaan Jeda Sunyi (Zoom Perbatasan Simbol 1 dan 2 pada t = 20 ms)');
    % xlabel('Waktu (s)');
    % ylabel('Amplitudo');
    % grid on;
    % hold on;
    % 
    % % Fokuskan xlim pada rentang +/- 1 ms dari batas 20 ms (t=0.020s)
    % t_center = symbol_time;
    % xlim([t_center - 0.001, t_center + 0.001]);
    % 
    % xline(t_center, 'r-', 'LineWidth', 2.0);
    % text(t_center, 1.5, ' Transisi Simbol 1 (#) \rightarrow Simbol 2 (#)', ...
    %      'Color', 'r', 'FontSize', 10, 'BackgroundColor', 'w', 'VerticalAlignment', 'bottom');
    % hold off;
    
    fprintf('Pengujian selesai. Grafik validasi telah ditampilkan.\n');
end
