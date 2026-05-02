function [acc_sinsignal, acc_cossignal] = accu(mult_sinsignal, mult_cossignal, frame_size)
    % Fixed-point config
    F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');

    num_frames = floor(size(mult_sinsignal, 2) / frame_size);

    % Set output signals to Q7.9 (16-bit)
    acc_sinsignal = fi(zeros(size(mult_sinsignal, 1), num_frames), ...
        1, 16, 9, 'fimath', F);
    acc_cossignal = fi(zeros(size(mult_cossignal, 1), num_frames), ...
        1, 16, 9, 'fimath', F);

    for frame = 1:num_frames
        start_idx = (frame - 1) * frame_size + 1;
        end_idx = frame * frame_size;

        for freq_idx = 1:size(mult_sinsignal, 1)
            % Accumulator initiation
            acc_sin = fi(0, 1, 16, 8, 'fimath', F);
            acc_cos = fi(0, 1, 16, 8, 'fimath', F);
            for n = start_idx:end_idx
                   % Incremental addition
                    temp_sin = acc_sin + mult_sinsignal(freq_idx, n);
                    temp_cos = acc_cos + mult_cossignal(freq_idx, n);

                    % Truncation after addition
                    acc_sin = fi(temp_sin, 1, 16, 8, 'fimath', F);
                    acc_cos = fi(temp_cos, 1, 16, 8, 'fimath', F);
            end
            % Assign output signals with acc_sin and acc_cos
            acc_sinsignal(freq_idx, frame) = acc_sin;
            acc_cossignal(freq_idx, frame) = acc_cos;
        end
    end
end
