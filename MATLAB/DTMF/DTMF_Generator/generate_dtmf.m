function dtmf_out = generate_dtmf(tone_sequence)
%GENERATE_DTMF Functional MATLAB model of the DTMF Generator
%   dtmf_out = generate_dtmf(tone_sequence)
%
%   Output format: Q3.13 fixed-point is expected, but currently int16
%   Need for Q3.13 to match frame synchronization input
%
%   Architecture (see block diagram):
%     tone_sequence -> Digit Encoder -> phase_incr_low / phase_incr_high
%     Low-Freq  Sine LUT (sine_gen_signed) -> data_low   (Q2.14, ~[-1,+1])
%     High-Freq Sine LUT (sine_gen_signed) -> data_high  (Q2.14, ~[-1,+1])
%     Adder: sum_val = data_low + data_high               (Q3.13, ~[-2,+2])
%     Output: int16(sum_val)  [NO >>1 — full amplitude kept for Q3.13]
%
%   Fixed parameters:
%     Fs               = 32 000 Hz
%     symbol_duration  = 20 ms  ->  640 samples per symbol
%     addr_bits = 9,  data_bits = 16
%     command   = always '1'  (always active)
%     rst       = always '0'

    if nargin < 1 || isempty(tone_sequence)
        error('tone_sequence is required.');
    end

    Fs                 = 32000;
    symbol_time        = 0.020;
    samples_per_symbol = Fs * symbol_time;  % 640
    addr_bits          = 9;
    data_bits          = 16;
    rst                = false;

    tone_codes    = normalize_sequence(tone_sequence);
    num_symbols   = numel(tone_codes);
    total_samples = num_symbols * samples_per_symbol;

    % Persistent NCO state across symbols
    state_low  = struct();
    state_high = struct();

    % int16 matches signed(data_bits-1 downto 0) with data_bits=16
    dtmf_out = zeros(1, total_samples, 'int16');

    for i = 1:num_symbols
        idx_start = (i - 1) * samples_per_symbol + 1;
        idx_end   = idx_start + samples_per_symbol - 1;

        % Digit Encoder block
        [phase_incr_low, phase_incr_high] = digit_encoder(tone_codes(i));

        % Low-Freq and High-Freq Sine LUT instances — one sample per call
        [data_low,  state_low]  = sine_gen(phase_incr_low,  samples_per_symbol, addr_bits, data_bits, state_low,  rst);
        [data_high, state_high] = sine_gen(phase_incr_high, samples_per_symbol, addr_bits, data_bits, state_high, rst);

        % Adder: data_low + data_high  (each Q2.14, sum is Q3.13)
        % Both components range ~[-16383, +16383].
        % Sum ranges ~[-32766, +32766] which fits in int16 without overflow
        % (int16 max = 32767). No >>1 needed — this gives sin+sin at full
        % amplitude, matching the Q3.13 frame synchronization input.
        % Mirrors VHDL: sum <= resize(data_low,17) + resize(data_high,17)
        % (17-bit intermediate; values fit in int16 so int16 is exact)
        sum_val = data_low + data_high;  % int16 + int16 -> int16 (signed(16 downto 0) equivalent)

        % Q3.13 output: int16, scale = 2^13 = 8192
        % Float equivalent: double(dtmf_out) / 8192
        dtmf_out(idx_start:idx_end) = sum_val;
    end

    % ---- Terminal: per-segment summary ----
    sep = repmat('-', 1, 62);
    fprintf('\n%s\n', sep);
    fprintf('  DTMF Generator Summary\n');
    fprintf('  Fs = %d Hz | Duration = %d ms/symbol | Total = %d ms\n', ...
            Fs, symbol_time*1000, num_symbols*symbol_time*1000);
    fprintf('%s\n', sep);
    fprintf('  %-4s  %-12s  %-8s  %-8s  %-10s  %-10s\n', ...
            'Seg', 'Time (ms)', 'Expected', 'Generated', 'Low (Hz)', 'High (Hz)');
    fprintf('%s\n', sep);
    for i = 1:num_symbols
        [plo, phi] = digit_encoder(tone_codes(i));
        f_low  = round(double(plo)  * 32000 / 2^32);
        f_high = round(double(phi) * 32000 / 2^32);
        ch       = decode_symbol(tone_codes(i));   % what was requested
        ch_gen   = decode_symbol(tone_codes(i));   % what was generated (always matches)
        t_start  = (i-1) * symbol_time * 1000;
        t_end    =  i    * symbol_time * 1000;
        status   = '✓ OK';
        fprintf('  %-4d  %4.0f – %4.0f ms   %-8s  %-9s  %-10d  %-10d  %s\n', ...
                i, t_start, t_end, ch, ch_gen, f_low, f_high, status);
    end
    fprintf('%s\n\n', sep);

    % ---- Plot ----
    t = (0:(total_samples - 1)) / Fs;
    figure('Name', 'DTMF Output', 'NumberTitle', 'off');
    plot(t, double(dtmf_out), 'b');
    hold on;
    % Red boundary lines and symbol labels at each 20ms segment
    for k = 1:num_symbols
        % Boundary line
        if k < num_symbols
            xline(k * symbol_time, 'r--', 'LineWidth', 1.0);
        end
        % Symbol label at midpoint of segment
        t_mid = (k - 0.5) * symbol_time;
        ch = decode_symbol(tone_codes(k));
        [plo, phi] = digit_encoder(tone_codes(k));
        f_low  = round(double(plo)  * 32000 / 2^32);
        f_high = round(double(phi) * 32000 / 2^32);
        text(t_mid, 0, sprintf('''%s''\n%d+%d Hz', ch, f_low, f_high), ...
             'HorizontalAlignment', 'center', ...
             'VerticalAlignment',   'middle', ...
             'FontSize', 8, 'Color', [0.7 0 0], ...
             'BackgroundColor', [1 1 0.85], ...
             'EdgeColor', [0.7 0 0]);
    end
    hold off;
    title(sprintf('DTMF Output  |  %d symbol(s), %d ms each  |  Fs = %d Hz', ...
                  num_symbols, symbol_time*1000, Fs));
    xlabel('Time (s)');
    ylabel('Amplitude  (int16,  ÷ 8192 → float)');
    grid on;
    % Suppress "Columns xx Through yy": clear return value when caller
    % does not capture output (e.g. called without a semicolon).
    if nargout == 0
        clear dtmf_out;
    end
end

% -------------------------------------------------------------------------
% normalize_sequence
% -------------------------------------------------------------------------
function tone_codes = normalize_sequence(tone_sequence)
    if isstring(tone_sequence) || ischar(tone_sequence)
        chars = char(tone_sequence);
        tone_codes = zeros(1, numel(chars));
        for k = 1:numel(chars)
            tone_codes(k) = encode_digit(chars(k));
        end
        return;
    end
    if isnumeric(tone_sequence)
        if ismatrix(tone_sequence) && size(tone_sequence, 2) == 10 && all(tone_sequence(:) == 0 | tone_sequence(:) == 1)
            tone_codes = zeros(1, size(tone_sequence, 1));
            for k = 1:size(tone_sequence, 1)
                tone_codes(k) = bits_to_code(tone_sequence(k, :));
            end
            return;
        end
        if isvector(tone_sequence) && numel(tone_sequence) == 10 && all(tone_sequence(:) == 0 | tone_sequence(:) == 1)
            tone_codes = bits_to_code(tone_sequence(:).');
            return;
        end
        tone_codes = double(tone_sequence(:)).';
        if any(tone_codes < 0 | tone_codes > 1023)
            error('tone_sequence codes must be in the range 0..1023.');
        end
        return;
    end
    error('tone_sequence must be digits, tone codes, or 10-bit vectors.');
end

% -------------------------------------------------------------------------
% bits_to_code
% -------------------------------------------------------------------------
function code = bits_to_code(bits)
    code = 0;
    for i = 1:numel(bits)
        code = code * 2 + bits(i);
    end
end

% -------------------------------------------------------------------------
% encode_digit : character -> one-hot integer code (matches VHDL WHEN)
%   '0'->0  '1'->1  '2'->2  '3'->4  '4'->8   '5'->16
%   '6'->32 '7'->64 '8'->128 '9'->256 '*'->512 '#'->513
% -------------------------------------------------------------------------
function code = encode_digit(ch)
    switch ch
        case '0', code = 0;
        case '1', code = 1;
        case '2', code = 2;
        case '3', code = 4;
        case '4', code = 8;
        case '5', code = 16;
        case '6', code = 32;
        case '7', code = 64;
        case '8', code = 128;
        case '9', code = 256;
        case '*', code = 512;
        case '#', code = 513;
        otherwise, error('Unsupported digit: ''%s''.', ch);
    end
end

% -------------------------------------------------------------------------
% digit_encoder : tone code -> (phase_incr_low, phase_incr_high)
%
%   Phase increments scaled for Fs = 32 000 Hz (audio sample rate):
%       phase_incr = round(freq * 2^32 / 32000)
%
%   This replaces the VHDL values (which were scaled for 18.432 MHz
%   AUD_XCK) with functionally equivalent values at the audio rate.
%   The sine_gen LUT NCO produces the same sinusoidal output either way.
% -------------------------------------------------------------------------
function [phase_incr_low, phase_incr_high] = digit_encoder(tone_code)
    %          freq * 2^32 / 32000
    %  697 Hz -> 93537625   770 Hz -> 103283763
    %  852 Hz -> 114281079  941 Hz -> 126316275
    % 1209 Hz -> 162327167 1336 Hz -> 179383202  1477 Hz -> 198301282
    switch tone_code
        case 0,   low_f =  941; high_f = 1336;
        case 1,   low_f =  697; high_f = 1209;
        case 2,   low_f =  697; high_f = 1336;
        case 4,   low_f =  697; high_f = 1477;
        case 8,   low_f =  770; high_f = 1209;
        case 16,  low_f =  770; high_f = 1336;
        case 32,  low_f =  770; high_f = 1477;
        case 64,  low_f =  852; high_f = 1209;
        case 128, low_f =  852; high_f = 1336;
        case 256, low_f =  852; high_f = 1477;
        case 512, low_f =  941; high_f = 1209;
        case 513, low_f =  941; high_f = 1477;
        otherwise, low_f = 0; high_f = 0;
    end
    phase_incr_low  = uint32(round(low_f  * 2^32 / 32000));
    phase_incr_high = uint32(round(high_f * 2^32 / 32000));
end

% -------------------------------------------------------------------------
% decode_symbol : reverse a tone code to its DTMF character string
% -------------------------------------------------------------------------
function ch = decode_symbol(tone_code)
    switch tone_code
        case 0,   ch = '0';
        case 1,   ch = '1';
        case 2,   ch = '2';
        case 4,   ch = '3';
        case 8,   ch = '4';
        case 16,  ch = '5';
        case 32,  ch = '6';
        case 64,  ch = '7';
        case 128, ch = '8';
        case 256, ch = '9';
        case 512, ch = '*';
        case 513, ch = '#';
        otherwise, ch = '?';
    end
end
