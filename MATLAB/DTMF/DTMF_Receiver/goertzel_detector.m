function [power_low, power_high] = goertzel_detector(chunk, Fs)
%GOERTZEL_DETECTOR MATLAB model of Goertzel_top.vhd + Goertzel.vhd

    if nargin < 2 || isempty(Fs)
        Fs = 32000; %#ok<NASGU>
    end

    if isempty(chunk)
        error('Input chunk is empty.');
    end

    chunk = double(chunk(:)).';
    if numel(chunk) ~= 640
        error('Input chunk must be 640 samples to match BLOCK_SIZE.');
    end

    coeff_697  = 1.98113868088715;
    coeff_770  = 1.97537668119028;
    coeff_852  = 1.96885313617978;
    coeff_941  = 1.96530655866142;
    coeff_1209 = 1.94006250638909;
    coeff_1336 = 1.93014734462309;
    coeff_1477 = 1.91388067146442;

    power_low = [
        goertzel_power(chunk, coeff_697), ...
        goertzel_power(chunk, coeff_770), ...
        goertzel_power(chunk, coeff_852), ...
        goertzel_power(chunk, coeff_941)
    ];

    power_high = [
        goertzel_power(chunk, coeff_1209), ...
        goertzel_power(chunk, coeff_1336), ...
        goertzel_power(chunk, coeff_1477)
    ];
end

function power_val = goertzel_power(samples, coeff)
    q1 = 0;
    q2 = 0;
    for n = 1:numel(samples)
        q0 = samples(n) + coeff * q1 - q2;
        q2 = q1;
        q1 = q0;
    end
    power_val = abs(q1 * q1 + q2 * q2 - coeff * q1 * q2);
end
