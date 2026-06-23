function [dtmf3_idx, mark_valid, goertzel_enable] = marking(batch_sums, flag_start_idx)
% MARKING  Mark detection module untuk DTMF "3" (697 Hz)
%
%   Sesuai skema (diperluas): setelah flag '#' terdeteksi (flag_start_idx),
%   scan dimulai dari batch berikutnya. Dua kondisi sekuensial:
%       (1) "Apakah nilai batch 697 Hz ini lebih besar dari sebelumnya?"
%       (2) "Apakah 697 Hz DAN 1477 Hz lebih tinggi dari 941 Hz?"
%   Jika keduanya Ya → goertzel_enable = 1.
%
%   Input:
%       batch_sums    : hasil sliding window [N x 3], kolom 1=697, 2=941, 3=1477
%       flag_start_idx: indeks batch awal flag '#' dari flagging()
%
%   Output:
%       dtmf3_idx      : batch index saat "3" terdeteksi (-1 jika tidak)
%       mark_valid     : 1 jika "3" terdeteksi, 0 jika tidak
%       goertzel_enable: sama dengan mark_valid

    dtmf3_idx      = -1;
    mark_valid     = 0;
    goertzel_enable = 0;

    % Titik awal scan: satu batch setelah flag '#' dikonfirmasi
    scan_start = flag_start_idx + 1;
    if scan_start < 2
        scan_start = 2;
    end

    bs = double(batch_sums);

    for idx = scan_start:size(bs, 1)

        curr_697  = bs(idx,   1);  % 697 Hz saat ini
        prev_697  = bs(idx-1, 1);  % 697 Hz sebelumnya
        curr_941  = bs(idx,   2);  % 941 Hz saat ini
        curr_1477 = bs(idx,   3);  % 1477 Hz saat ini

        % KONDISI 1: apakah nilai batch 697 Hz ini lebih besar dari sebelumnya?
        if curr_697 > prev_697

            % KONDISI 2 (guard): apakah 697 Hz DAN 1477 Hz lebih tinggi dari 941 Hz?
            if curr_697 > curr_941 && curr_1477 > curr_941
                dtmf3_idx      = idx;
                mark_valid     = 1;
                goertzel_enable = 1;

                fprintf('Mark "3" terdeteksi pada batch ke-%d\n', dtmf3_idx);
                fprintf('  697 Hz  = %.3f (naik dari %.3f)\n', curr_697, prev_697);
                fprintf('  941 Hz  = %.3f\n', curr_941);
                fprintf('  1477 Hz = %.3f\n', curr_1477);

                break;
            end

        end

    end

end
