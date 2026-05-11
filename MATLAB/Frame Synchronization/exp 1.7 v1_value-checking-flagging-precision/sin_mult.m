function mult_sinsignal = sin_mult(inputsignal, refsins)
    refsins_length = size(refsins, 2); % Length of each reference signal
    mult_sinsignal = zeros(size(refsins, 1), length(inputsignal));

    for i = 1:length(inputsignal)
        idx = mod(i - 1, refsins_length) + 1; % Calculate index in refsins using modulo operation
        for freq_idx = 1:size(refsins, 1)
            mult_sinsignal(freq_idx, i) = inputsignal(i) * refsins(freq_idx, idx);
        end
    end
end