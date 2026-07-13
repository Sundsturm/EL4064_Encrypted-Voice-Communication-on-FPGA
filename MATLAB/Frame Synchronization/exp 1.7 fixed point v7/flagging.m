function [detect_enable_941, detect_enable_1477, precision_enable, flag_start_idx] = flagging(batch_sums)
% FLAGGING  Flag detection module untuk DTMF "#" (941 Hz dan 1477 Hz)
%
%   Sesuai dengan flaggingv2.vhd. Dua counter independen di-update per batch.
%   Menggunakan guard floor 32.0.

    % Tweaking parameters defined internally
    lookback_depth  = 16;  % LOOKBACK_DEPTH in flaggingv2
    threshold_coeff = 5;   % THRESHOLD_COEFF in flaggingv2
    guard_floor     = 32.0; % GUARD_FLOOR in flaggingv2 (VHDL)

    detect_enable_941 = 0;
    detect_enable_1477 = 0;
    precision_enable = 0;
    flag_start_idx = -1;  % -1 = flag '#' tidak terdeteksi

    % Initialize internal states of flaggingv2 FSM
    cbuffer941  = zeros(lookback_depth + 1, 1);
    cbuffer1477 = zeros(lookback_depth + 1, 1);
    index       = 0;  % 0-indexed to match VHDL
    full        = 0;
    count_941   = 0;
    count_1477  = 0;
    detect_941  = 0;
    detect_1477 = 0;
    onoff_mark  = 0;

    N = size(batch_sums, 1);

    for idx = 1:N
        in_941  = double(batch_sums(idx, 2));
        in_1477 = double(batch_sums(idx, 3));

        % IDLE state logic
        new941   = in_941;
        new1477  = in_1477;
        old_941  = threshold_coeff * cbuffer941(index + 1);
        old_1477 = threshold_coeff * cbuffer1477(index + 1);

        % COMPUTE state logic (evaluates using non-blocking/registered semantics)
        prev_count_941  = count_941;
        prev_count_1477 = count_1477;
        prev_detect_941 = detect_941;
        prev_detect_1477 = detect_1477;

        if full == 1
            % 941 Hz detection (independen, dengan noise floor guard floor check)
            if new941 >= old_941 && new941 > guard_floor
                if prev_count_941 < 5
                    count_941 = prev_count_941 + 1;
                else
                    count_941 = 5;
                end
            else
                count_941 = 0;
            end

            % 1477 Hz detection (independen, dengan noise floor guard floor check)
            if new1477 >= old_1477 && new1477 > guard_floor
                if prev_count_1477 < 5
                    count_1477 = prev_count_1477 + 1;
                else
                    count_1477 = 5;
                end
            else
                count_1477 = 0;
            end

            % SR latch detection per frekuensi (RTL: count >= 4 setara >= 5 di MATLAB)
            if prev_count_941 >= 4
                detect_941 = 1;
            end

            if prev_count_1477 >= 4
                detect_1477 = 1;
            end

            % SR latch untuk onoff_mark (aktif jika kedua detect sudah bernilai 1)
            if prev_detect_941 == 1 && prev_detect_1477 == 1
                onoff_mark = 1;
            end
        end

        % STORE state logic
        cbuffer941(index + 1)  = in_941;
        cbuffer1477(index + 1) = in_1477;

        if index == lookback_depth
            full = 1;
        end

        % Advance index (modular lookback_depth + 1)
        if index == lookback_depth
            index = 0;
        else
            index = index + 1;
        end

        % Check if SR latch is asserted
        if onoff_mark == 1
            precision_enable = 1;
            detect_enable_941 = detect_941;
            detect_enable_1477 = detect_1477;
            flag_start_idx = idx;

            fprintf('Sinyal Flag ("#") terdeteksi pada batch ke-%d\n', flag_start_idx);
            fprintf('  941 Hz  = %.2f\n', batch_sums(flag_start_idx, 2));
            fprintf('  1477 Hz = %.2f\n', batch_sums(flag_start_idx, 3));
            break;
        end
    end
end