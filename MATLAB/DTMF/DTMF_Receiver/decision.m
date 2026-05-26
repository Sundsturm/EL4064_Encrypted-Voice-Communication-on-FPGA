function dtmf_code = decision(code_low, code_high)
%DECISION MATLAB model of decision.vhd (DTMF code only)
%   code_low  : 3-bit code from lowcomparator (1..4 or 0)
%   code_high : 3-bit code from highcomparator (1..3 or 0)

    dtmf_code = uint8(0);

    if code_low == 1 && code_high == 1
        dtmf_code = uint8(8);   % "1000" -> DTMF 1
    elseif code_low == 1 && code_high == 2
        dtmf_code = uint8(9);   % "1001" -> DTMF 2
    elseif code_low == 2 && code_high == 1
        dtmf_code = uint8(10);  % "1010" -> DTMF 4
    elseif code_low == 2 && code_high == 2
        dtmf_code = uint8(11);  % "1011" -> DTMF 5
    elseif code_low == 3 && code_high == 1
        dtmf_code = uint8(12);  % "1100" -> DTMF 7
    elseif code_low == 3 && code_high == 2
        dtmf_code = uint8(13);  % "1101" -> DTMF 8
    elseif code_low == 4 && code_high == 1
        dtmf_code = uint8(14);  % "1110" -> DTMF *
    elseif code_low == 4 && code_high == 2
        dtmf_code = uint8(15);  % "1111" -> DTMF 0
    end
end
