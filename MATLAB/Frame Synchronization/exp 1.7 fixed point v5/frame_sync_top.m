function [sync_lock_index, batch_sums] = frame_sync_top(sinyal_input, Fs)
%FRAME_SYNC_TOP Wrapper Sinkronisasi Bingkai (Kean v5)
%   Menerapkan logika murni dari v5/main.m milik Kean.
%
%   Input:
%       sinyal_input - Sinyal masukan
%       Fs           - Frekuensi sampling
%   Output:
%       sync_lock_index - Indeks mulai payload
%       batch_sums      - Hasil perhitungan energi tiap batch

    if nargin < 2
        Fs = 32000;
    end

    % Global setup of fixed-point simulation
    F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');
    
    % Konversi sinyal input ke fixed-point Q3.13
    input_fi = fi(double(sinyal_input) / 65536, 1, 16, 13, 'fimath', F);

    frame_size = 40;
    batch_size = 16;
    
    % Generate lookup table for reference sines and cosines
    [refsin_697, refcos_697] = lut_697();
    [refsin_941, refcos_941] = lut_941();
    [refsin_1477, refcos_1477] = lut_1477();
    
    refsins = [refsin_697; refsin_941; refsin_1477];
    refcosines = [refcos_697; refcos_941; refcos_1477];

    % Step 1: Multiply input signal with reference sine and cosine
    mult_sinsignal = sin_mult(input_fi, refsins);
    mult_cossignal = cosines_mult(input_fi, refcosines);

    % Step 2: Accumulate data for framing
    [acc_sinsignal, acc_cossignal] = accu(mult_sinsignal, mult_cossignal, frame_size);

    % Step 3: Calculate total power from sin and cos accumulations
    total_power = total_calc(acc_sinsignal, acc_cossignal);

    % Step 4: Perform sliding window batch summation
    batch_sums_fi = sliding(total_power, batch_size);
    batch_sums = double(batch_sums_fi);

    % Step 5: Flagging for specific DTMF frequencies [941 Hz and 1477 Hz]
    [~, ~, precision_enable, flag_start_idx] = flagging(batch_sums_fi);

    % Step 6: Mark detection — DTMF "3" (697 Hz)
    dtmf3_idx = -1;
    if precision_enable
        [dtmf3_idx, ~, ~] = marking(batch_sums_fi, flag_start_idx);
    end

    if dtmf3_idx > 0
        % Hitung titik sinkronisasi: 
        % Karena Kean mendeteksi transisi simbol # ke 3,
        % masih tersisa simbol '3' (16 batch) dan '#' (16 batch).
        % Maka T=0 Payload adalah 32 batch setelahnya.
        sync_batch = dtmf3_idx + 32;
        sync_lock_index = sync_batch * frame_size;
        
        fprintf('=== HASIL SINKRONISASI BINGKAI (KEAN v5) ===\n');
        fprintf('Flag # ditemukan mulai batch %d\n', flag_start_idx);
        fprintf('Puncak 3 terdeteksi pada batch %d\n', dtmf3_idx);
        fprintf('-> SYNC LOCK INDEX ditetapkan di sampel ke-%d\n', sync_lock_index);
    else
        warning('Gagal mengunci pola Preamble secara penuh. Menggunakan indeks paksa.');
        sync_lock_index = 0;
    end
end
