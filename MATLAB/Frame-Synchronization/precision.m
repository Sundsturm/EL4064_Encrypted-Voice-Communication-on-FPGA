function [max_idx, max_value, detect_enable] = precision(batch_sums)

    detect_enable = 0;
    max_idx = 0;
    max_value = 0;

    for idx = 2:size(batch_sums,1)

        curr = batch_sums(idx,1);      % 697 Hz
        prev = batch_sums(idx-1,1);

        % CONDITION: current > previous
        if curr > prev
            detect_enable = 1;
            max_idx = idx;
            max_value = curr;

            fprintf('Deteksi "3" pada batch ke-%d\n', idx);
            fprintf('Nilai korelasi 697 Hz = %.3f\n', curr);

            break;
        end

    end

end