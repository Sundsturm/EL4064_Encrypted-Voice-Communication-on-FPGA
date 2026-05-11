function mult_sinsignal = sin_mult(inputsignal, refsins)
    % Fixed-point conversion configuration Q2.14 (16-bit)
    F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');
    refsins_length = size(refsins, 2); % Length of each reference signal
    mult_sinsignal = fi(zeros(size(refsins, 1), length(inputsignal)), ...
                        1, 16, 14, 'fimath', F); % Preallocate to Q2.14

    for i = 1:length(inputsignal)
        idx = mod(i - 1, refsins_length) + 1; % Calculate index in refsins using modulo operation
        for freq_idx = 1:size(refsins, 1)
            temp = inputsignal(i) * refsins(freq_idx, idx); % Signal multiplication
            mult_sinsignal(freq_idx, i) = fi(temp, 1, 16, 14, 'fimath', F);
        end
    end
end
