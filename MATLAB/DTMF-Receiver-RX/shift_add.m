function [output_key, state, out_valid] = shift_add(state, dtmf_code, in_valid, out_ready)
%SHIFT_ADD MATLAB model of shift_add.vhd - Modified for 32-bit output
%
%   Accumulates 8 × 4-bit DTMF codes into a single 32-bit uint32.
%   Each call shifts existing value left by 4 bits and ORs in the new 4-bit code.
%   Output is valid after 8 symbols have been received.
%
%   dtmf_code : uint8, 4-bit DTMF code from decision (0x0 - 0xF)
%   in_valid  : logical, assert true when dtmf_code is valid
%   out_ready : logical, assert true to consume output and reset counter

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

    % Initialize state fields
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

    % Accumulate 4-bit DTMF code into 32-bit shift register
    if in_valid
        % Shift left 4 bits and OR in the new 4-bit code (no MSB valid-flag trick)
        state.temp_sig = bitshift(state.temp_sig, 4);
        state.temp_sig = bitor(state.temp_sig, uint32(bitand(uint8(dtmf_code), uint8(15))));
        state.counter  = state.counter + 1;
    end

    % Output valid after 8 symbols accumulated
    if state.counter >= 8
        state.output_key = state.temp_sig;
        out_valid = true;
        if out_ready
            state.counter  = 0;
            state.temp_sig = uint32(0);
        end
    end

    output_key = state.output_key;
end
