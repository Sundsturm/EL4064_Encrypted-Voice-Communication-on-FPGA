function batch_sums = sliding(total_power, batch_size)
    sliding_window_size = size(total_power, 2) - batch_size + 1;
    batch_sums = zeros(sliding_window_size, size(total_power, 1));

    for slide_i = 1:sliding_window_size
        for ref_i = 1:size(total_power, 1)
            start_idx = slide_i;
            end_idx = min(slide_i + batch_size - 1, size(total_power, 2));
            batch_sums(slide_i, ref_i) = sum(total_power(ref_i, start_idx:end_idx));
        end
    end
end
