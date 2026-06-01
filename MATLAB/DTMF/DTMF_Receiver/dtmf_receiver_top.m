function [reconstructed_key, decode_table] = dtmf_receiver_top(payload_signal)
%DTMF_RECEIVER_TOP Pure DTMF Receiver - standalone, no external dependencies
%
%   Memodelkan alur DTMF Receiver murni:
%     1. Goertzel filter bank (7 atau 8 frekuensi) per blok 640 sampel
%     2. Comparator (low & high group)
%     3. Decision (pemetaan 16-simbol DTMF)
%     4. Shift-add accumulator (8 x 4-bit -> 32-bit)
%
%   Input:
%       payload_signal - Array int16/double, tepat 8*640 = 5120 sampel
%                        (sudah bersih, tidak perlu preamble)
%   Output:
%       reconstructed_key - uint32, hasil decode 32-bit
%       decode_table      - struct array (8 elemen), detail per simbol:
%                           .symbol_index   : nomor simbol (1-8)
%                           .dtmf_char      : karakter DTMF terdeteksi
%                           .dtmf_code      : 4-bit uint8
%                           .bits           : string 4-bit biner
%                           .dominant_low_hz  : frekuensi low group dominan (Hz)
%                           .dominant_high_hz : frekuensi high group dominan (Hz)
%                           .energy_low       : nilai energi frekuensi low dominan
%                           .energy_high      : nilai energi frekuensi high dominan

    Fs     = 32000;
    N      = 640;   % 20 ms per simbol @ 32 kHz
    N_SYM  = 8;

    if length(payload_signal) < N_SYM * N
        error('payload_signal terlalu pendek. Diperlukan min %d sampel (%d simbol x %d sampel).', ...
              N_SYM * N, N_SYM, N);
    end

    low_freqs  = [697, 770, 852, 941];
    high_freqs = [1209, 1336, 1477, 1633];

    % Lookup tabel karakter DTMF dari (code_low, code_high)
    % Baris = code_low (1..4), Kolom = code_high (1..4)
    dtmf_chars = {'1','2','3','A'; ...
                  '4','5','6','B'; ...
                  '7','8','9','C'; ...
                  '*','0','#','D'};

    reconstructed_key = uint32(0);
    shift_state       = struct();
    decode_table      = struct('symbol_index',   cell(1, N_SYM), ...
                               'dtmf_char',      cell(1, N_SYM), ...
                               'dtmf_code',      cell(1, N_SYM), ...
                               'bits',           cell(1, N_SYM), ...
                               'dominant_low_hz',  cell(1, N_SYM), ...
                               'dominant_high_hz', cell(1, N_SYM), ...
                               'energy_low',       cell(1, N_SYM), ...
                               'energy_high',      cell(1, N_SYM));

    fprintf('\n=== DTMF RECEIVER TOP (PURE) ===\n');
    fprintf('Memproses %d simbol (@ %d sampel/simbol, Fs=%d Hz)\n\n', N_SYM, N, Fs);

    for i = 1:N_SYM
        idx_start = (i - 1) * N + 1;
        idx_end   = i * N;
        chunk     = payload_signal(idx_start:idx_end);

        % Stage 1: Goertzel Filter Bank
        [power_low, power_high] = goertzel_detector(chunk, Fs);

        % Stage 2: Comparator
        [code_low, code_high] = comparator(power_low, power_high);

        % Stage 3: Decision
        dtmf_code = decision(code_low, code_high);

        % Stage 4: Shift-Add Accumulator
        [output_key, shift_state, out_valid] = shift_add(shift_state, dtmf_code, true, true);

        if out_valid
            reconstructed_key = output_key;
        end

        % Isi decode_table
        cl = double(code_low);
        ch = double(code_high);
        if cl >= 1 && cl <= 4 && ch >= 1 && ch <= 4
            sym_char = dtmf_chars{cl, ch};
        else
            sym_char = '?';
        end

        % Energi dominan
        if cl >= 1 && cl <= 4
            dom_energy_low  = power_low(cl);
            dom_low_hz      = low_freqs(cl);
        else
            dom_energy_low  = 0;
            dom_low_hz      = 0;
        end
        if ch >= 1 && ch <= 4
            dom_energy_high = power_high(ch);
            dom_high_hz     = high_freqs(ch);
        else
            dom_energy_high = 0;
            dom_high_hz     = 0;
        end

        decode_table(i).symbol_index    = i;
        decode_table(i).dtmf_char       = sym_char;
        decode_table(i).dtmf_code       = dtmf_code;
        decode_table(i).bits            = dec2bin(double(dtmf_code), 4);
        decode_table(i).dominant_low_hz  = dom_low_hz;
        decode_table(i).dominant_high_hz = dom_high_hz;
        decode_table(i).energy_low       = dom_energy_low;
        decode_table(i).energy_high      = dom_energy_high;

        fprintf('Simbol %d/8 -> Karakter: %s | Code: 0x%X | Bits: %s | Low: %dHz (E=%.2e) | High: %dHz (E=%.2e)\n', ...
                i, sym_char, dtmf_code, dec2bin(double(dtmf_code), 4), ...
                dom_low_hz, dom_energy_low, dom_high_hz, dom_energy_high);
    end

    fprintf('\nDekode Selesai. Reconstructed Key = 0x%08X\n\n', reconstructed_key);
end
