function [f_low_detected, f_high_detected] = comparator(power_low, power_high)
% GOERTZEL_COMPARATOR Ekivalen MATLAB dari komponen comparator.vhd
% Menerima array daya dari modul goertzel dan mencari indeks dengan nilai
% maksimal untuk menentukan frekuensi dominan.

    % 7 Target Frekuensi DTMF
    f_low_targets = [697, 770, 852, 941];
    f_high_targets = [1209, 1336, 1477];
    
    % Cari indeks dengan daya tertinggi di masing-masing grup
    [~, max_idx_low] = max(power_low);
    [~, max_idx_high] = max(power_high);
    
    % Output frekuensi dominan yang terdeteksi
    f_low_detected = f_low_targets(max_idx_low);
    f_high_detected = f_high_targets(max_idx_high);
    
    % --- Log Keluaran ---
    fprintf('  -> [Comparator] Frekuensi Dominan : Low = %d Hz, High = %d Hz\n', f_low_detected, f_high_detected);
end
