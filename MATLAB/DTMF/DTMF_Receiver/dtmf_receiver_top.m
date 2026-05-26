function reconstructed_key = reconstruct_key(sinyal_input)
%RECONSTRUCT_KEY MATLAB model of dtmf_system.vhd + top_dtmfencode.vhd

    Fs = 32000;
    N = 640;

    if length(sinyal_input) < 8 * N
        error('Panjang sinyal input kurang dari 5120 sampel.');
    end

    reconstructed_key = uint32(0);
    shift_state = struct();

    for i = 1:8
        fprintf('\n>> Memproses Segmen %d/8...\n', i);
        idx_start = (i - 1) * N + 1;
        idx_end = i * N;
        chunk = sinyal_input(idx_start:idx_end);

        [power_low, power_high] = goertzel_detector(chunk, Fs);
        [code_low, code_high] = comparator(power_low, power_high);
        dtmf_code = decision(code_low, code_high);

        [output_key, shift_state, out_valid] = shift_add(shift_state, dtmf_code, true, true);
        fprintf('  -> [Decision] DTMF Code: 0x%X\n', dtmf_code);

        if out_valid
            reconstructed_key = output_key;
        end
    end
end
