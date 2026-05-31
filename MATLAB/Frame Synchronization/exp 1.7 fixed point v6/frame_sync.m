function goertzel_enable = frame_sync(inputsignal)
% FRAME_SYNC  Frame synchronization module.
%
%   Accepts a fixed-point input signal (fi, Q3.13) containing
%   12 DTMF symbols:
%       - First 4 symbols : sync point "##3#"
%       - Next 8 symbols  : payload DTMF symbols to be processed
%
%   The function detects the "##3#" sync pattern in the input signal
%   and asserts an enable signal for the downstream receiver (Goertzel detector).
%
%   Input:
%       inputsignal    : fixed-point input signal fi (1 x M), Q3.13 format
%                        (M = total number of samples from 12 symbols + noise)
%
%   Output:
%       goertzel_enable: 1 if sync point "##3#" is detected, 0 otherwise
%
%   Example call from top-level:
%       enable = frame_sync(inputsignal);
%
%   To run a standalone demo (with an internally generated test signal),
%   use script: run_frame_sync_demo.m

% =========================================
% Fixed-point parameters
% =========================================
Fs         = 32000;   % Sampling frequency (Hz)
frame_size = 40;      % Frame size (samples)
batch_size = 16;      % Batch size (frames)
dtmf_freqs = [697, 941, 1477];

% =========================================
% Step 0: Generate LUT reference sines/cosines
% =========================================
[refsin_697,  refcos_697]  = lut_697();
[refsin_941,  refcos_941]  = lut_941();
[refsin_1477, refcos_1477] = lut_1477();

refsins = [
    refsin_697;   % Freq 697 Hz
    refsin_941;   % Freq 941 Hz
    refsin_1477   % Freq 1477 Hz
];

refcosines = [
    refcos_697;   % Freq 697 Hz
    refcos_941;   % Freq 941 Hz
    refcos_1477   % Freq 1477 Hz
];

% =========================================
% Step 1: Multiply input signal with reference sine and cosine
% =========================================
mult_sinsignal = sin_mult(inputsignal, refsins);
mult_cossignal = cosines_mult(inputsignal, refcosines);
check_saturation(mult_sinsignal, 'MULT SIN');
check_saturation(mult_cossignal, 'MULT COS');

% =========================================
% Step 2: Accumulate data for framing
% =========================================
[acc_sinsignal, acc_cossignal] = accu(mult_sinsignal, mult_cossignal, frame_size);
check_saturation(acc_sinsignal, 'ACC SIN');
check_saturation(acc_cossignal, 'ACC COS');

% =========================================
% Step 3: Calculate total power from sin and cos accumulations
% =========================================
total_power = total_calc(acc_sinsignal, acc_cossignal);
check_saturation(total_power, 'TOTAL POWER');

% =========================================
% Step 4: Perform sliding window batch summation
% =========================================
batch_sums = sliding(total_power, batch_size);
check_saturation(batch_sums, 'BATCH SUM');

% Range info
max_val = max(double(batch_sums(:)));
min_val = min(double(batch_sums(:)));
disp(['Max. batch sums: ', num2str(max_val)])
disp(['Min. batch sums: ', num2str(min_val)])

% =========================================
% Step 5: Flagging — detect "##" (941 Hz & 1477 Hz)
% =========================================
[~, ~, precision_enable, flag_start_idx] = flagging(batch_sums);

% =========================================
% Step 6: Marking — detect DTMF "3" (697 Hz) after flag confirmation
% =========================================
flag_valid      = precision_enable;
dtmf3_idx       = -1;
goertzel_enable = 0;

if flag_valid
    [dtmf3_idx, ~, goertzel_enable] = marking(batch_sums, flag_start_idx);

    if goertzel_enable
        fprintf('Detection complete: mark_valid = 1, goertzel_enable = 1.\n');
    else
        fprintf('Flag detected, but DTMF "3" was not found.\n');
    end
else
    fprintf('No flag signal detected.\n');
end

fprintf('Goertzel Enable = %d\n', goertzel_enable);

% =========================================
% Print vertical line positions to terminal
% =========================================
fprintf('\n--- Vertical Line Positions ---\n');
if dtmf3_idx > 0
    fprintf('[Green Line]  DTMF "3" detected at batch index = %d\n', dtmf3_idx);
    fprintf('              Condition: 697Hz rising, 697Hz > 941Hz, 1477Hz > 941Hz\n');
else
    fprintf('[Green Line]  DTMF "3" NOT detected\n');
end
fprintf('-------------------------------\n\n');

% =========================================
% Visualization (only runs when no output argument is captured,
% i.e. when called interactively / in standalone mode)
% =========================================
if nargout == 0
    samples_per_batch = frame_size * batch_size;
    time_per_frame    = frame_size / Fs;
    time_per_batch    = samples_per_batch / Fs;

    figure;
    hold on;
    for freq_idx = 1:3
        plot(1:size(batch_sums, 1), double(batch_sums(:, freq_idx)), ...
            'DisplayName', ['Frequency ', num2str(dtmf_freqs(freq_idx)), ' Hz'], ...
            'LineWidth', 2);
    end
    if dtmf3_idx > 0
        xline(dtmf3_idx, 'g-', ...
            ['DTMF "3" detected @ idx=', num2str(dtmf3_idx)], ...
            'LabelVerticalAlignment','bottom', ...
            'LabelHorizontalAlignment','left', ...
            'LineWidth', 2, ...
            'DisplayName', ['DTMF "3" detected @ idx=', num2str(dtmf3_idx)]);
    end
    xlabel('Sliding Window Index');
    ylabel('Accumulated Power (Batch)');
    title({
        'Sliding Window Batch Accumulation (Fixed-Point Simulation)'
        ['Frame Size = ', num2str(frame_size), ' samples | Batch Size = ', num2str(batch_size), ' frames']
        ['Samples/Batch = ', num2str(samples_per_batch), ...
         ' | Frame Time = ', num2str(time_per_frame*1e3, '%.2f'), ' ms', ...
         ' | Batch Time = ', num2str(time_per_batch*1e3, '%.2f'), ' ms']
    });
    legend('show','Location','best');
    grid on;
    annotation('textbox', [0.15 0.75 0.3 0.15], ...
        'String', { ...
        ['Fs = ', num2str(Fs), ' Hz'], ...
        ['Fixed-point: Q2.14 -> Q2.14 -> Q8.8 -> Q12.4 -> Q14.2'], ...
        ['Max = ', num2str(max_val)], ...
        ['Min = ', num2str(min_val)]}, ...
        'FitBoxToText','on', ...
        'BackgroundColor','white');
    hold off;

    figure;
    hold on;
    for freq_idx = 1:3
        plot(1:size(batch_sums, 1), batch_sums(:, freq_idx), ...
            'DisplayName', ['Frequency ', num2str(dtmf_freqs(freq_idx)), ' Hz'], ...
            'LineWidth', 3);
    end
    if dtmf3_idx > 0
        xline(dtmf3_idx, 'g-', ...
            ['DTMF "3" @ idx=', num2str(dtmf3_idx)], ...
            'LabelVerticalAlignment','bottom', ...
            'LabelHorizontalAlignment','left', ...
            'LineWidth', 2, ...
            'DisplayName', ['DTMF "3" detected @ idx=', num2str(dtmf3_idx)]);
    end
    xlabel('Sliding Window Index');
    ylabel('Accumulated Power (Batch)');
    title('Sliding Window Batch Accumulation for DTMF Frequencies');
    legend('show');
    grid on;
    hold off;
end

end % function frame_sync
