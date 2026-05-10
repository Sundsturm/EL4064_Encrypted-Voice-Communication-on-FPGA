function [flag_idx, flag_enable, TH] = flagging(score_flag, Fs)

    flag_enable = 0;
    flag_idx = [];

    skip_time = 0.01;           % skip 10 ms awal (noise)
    min_count = 5;              % hysteresis (jumlah sampel berturut-turut)
    noise_window_time = 0.01;   % estimasi noise dari 10 ms awal

    % Sample conversion
    skip_samples = round(skip_time * Fs);
    noise_window = round(noise_window_time * Fs);

    % Estimasi noise floor
    noise_floor = mean(score_flag(1:noise_window));
    signal_peak = max(score_flag);

    % Parameter threshold dengan noise floor
    TH = noise_floor + 0.3 * (signal_peak - noise_floor);

    fprintf('Noise floor: %.4f\n', noise_floor);
    fprintf('Signal peak: %.4f\n', signal_peak);
    fprintf('Adaptive Threshold (TH): %.4f\n', TH);

    % Deteksi mark/flag dengan histeresis
    count = 0;

    for i = skip_samples:length(score_flag)

        if score_flag(i) > TH
            count = count + 1;

            if count >= min_count
                flag_idx = i - min_count + 1; % awal deteksi
                flag_enable = 1;

                fprintf('FLAG terdeteksi di sample ke-%d\n', flag_idx);
                fprintf('Nilai score_flag saat deteksi: %.4f\n', score_flag(i));
                return;
            end

        else
            count = 0;
        end

    end


    fprintf('FLAG TIDAK TERDETEKSI\n');

end