function mult_cossignal = cosines_mult(inputsignal, refcosines)
    refcosines_length = size(refcosines, 2); % Length of each reference signal
    mult_cossignal = zeros(size(refcosines, 1), length(inputsignal));

    for i = 1:length(inputsignal)
        idx = mod(i - 1, refcosines_length) + 1; % Calculate index in refcosines using modulo operation
        for freq_idx = 1:size(refcosines, 1)
            mult_cossignal(freq_idx, i) = inputsignal(i) * refcosines(freq_idx, idx);
        end
    end
end
