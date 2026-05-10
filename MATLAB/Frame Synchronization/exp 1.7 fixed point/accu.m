function [acc_sinsignal, acc_cossignal] = accu(mult_sinsignal, mult_cossignal, frame_size)
    num_frames = floor(size(mult_sinsignal, 2) / frame_size);
    acc_sinsignal = zeros(size(mult_sinsignal, 1), num_frames);
    acc_cossignal = zeros(size(mult_cossignal, 1), num_frames);

    for frame = 1:num_frames
        start_idx = (frame - 1) * frame_size + 1;
        end_idx = frame * frame_size;

        for freq_idx = 1:size(mult_sinsignal, 1)
            acc_sinsignal(freq_idx, frame) = sum(mult_sinsignal(freq_idx, start_idx:end_idx));
            acc_cossignal(freq_idx, frame) = sum(mult_cossignal(freq_idx, start_idx:end_idx));
        end
    end
end
