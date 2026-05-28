function [sync_lock_index, batch_sums] = dtmf_iq_demodulator(sinyal_input, Fs)
%DTMF_IQ_DEMODULATOR Demodulator IQ Kuadratur & Deteksi Preamble Kontinu
%   [sync_lock_index, batch_sums] = dtmf_iq_demodulator(sinyal_input, Fs)
%
%   Memanfaatkan lingkungan simulasi 'exp 1.7 fixed point v4' karya Kean
%   untuk melakukan demodulasi sinyal dengan arsitektur RTL.
%
%   Input:
%       sinyal_input - Sinyal audio 1D (domain waktu)
%       Fs           - Frekuensi sampling (default 32000)
%   Output:
%       sync_lock_index - Titik T=0 untuk payload (akhir preamble '# # 3 #')
%       batch_sums      - Array energi (Sliding Window Output) untuk visualisasi

    if nargin < 2
        Fs = 32000;
    end

    % 1. Tambahkan path lingkungan simulasi fixed-point Kean
    % Pastikan path ini benar berdasarkan lokasi file
    kean_path = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'Frame Synchronization', 'exp 1.7 fixed point v4');
    addpath(kean_path);

    % Global setup of fixed-point simulation (dari main.m Kean)
    F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');
    
    % Konversi sinyal input ke fixed-point Q3.13 (sesuai spesifikasi Kean/RTL)
    % Perhatian: sinyal_input direpresentasikan dalam int16 (amplitudo puncak 32766).
    % Kita mendivisinya dengan 65536 agar amplitudo menjadi ~0.5. 
    % Ini mencegah saturasi pada akumulator sliding window Kean.
    input_fi = fi(double(sinyal_input) / 65536, 1, 16, 13, 'fimath', F);

    % Parameter arsitektur IQ RTL
    frame_size = 40;  % Accumulator framing size (1.25 ms)
    batch_size = 16;  % Sliding window size (16 * 1.25 = 20 ms / 1 Simbol)
    
    % Bangkitkan LUT Sinus & Kosinus dari lingkungan Kean
    [refsin_697, refcos_697] = lut_697();
    [refsin_941, refcos_941] = lut_941();
    [refsin_1477, refcos_1477] = lut_1477();
    
    refsins = [refsin_697; refsin_941; refsin_1477];
    refcosines = [refcos_697; refcos_941; refcos_1477];

    % 2. Proses Demodulasi IQ (Sesuai Pipeline RTL toplevel_iq.vhd)
    % Tahap 1: IQ Mixing (Perkalian sinyal dengan carrier lokal)
    mult_sinsignal = sin_mult(input_fi, refsins);
    mult_cossignal = cosines_mult(input_fi, refcosines);

    % Tahap 2: Accumulator (Integrate & Dump - LPF)
    [acc_sinsignal, acc_cossignal] = accu(mult_sinsignal, mult_cossignal, frame_size);

    % Tahap 3: Power Calculation (I^2 + Q^2)
    total_power = total_calc(acc_sinsignal, acc_cossignal);

    % Tahap 4: Sliding Window Batch Summation (Moving Average energi selama 1 simbol)
    batch_sums_fi = sliding(total_power, batch_size);
    batch_sums = double(batch_sums_fi); % Convert ke double untuk kemudahan pelacakan indeks di MATLAB

    % 3. Deteksi Preamble & Sinkronisasi (RTL-Style Peak Tracking)
    % Mengadaptasi algoritma `markingv1.vhd` yang menghitung 'drop counter'
    % untuk menghindari deteksi palsu akibat ripple (riak) sinyal.
    
    state = 0;
    sync_batch_idx = 0;
    
    % Threshold dinamis berdasarkan energi maksimum
    % Dinaikkan ke 0.8 untuk menghindari "False Peak" akibat CROSSTALK yang sangat tinggi (~70%)
    thresh_941 = max(batch_sums(:, 2)) * 0.8;
    thresh_697 = max(batch_sums(:, 1)) * 0.8;
    
    max_697 = 0;
    peak_697_idx = 0;
    drop_count_697 = 0;
    
    max_941_local = 0;
    peak_941_idx = 0;
    drop_count_941 = 0;
    
    DROP_THRESHOLD = 8; % 8 batch = 10 ms waktu jatuh konsisten
    
    for i = 1:size(batch_sums, 1)
        pow_697 = batch_sums(i, 1);
        pow_941 = batch_sums(i, 2);
        
        switch state
            case 0 % Wait for first '#' plateau
                if pow_941 > thresh_941
                    state = 1;
                end
                
            case 1 % Track '3' peak
                if pow_697 > max_697
                    max_697 = pow_697;
                    peak_697_idx = i;
                    drop_count_697 = 0;
                else
                    drop_count_697 = drop_count_697 + 1;
                end
                
                % Jika energi sudah konsisten turun (melewati puncak)
                if drop_count_697 >= DROP_THRESHOLD && max_697 > thresh_697
                    state = 2;
                end
                
            case 2 % Track 4th '#' peak
                if pow_941 > max_941_local
                    max_941_local = pow_941;
                    peak_941_idx = i;
                    drop_count_941 = 0;
                else
                    drop_count_941 = drop_count_941 + 1;
                end
                
                % Jika energi sudah konsisten turun (melewati puncak '#' ke-4)
                if drop_count_941 >= DROP_THRESHOLD && max_941_local > thresh_941
                    sync_batch_idx = peak_941_idx;
                    break;
                end
        end
    end
    
    if sync_batch_idx == 0
        warning('Gagal mengunci pola Preamble secara penuh. Menggunakan indeks paksa.');
        sync_batch_idx = 1;
    end
    
    % 4. Konversi ke Indeks Sampel Aktual
    % Karena 1 frame (batch) memproses 'frame_size' sampel (40), indeks sampel adalah:
    sync_lock_index = sync_batch_idx * frame_size;
    
    fprintf('=== HASIL DEMODULASI IQ & SINKRONISASI ===\n');
    fprintf('Puncak Simbol ''3'' (697 Hz) ditemukan pada batch %d.\n', peak_697_idx);
    fprintf('Puncak Simbol ''#'' ke-4 (941 Hz) divalidasi pada batch %d.\n', sync_batch_idx);
    fprintf('-> SYNC LOCK INDEX ditetapkan di sampel ke-%d (Titik T=0 Payload)\n', sync_lock_index);
end
