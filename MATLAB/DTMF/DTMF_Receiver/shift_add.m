function [output_key, state, out_valid] = shift_add(state, dtmf_code, in_valid, out_ready)
%SHIFT_ADD MATLAB model of shift_add.vhd
%   dtmf_code : 4-bit code from decision (MSB indicates valid)

    if nargin < 1 || isempty(state)
        state = struct();
    end
    if nargin < 2 || isempty(dtmf_code)
        dtmf_code = uint8(0);
    end
    if nargin < 3 || isempty(in_valid)
        in_valid = true;
    end
    if nargin < 4 || isempty(out_ready)
        out_ready = true;
    end

    if ~isfield(state, 'temp_sig') || isempty(state.temp_sig)
        state.temp_sig = uint32(0);
    end
    if ~isfield(state, 'counter') || isempty(state.counter)
        state.counter = 0;
    end
    if ~isfield(state, 'output_key') || isempty(state.output_key)
        state.output_key = uint32(0);
    end

    out_valid = false;
    if in_valid
        if bitand(uint8(dtmf_code), uint8(8)) ~= 0
            state.temp_sig = bitshift(state.temp_sig, 3);
            state.temp_sig = bitor(state.temp_sig, uint32(bitand(uint8(dtmf_code), uint8(7))));
            state.counter = state.counter + 1;
        end
    end

    if state.counter >= 8
        state.output_key = state.temp_sig;
        out_valid = true;
        if out_ready
            state.counter = 0;
        end
    end

    output_key = state.output_key;
end
