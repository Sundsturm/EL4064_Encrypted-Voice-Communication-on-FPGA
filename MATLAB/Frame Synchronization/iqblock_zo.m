    clear all; close all;
    
    % Parameter dasar
    Fs = 32000;              % Frekuensi sampling
    duration = 0.02;         % Durasi sinyal dalam detik
    N = Fs * duration;       % Jumlah sampel: 320 sampel
    t = (0:N - 1) / Fs;      % Vektor waktu
    
    % Tabel Lookup Frekuensi DTMF
    dtmf_matrix = [697 941; 1477 0];        % Matriks frekuensi DTMF
    dtmf_row = containers.Map({'3', '#'}, ... % Map untuk baris DTMF
                              {1, 2});
    dtmf_col = containers.Map({'3', '#'}, ... % Map untuk kolom DTMF
                              {1, 1});
    
    % Pembuatan sinyal nada DTMF
    tones = [
        sin(2 * pi * dtmf_matrix(1, dtmf_row('3')) * t) + ...   % Nada untuk simbol '3'
        sin(2 * pi * dtmf_matrix(2, dtmf_col('3')) * t);
        
        sin(2 * pi * dtmf_matrix(1, dtmf_row('#')) * t) + ...   % Nada untuk simbol '#'
        sin(2 * pi * dtmf_matrix(2, dtmf_col('#')) * t);
        ];
    
    % Nama nada yang digunakan (frekuensi)
    tone_names = [
        '697 + 1477',    % Nada kombinasi frekuensi untuk simbol '3'
        '941 + 1477'     % Nada kombinasi frekuensi untuk simbol '#'
        ];
    
    % Daftar frekuensi DTMF yang akan dianalisis
    dtmf_freqs = [697 941 1477];
    
    % Pembuatan sinyal input dengan noise dan dua simbol DTMF
    inputsignal = [(4*rand(1, 1280))-2, ...   % Noise awal
                   tones(2, :), ...          % Nada '#'
                   tones(2, :), ...          % Nada '#'
                   tones(1, :), ...          % Nada '3'
                   tones(2, :), ...          % Nada '#'
                   4*(rand(1, 1280))-2];      % Noise akhir
    
    inputsignal_name = 'Sinyal # dan 3, noise L+R';  % Nama sinyal input
    
    % Hitung total sampel dalam sinyal input
    N_total = length(inputsignal);
    
    % Pengaturan parameter frame
    frame_size = 32;                         % Ukuran frame 64 sampel
    num_frames = floor(N_total / frame_size); % Jumlah frame yang akan diproses
    batch_size = 20;                                        % Ukuran batch: 1/5 dari total frame
    sliding_window_size = num_frames - batch_size + 1;      % Ukuran sliding window
    
    % Matriks untuk menyimpan hasil akumulasi korelasi
    frame_sums = zeros(num_frames, length(dtmf_freqs));
    
    % Loop untuk menghitung akumulasi magnituda korelasi pada setiap frame
    for frame_i = 1:num_frames
        frame_start = (frame_i - 1) * frame_size + 1;
        frame_end = frame_i * frame_size;
        input_frame = inputsignal(frame_start:frame_end); % Ekstrak sinyal pada frame
    
        for ref_i = 1:length(dtmf_freqs)
            % Hitung korelasi pada frame ini untuk frekuensi referensi
            frame_sums(frame_i, ref_i) = sum(iq_corr(input_frame, dtmf_freqs(ref_i), Fs)); % Simpan hasil korelasi
        end
    end
    
    % Inisialisasi matriks untuk menyimpan hasil akumulasi korelasi pada batch
    batch_sums = zeros(sliding_window_size, length(dtmf_freqs));
    
    % Loop untuk menghitung akumulasi magnituda korelasi pada setiap batch
    for slide_i = 1:sliding_window_size
        for ref_i = 1:length(dtmf_freqs)
            % Hitung jumlah korelasi dalam satu batch
            batch_sums(slide_i, ref_i) = sum(frame_sums(slide_i:slide_i + batch_size - 1, ref_i));
        end
    end
    
    % Inisialisasi deteksi block presisi
    precision_enable = 0;
    detect_enable = 0;
    count = 0;
    
    % Mencari Sinyal Flag
    for slide_i = 25:sliding_window_size
        % Cek apakah nilai batch sama dengan batch sebelumnya
        if batch_sums(slide_i, 3) >= 6*batch_sums(slide_i - 24, 3)
            count = count + 1;
            if count == 5
                precision_enable = 1;
                fprintf('Sinyal Flag dimulai pada batch ke-%d\n', slide_i-4);
                fprintf('Nilai korelasinya sebesar %d\n', batch_sums(slide_i,3));
                break;
            end
        else
            count = 0; % Reset jika tidak sama
        end
    end
    
    % Proses setelah precision_enable aktif
    if precision_enable
        % Cari nilai tertinggi pada frekuensi 697 Hz
        [~, max_idx] = max(batch_sums(:, 1));
        fprintf('Nilai korelasi maksimum pada frekuensi 697 Hz ditemukan di batch ke-%d\n', max_idx);
        fprintf('Nilai korelasinya sebesar %d\n', batch_sums(max_idx,1));
        detect_enable = 1;
    end
    
    if detect_enable
        fprintf('Deteksi selesai dengan mark_enable = 1 dan goertzel_enable = 1.\n');
    end
    
    % Tampilkan hasil akumulasi batch dalam bentuk teks
    for ref_i = 1:length(dtmf_freqs)
        fprintf('Nilai akumulasi korelasi pada frekuensi %d Hz:\n', dtmf_freqs(ref_i));
        for slide_i = 1:sliding_window_size
            fprintf('Batch ke-%d: %.2f\n', slide_i, batch_sums(slide_i, ref_i));
        end
        fprintf('\n');
    end
    
    % Plot grafik per frame dan per batch dalam satu tampilan
    figure;
    
    % Subplot 1: Grafik per frame
    subplot(2, 1, 1);
    hold on;
    for ref_i = 1:length(dtmf_freqs)
        plot(1:num_frames, frame_sums(:, ref_i), 'DisplayName', ['Frekuensi ', num2str(dtmf_freqs(ref_i)), ' Hz']);
    end
    hold off;
    xlabel('Frame ke-');                    % Label sumbu x
    xlim([1 num_frames]);                   % Sesuaikan skala sumbu x sesuai jumlah frame
    ylabel('Akumulasi Magnituda Korelasi');
    title('Grafik Garis Akumulasi Korelasi per Frame');
    legend show;
    
    % Subplot 2: Grafik per batch
    subplot(2, 1, 2);
    hold on;
    for ref_i = 1:length(dtmf_freqs)
        plot(1:sliding_window_size, batch_sums(:, ref_i), 'DisplayName', ['Frekuensi ', num2str(dtmf_freqs(ref_i)), ' Hz']);
    end
    hold off;
    xlabel('Batch ke-');
    xlim([1 sliding_window_size]);          % Sesuaikan skala sumbu x sesuai ukuran sliding window
    ylabel('Akumulasi Magnituda Korelasi');
    title('Grafik Garis Akumulasi Korelasi per Batch');
    legend show;
    
    % Fungsi iq_corr untuk menghitung korelasi IQ per frame
    function IQmag = iq_corr(input_tone, ref_freq, Fs)
        N = length(input_tone);
        t = (0:N - 1)/Fs;
    
        % Komponen in-phase (I) dan quadrature (Q) dari referensi frekuensi
        ref_sin = sin(2 * pi * ref_freq * t);
        ref_cos = cos(2 * pi * ref_freq * t);
        
        % Hitung magnituda korelasi IQ dengan menjumlahkan hasil perkalian sinyal
        IQmag = sum(input_tone .* ref_cos)^2 + sum(input_tone .* ref_sin)^2;
    end
