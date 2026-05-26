function [code_low, code_high] = comparator(power_low, power_high)
%COMPARATOR MATLAB model of lowcomparator/highcomparator in HDL
%   power_low  : [p697 p770 p852 p941]
%   power_high : [p1209 p1336 p1477]

    if numel(power_low) ~= 4
        error('power_low must have 4 elements (697, 770, 852, 941).');
    end
    if numel(power_high) ~= 3
        error('power_high must have 3 elements (1209, 1336, 1477).');
    end

    p697 = power_low(1);
    p770 = power_low(2);
    p852 = power_low(3);
    p941 = power_low(4);

    if p697 > p770 && p697 > p852 && p697 > p941
        code_low = uint8(1); % "001"
    elseif p770 > p697 && p770 > p852 && p770 > p941
        code_low = uint8(2); % "010"
    elseif p852 > p697 && p852 > p770 && p852 > p941
        code_low = uint8(3); % "011"
    elseif p941 > p697 && p941 > p770 && p941 > p852
        code_low = uint8(4); % "100"
    else
        code_low = uint8(0); % "000"
    end

    p1209 = power_high(1);
    p1336 = power_high(2);
    p1477 = power_high(3);

    if p1209 > p1336 && p1209 > p1477
        code_high = uint8(1); % "001"
    elseif p1336 > p1209 && p1336 > p1477
        code_high = uint8(2); % "010"
    elseif p1477 > p1209 && p1477 > p1336
        code_high = uint8(3); % "011"
    else
        code_high = uint8(0); % "000"
    end
end
