function [data, state] = sine_gen(phase_incr, num_samples, addr_bits, data_bits, state, rst)
%SINE_GEN MATLAB model of sine_gen_signed.vhd (quarter-wave LUT + NCO)
%   data = sine_gen(phase_incr, num_samples, addr_bits, data_bits)
%   [data, state] = sine_gen(..., state, rst)

    if nargin < 2 || isempty(num_samples)
        num_samples = 1;
    end
    if nargin < 3 || isempty(addr_bits)
        addr_bits = 10;
    end
    if nargin < 4 || isempty(data_bits)
        data_bits = 19;
    end
    if nargin < 5 || isempty(state)
        state = struct();
    end
    if nargin < 6 || isempty(rst)
        rst = false;
    end

    state = init_state(state);

    rom_depth = 2^addr_bits;
    rom_width = data_bits - 1;
    rom = build_rom(rom_depth, rom_width);

    phase_incr = uint32(phase_incr);
    rom_mask = uint32(rom_depth - 1);
    shift_amt = 30 - addr_bits;
    base_phase_acc_incr = bitshift(uint32(1), 31 - addr_bits - 1);

    if isscalar(rst)
        rst_vec = false(1, num_samples);
        if rst
            rst_vec(1) = true;
        end
    else
        rst_vec = logical(rst);
        if numel(rst_vec) ~= num_samples
            error('rst must be scalar or length num_samples.');
        end
    end

    data = zeros(1, num_samples, 'int16');  % signed(data_bits-1 downto 0)
    for n = 1:num_samples
        if rst_vec(n)
            state.phase_acc = uint32(hex2dec('40000000'));
            state.quadrant_p1 = uint32(0);
            state.quadrant_p2 = uint32(0);
            state.rom_dout = uint32(0);
            state.rom_data = uint32(0);
            data(n) = int32(0);
            continue;
        end

        data(n) = output_from_state(state);

        phase_acc = state.phase_acc;
        quadrant = bitand(bitshift(phase_acc, -30), uint32(3));
        rom_index = bitand(bitshift(phase_acc, -shift_amt), rom_mask);
        if quadrant == 1 || quadrant == 3
            rom_addr = rom_index;
        else
            rom_addr = uint32(rom_depth - 1) - rom_index;
        end
        rom_dout_next = rom(double(rom_addr) + 1);

        % Use double+mod to replicate hardware uint32 wraparound.
        % MATLAB uint32 arithmetic saturates at 0xFFFFFFFF instead of
        % wrapping, which locks the NCO at a constant output value.
        acc = uint32(mod(double(phase_acc) + double(phase_incr), 2^32));
        rom_index_acc = bitand(bitshift(acc, -shift_amt), rom_mask);
        if rom_index_acc == rom_depth - 1
            acc = uint32(mod(double(acc) + double(base_phase_acc_incr), 2^32));
        end

        state.phase_acc = acc;
        state.quadrant_p2 = state.quadrant_p1;
        state.quadrant_p1 = quadrant;
        state.rom_data = state.rom_dout;
        state.rom_dout = rom_dout_next;
    end
end

function state = init_state(state)
    if ~isfield(state, 'phase_acc') || isempty(state.phase_acc)
        state.phase_acc = uint32(hex2dec('40000000'));
    end
    if ~isfield(state, 'quadrant_p1') || isempty(state.quadrant_p1)
        state.quadrant_p1 = uint32(0);
    end
    if ~isfield(state, 'quadrant_p2') || isempty(state.quadrant_p2)
        state.quadrant_p2 = uint32(0);
    end
    if ~isfield(state, 'rom_dout') || isempty(state.rom_dout)
        state.rom_dout = uint32(0);
    end
    if ~isfield(state, 'rom_data') || isempty(state.rom_data)
        state.rom_data = uint32(0);
    end
end

function data_out = output_from_state(state)
    % Mirrors DATA_OUT_PROC in sine_gen_signed.vhd:
    %   signed('0' & rom_data) for positive quadrants (1, 2)
    %   -signed('0' & rom_data) for negative quadrants (0, 3)
    % Result is signed(data_bits-1 downto 0) = int16
    if state.quadrant_p2 == 1 || state.quadrant_p2 == 2
        data_out = int16(state.rom_data);
    else
        data_out = -int16(state.rom_data);
    end
end

function rom = build_rom(rom_depth, rom_width)
    idx = 0:(rom_depth - 1);
    angle = double(idx) * ((pi / 2) / double(rom_depth));
    sin_scaled = sin(angle) * (2^double(rom_width - 1) - 1);
    rom = uint32(round(sin_scaled));
end
