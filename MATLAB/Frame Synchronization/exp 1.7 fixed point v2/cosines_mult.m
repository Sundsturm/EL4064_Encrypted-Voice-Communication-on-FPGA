function mult_cossignal = cosines_mult(inputsignal, refcosines)
    % Fixed-point conversion to Q2.14 (16-bit)
    F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');
    refcosines_length = size(refcosines, 2); % Length of each reference signal
    mult_cossignal = fi(zeros(size(refcosines, 1), length(inputsignal)), ...
        1, 16, 14, 'fimath', F);
    
    for i = 1:length(inputsignal)
        idx = mod(i - 1, refcosines_length) + 1; % Calculate index in refcosines using modulo operation
        for freq_idx = 1:size(refcosines, 1)
            temp = inputsignal(i) * refcosines(freq_idx, idx); % Signal multiplication
            mult_cossignal(freq_idx, i) = fi(temp, 1, 16, 14, 'fimath', F);
        end
    end
end
