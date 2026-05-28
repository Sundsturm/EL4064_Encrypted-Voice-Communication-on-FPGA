function [reconstructed_key, sync_lock_index, batch_sums] = dtmf_receiver_top(sinyal_input)
%DTMF_RECEIVER_TOP Sisi Penerima (RX) Lengkap untuk Voice-Band Modem
%   [reconstructed_key, sync_lock_index, batch_sums] = dtmf_receiver_top(sinyal_input)
%
%   Memodelkan alur komprehensif Sisi Penerima:
%   1. Preamble Detection (Sinkronisasi Bingkai) menggunakan Demodulator IQ
%      (Mengadaptasi skrip fixed-point Kean) untuk menemukan titik T=0.
%   2. Dekode Payload Data menggunakan algoritma Goertzel per simbol.
%
%   Input:
%       sinyal_input - Sinyal audio termodulasi 1D dari Generator
%   Output:
%       reconstructed_key - Data 32-bit hasil dekode dari Payload
%       sync_lock_index   - Indeks sampel presisi pembatas Preamble dan Payload
%       batch_sums        - Array energi dari IQ Demodulator (untuk visualisasi)

    Fs = 32000;
    N = 640; % Durasi per simbol (20 ms)

    % 1. Fase Demodulator IQ Kuadratur untuk Sinkronisasi Preamble
    fprintf('\n--- TAHAP 1: DETEKSI PREAMBLE & SINKRONISASI BINGKAI ---\n');
    
    % Tambahkan path ke modul Sinkronisasi Bingkai v5 Kean
    v5_path = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'Frame Synchronization', 'exp 1.7 fixed point v5');
    addpath(v5_path);
    
    [sync_lock_index, batch_sums] = frame_sync_top(sinyal_input, Fs);
    
    % Periksa apakah sinyal setelah sync_lock_index cukup untuk 8 simbol Payload
    if length(sinyal_input) < sync_lock_index + (8 * N)
        error('Panjang sinyal input setelah preamble tidak mencukupi untuk Payload (8 Simbol).');
    end

    % Potong sinyal (Slice) dari indeks sinkronisasi sebagai Payload T=0
    payload_signal = sinyal_input(sync_lock_index + 1 : end);

    % 2. Fase Dekode Payload menggunakan Detektor Goertzel
    fprintf('\n--- TAHAP 2: DEKODE PAYLOAD DATA (8 SIMBOL) ---\n');
    reconstructed_key = uint32(0);
    shift_state = struct();

    for i = 1:8
        fprintf('\n>> Memproses Segmen Payload %d/8...\n', i);
        idx_start = (i - 1) * N + 1;
        idx_end = i * N;
        chunk = payload_signal(idx_start:idx_end);

        % Goertzel Detector memproses 640 sampel blok demi blok
        [power_low, power_high] = goertzel_detector(chunk, Fs);
        
        % Menentukan frekuensi tertinggi pada Low Group dan High Group
        [code_low, code_high] = comparator(power_low, power_high);
        
        % Keputusan karakter DTMF (0-15)
        dtmf_code = decision(code_low, code_high);

        % Register Geser untuk menggabungkan 8 * 4-bit menjadi 32-bit (uint32)
        [output_key, shift_state, out_valid] = shift_add(shift_state, dtmf_code, true, true);
        fprintf('  -> [Decision] Simbol DTMF Code: 0x%X\n', dtmf_code);

        if out_valid
            reconstructed_key = output_key;
        end
    end
    
    fprintf('\nDekode Selesai. Reconstructed Key = 0x%08X\n\n', reconstructed_key);
end
