function dtmf_code = decision(code_low, code_high)
%DECISION MATLAB model of decision.vhd - Full 16-symbol DTMF mapping
%
%   Standard DTMF 4x4 Matrix:
%          1209Hz  1336Hz  1477Hz  1633Hz
%   697Hz    1       2       3       A
%   770Hz    4       5       6       B
%   852Hz    7       8       9       C
%   941Hz    *       0       #       D
%
%   4-bit encoding (natural hex representation):
%   '1'->0x1, '2'->0x2, '3'->0x3, 'A'->0xA
%   '4'->0x4, '5'->0x5, '6'->0x6, 'B'->0xB
%   '7'->0x7, '8'->0x8, '9'->0x9, 'C'->0xC
%   '*'->0xE, '0'->0x0, '#'->0xF, 'D'->0xD
%
%   code_low  : 1=697Hz, 2=770Hz, 3=852Hz, 4=941Hz
%   code_high : 1=1209Hz, 2=1336Hz, 3=1477Hz, 4=1633Hz

    dtmf_code = uint8(0); % Default: ambiguous / no detection

    % --- Row 1: 697 Hz ---
    if code_low == 1 && code_high == 1
        dtmf_code = uint8(1);    % '1' -> 0x1
    elseif code_low == 1 && code_high == 2
        dtmf_code = uint8(2);    % '2' -> 0x2
    elseif code_low == 1 && code_high == 3
        dtmf_code = uint8(3);    % '3' -> 0x3
    elseif code_low == 1 && code_high == 4
        dtmf_code = uint8(10);   % 'A' -> 0xA

    % --- Row 2: 770 Hz ---
    elseif code_low == 2 && code_high == 1
        dtmf_code = uint8(4);    % '4' -> 0x4
    elseif code_low == 2 && code_high == 2
        dtmf_code = uint8(5);    % '5' -> 0x5
    elseif code_low == 2 && code_high == 3
        dtmf_code = uint8(6);    % '6' -> 0x6
    elseif code_low == 2 && code_high == 4
        dtmf_code = uint8(11);   % 'B' -> 0xB

    % --- Row 3: 852 Hz ---
    elseif code_low == 3 && code_high == 1
        dtmf_code = uint8(7);    % '7' -> 0x7
    elseif code_low == 3 && code_high == 2
        dtmf_code = uint8(8);    % '8' -> 0x8
    elseif code_low == 3 && code_high == 3
        dtmf_code = uint8(9);    % '9' -> 0x9
    elseif code_low == 3 && code_high == 4
        dtmf_code = uint8(12);   % 'C' -> 0xC

    % --- Row 4: 941 Hz ---
    elseif code_low == 4 && code_high == 1
        dtmf_code = uint8(14);   % '*' -> 0xE
    elseif code_low == 4 && code_high == 2
        dtmf_code = uint8(0);    % '0' -> 0x0
    elseif code_low == 4 && code_high == 3
        dtmf_code = uint8(15);   % '#' -> 0xF
    elseif code_low == 4 && code_high == 4
        dtmf_code = uint8(13);   % 'D' -> 0xD
    end
end
