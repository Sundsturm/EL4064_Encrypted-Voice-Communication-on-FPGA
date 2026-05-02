function [sync_idx, max_value, detect_enable] = precision(score_mark, flag_idx, Fs)

    detect_enable = 0;
    max_value = 0;
    sync_idx = 0;

    if isempty(flag_idx)
        fprintf('Flag belum terdeteksi, tidak bisa mencari sync point.\n');
        return;
    end

    % Tentukan window pencarian setelah flag (misalnya 50 ms)
    search_len = round(0.05 * Fs); % 50 ms
    search_end = min(flag_idx + search_len, length(score_mark));

    search_range = flag_idx : search_end;

    % Cari peak lokal dalam window ini
    [max_value, rel_idx] = max(score_mark(search_range));
    sync_idx = search_range(rel_idx);

    fprintf('Sync point ditemukan di sample ke-%d\n', sync_idx);
    fprintf('Nilai korelasi maksimum (mark) sebesar %.4f\n', max_value);

    detect_enable = 1;
end