function [code_low, code_high] = comparator(power_low, power_high)
%COMPARATOR MATLAB model of lowcomparator/highcomparator in HDL
%   Extended to support full 16-symbol DTMF (4 high-group frequencies)
%
%   power_low  : [p697 p770 p852 p941]       (4 elements)
%   power_high : [p1209 p1336 p1477 p1633]   (4 elements)
%
%   code_low  : 1=697Hz, 2=770Hz, 3=852Hz, 4=941Hz  (0=ambiguous)
%   code_high : 1=1209Hz, 2=1336Hz, 3=1477Hz, 4=1633Hz (0=ambiguous)

    if numel(power_low) ~= 4
        error('power_low must have 4 elements (697, 770, 852, 941).');
    end
    if numel(power_high) ~= 4
        error('power_high must have 4 elements (1209, 1336, 1477, 1633).');
    end

    % --- Low Group Comparator (matches lowcomparator.vhd logic) ---
    p697 = power_low(1);
    p770 = power_low(2);
    p852 = power_low(3);
    p941 = power_low(4);

    if p697 > p770 && p697 > p852 && p697 > p941
        code_low = uint8(1); % 697 Hz
    elseif p770 > p697 && p770 > p852 && p770 > p941
        code_low = uint8(2); % 770 Hz
    elseif p852 > p697 && p852 > p770 && p852 > p941
        code_low = uint8(3); % 852 Hz
    elseif p941 > p697 && p941 > p770 && p941 > p852
        code_low = uint8(4); % 941 Hz
    else
        code_low = uint8(0); % Ambiguous
    end

    % --- High Group Comparator (extended to include 1633 Hz) ---
    p1209 = power_high(1);
    p1336 = power_high(2);
    p1477 = power_high(3);
    p1633 = power_high(4);

    if p1209 > p1336 && p1209 > p1477 && p1209 > p1633
        code_high = uint8(1); % 1209 Hz
    elseif p1336 > p1209 && p1336 > p1477 && p1336 > p1633
        code_high = uint8(2); % 1336 Hz
    elseif p1477 > p1209 && p1477 > p1336 && p1477 > p1633
        code_high = uint8(3); % 1477 Hz
    elseif p1633 > p1209 && p1633 > p1336 && p1633 > p1477
        code_high = uint8(4); % 1633 Hz -> for A, B, C, D
    else
        code_high = uint8(0); % Ambiguous
    end
end
