function batch_sums = sliding(total_power, batch_size)
    % Fixed-point config for Q15.1 (16-bit)
    F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');
    sliding_window_size = size(total_power, 2) - batch_size + 1;
    batch_sums = fi(zeros(sliding_window_size, size(total_power, 1)), ...
        1, 16, 1, 'fimath', F);

    for slide_i = 1:sliding_window_size
        for ref_i = 1:size(total_power, 1)
            % Initiation
            acc_batch = fi(0, 1, 16, 2, 'fimath', F);
            start_idx = slide_i;
            end_idx   = slide_i + batch_size - 1;
            
            for k = start_idx:end_idx
                temp = acc_batch + total_power(ref_i, k); % Addition
                acc_batch = fi(temp, 1, 16, 2, 'fimath', F); % Truncation to Q14.2
            end
            
            batch_sums(slide_i, ref_i) = acc_batch;
        end
    end
end
