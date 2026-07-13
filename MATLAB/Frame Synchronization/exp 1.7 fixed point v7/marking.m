function [dtmf3_idx, mark_valid, goertzel_enable] = marking(batch_sums, flag_start_idx)
% MARKING  Mark detection module untuk DTMF "3" (697 Hz)
%
%   Sesuai dengan markingv1.vhd hasil pembaruan Opsi A.
%   Menggunakan Normalized Power Difference pada gabungan daya (697 Hz dan 941 Hz).

    % Parameter threshold rasio internal (alpha)
    threshold_coeff = 0.55; 

    dtmf3_idx       = -1;
    mark_valid      = 0;
    goertzel_enable = 0;

    if flag_start_idx < 1
        return;
    end

    % Titik awal scan: satu batch setelah flag '#' dikonfirmasi
    scan_start = flag_start_idx + 1;
    N = size(batch_sums, 1);
    if scan_start > N
        return;
    end

    bs = double(batch_sums);
    enable_i = 0;

    for idx = scan_start:N
        curr_697 = bs(idx, 1);
        curr_941 = bs(idx, 2);

        % Hitung total daya gabungan penanda low group
        total_power = curr_697 + curr_941;

        % Logika deteksi Opsi A (perkalian silang ekuivalen untuk menghindari division)
        fprintf('idx=%d: curr_697=%.1f, curr_941=%.1f, total_power=%.1f, ratio=%.3f (threshold=%.2f)\n', ...
            idx, curr_697, curr_941, total_power, curr_697 / max(1, total_power), threshold_coeff);

        if curr_697 >= threshold_coeff * total_power
            enable_i = 1;
        end

        % Jika terpicu, simpan indeks deteksi dan hentikan pencarian
        if enable_i == 1
            dtmf3_idx       = idx;
            mark_valid      = 1;
            goertzel_enable = 1;

            fprintf('Mark "3" terdeteksi pada batch ke-%d (Normalized Power Difference)\n', dtmf3_idx);
            fprintf('  curr_697    = %.3f\n', curr_697);
            fprintf('  curr_941    = %.3f\n', curr_941);
            fprintf('  total_power = %.3f\n', total_power);
            fprintf('  ratio       = %.3f\n', curr_697 / total_power);
            break;
        end
    end
end
