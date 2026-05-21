% =========================================================================
% Script Penguji (Testbench) Detektor MATLAB Golden Model
% =========================================================================

disp('======================================================');
disp('Menjalankan Testbench Sistem Pengiriman Sekuens DTMF Satu Arah');

% 1. Pembangkitan Sinyal
Fs = 32000;
original_key = uint32(hex2dec('A5B6C7')); % Contoh Kunci 24-bit

disp(['Kunci Asli (Hex)       : ', dec2hex(original_key, 6)]);

% Panggil fungsi dari `generate_dtmf.m` untuk mendapatkan 5120 sampel sinyal
try
    input_signal = generate_dtmf(original_key);
catch
    error('Gagal memanggil generate_dtmf!');
end

% Plotting Sinyal 5120 Sampel di Time Domain
N_total = length(input_signal);
t_total = (0 : N_total - 1) / Fs;

figure;
plot(t_total, input_signal);
title('Sinyal Payload DTMF 24-bit');
xlabel('Waktu (detik)');
ylabel('Amplitudo');
grid on;

% Menambahkan penanda batas tiap segmen 20 ms (untuk verifikasi persambungan)
hold on;
for i = 1 : 7
    xline(i * 0.02, 'r--', 'LineWidth', 1.5, ...
        'Label', sprintf('Segmen %d', i + 1), ...
        'LabelVerticalAlignment', 'bottom');
end
hold off;
% 2. Proses Deteksi dan Rekonstruksi Kunci
reconstructed_key = reconstruct_key(input_signal);
disp(['Kunci Rekonstruksi (Hex): ', dec2hex(reconstructed_key, 6)]);

% 3. Verifikasi
disp('------------------------------------------------------');
if original_key == reconstructed_key
    disp('Verifikasi SUKSES: Kunci berhasil direkonstruksi 100%!');
else
    disp('Verifikasi GAGAL : Kunci hasil rekonstruksi tidak cocok dengan aslinya.');
end
disp('======================================================');
