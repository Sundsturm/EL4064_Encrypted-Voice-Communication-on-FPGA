function [detect_enable_941, detect_enable_1477, precision_enable] = flagging(batch_sums)

    detect_enable_941 = 0;
    detect_enable_1477 = 0;
    precision_enable = 0;

    count_941 = 0;
    count_1477 = 0;

    % Mulai dari 33 karena -32
    for slide_i = 33:size(batch_sums, 1)

        % 941 Hz Detection
        prev_941 = batch_sums(slide_i - 32, 2);
        curr_941 = batch_sums(slide_i, 2);

        if curr_941 >= 3 * prev_941
            count_941 = count_941 + 1;
        else
            count_941 = 0;
        end

        if count_941 >= 5
            detect_enable_941 = 1;
        end

        % 1477 Hz Detection
        prev_1477 = batch_sums(slide_i - 32, 3);
        curr_1477 = batch_sums(slide_i, 3);

        if curr_1477 >= 3 * prev_1477
            count_1477 = count_1477 + 1;
        else
            count_1477 = 0;
        end

        if count_1477 >= 5
            detect_enable_1477 = 1;
        end

        % "#" detection
        if detect_enable_941 && detect_enable_1477
            precision_enable = 1;

            start_idx = slide_i - 4; % awal dari 5 consecutive

            fprintf('Sinyal Flag dimulai pada batch ke-%d\n', start_idx);
            fprintf('941 Hz = %.2f\n', batch_sums(start_idx, 2));
            fprintf('1477 Hz = %.2f\n', batch_sums(start_idx, 3));

            break;
        end
    end
end