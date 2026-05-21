function [power_low, power_high] = goertzel_detector(chunk, Fs)
% GOERTZEL_DETECTOR Ekivalen MATLAB dari Goertzel.vhd
% Menerima 1 chunk sinyal dan frekuensi sampling, lalu menghitung
% spektrum frekuensi diskrit (daya) untuk frekuensi DTMF target.

    % 7 Target Frekuensi DTMF
    f_low_targets = [697, 770, 852, 941];
    f_high_targets = [1209, 1336, 1477];
    
    N = length(chunk);
    
    % Perhitungan indeks array (bin) DFT untuk fungsi goertzel()
    indices_low = round((f_low_targets * N) / Fs) + 1;
    indices_high = round((f_high_targets * N) / Fs) + 1;
    
    % Hitung Power (Daya) menggunakan fungsi goertzel MATLAB
    dft_low = goertzel(chunk, indices_low);
    power_low = abs(dft_low).^2;
    
    dft_high = goertzel(chunk, indices_high);
    power_high = abs(dft_high).^2;
    
    % --- Log Keluaran ---
    disp('  -> [Goertzel Detector] Power Low Group  :');
    disp(power_low);
    disp('  -> [Goertzel Detector] Power High Group :');
    disp(power_high);
end
