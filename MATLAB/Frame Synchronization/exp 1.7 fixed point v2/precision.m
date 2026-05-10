function [max_idx, max_value, detect_enable] = precision(batch_sums)
    max_value = 0;
    max_idx = 0;
    
    for idx = 1:size(batch_sums, 1)
        if batch_sums(idx, 1) > max_value
            max_value = batch_sums(idx, 1);
            max_idx = idx;
        end
    end

    detect_enable = 1;
end
