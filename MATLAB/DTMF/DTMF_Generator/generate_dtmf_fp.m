function signal = generate_dtmf(key_24bit)
% GENERATE_DTMF Membangkitkan sinyal kontinu DTMF 8-segmen dari kunci 24-bit
% Target : 32 kHz Sampling Rate, 20 ms (640 sampel) per Nada
% Continuous Transmission (Tanpa Jeda)

    % 1. Parameter Dasar Sistem
    Fs = 32000;          % Frekuensi sampling 32 kHz
    t_dur = 0.02;        % Durasi tepat 20 ms per frame
    N = Fs * t_dur;      % Tepat 640 sampel per nada
    t = (0 : N - 1) / Fs; % Vektor waktu untuk 1 segmen (640 sampel)

    % 2. Operasi sinusoidal untuk pembangkitan 640 sampel tiap segmen
    gen_dtmf = @(f_low, f_high) ...
        0.5 * sin(2 * pi * f_low * t) + ...
        0.5 * sin(2 * pi * f_high * t);

    % 3. Tabel Pemetaan 3-bit ke Nada DTMF (Berdasarkan decision.vhd)
    % 000=1, 001=2, 010=4, 011=5, 100=7, 101=8, 110=*, 111=0
    freq_map = [
        697, 1209; % 000:'1'
        697, 1336; % 001:'2'
        770, 1209; % 010:'4'
        770, 1336; % 011:'5'
        852, 1209; % 100:'7'
        852, 1336; % 101:'8'
        941, 1209; % 110:'*'
        941, 1336  % 111:'0'
    ];

    % 4. Inisialisasi array keluaran akhir kontinu
    signal = [];

    % 5. Kunci 24-bit dipecah menjadi 8 segmen (masing-masing 3 bit)
    % Ekstraksi 8 segmen berurutan secara looping (MSB ke LSB)
    for i = 7:-1:0
        % Ekstrak 3-bit segment menggunakan bitshift dan bitand
        segment_val = bitand(bitshift(uint32(key_24bit), -i*3), 7);

        % Pemetaan ke frekuensi
        f_low = freq_map(segment_val + 1, 1);
        f_high = freq_map(segment_val + 1, 2);

        % Bangkitkan 640 sampel
        segment_signal = gen_dtmf(f_low, f_high);
        
        % --- Log Keluaran ---
        fprintf('\n  -> [Generator] Segmen %d (3-bit: %d, Low: %d Hz, High: %d Hz) dibangkitkan.\n', 8-i, segment_val, f_low, f_high);
        disp('  Isi payload_signal (640 sampel):');
        disp(segment_signal);

        % Gabungkan array sinyal 1D kontinu hasil ke-8 segmen
        signal = [signal, segment_signal];
    end
end