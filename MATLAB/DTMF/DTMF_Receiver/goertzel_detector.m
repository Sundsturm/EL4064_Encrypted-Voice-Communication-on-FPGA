function [power_low, power_high] = goertzel_detector(chunk, Fs)
%GOERTZEL_DETECTOR MATLAB model of Goertzel_top.vhd + Goertzel.vhd
%   Extended to support full 16-symbol DTMF (includes 1633 Hz for A,B,C,D)
%
%   Outputs:
%       power_low  : [p697 p770 p852 p941]       (4 elements)
%       power_high : [p1209 p1336 p1477 p1633]   (4 elements)

    if nargin < 2 || isempty(Fs)
        Fs = 32000;
    end

    if isempty(chunk)
        error('Input chunk is empty.');
    end

    chunk = double(chunk(:)).';
    if numel(chunk) ~= 640
        error('Input chunk must be 640 samples to match BLOCK_SIZE.');
    end

    % Goertzel coefficients: coeff = 2*cos(2*pi*f/Fs)
    coeff_697  = 2*cos(2*pi*697/Fs);   % 1.98113868088715
    coeff_770  = 2*cos(2*pi*770/Fs);   % 1.97537668119028
    coeff_852  = 2*cos(2*pi*852/Fs);   % 1.96885313617978
    coeff_941  = 2*cos(2*pi*941/Fs);   % 1.96530655866142
    coeff_1209 = 2*cos(2*pi*1209/Fs);  % 1.94006250638909
    coeff_1336 = 2*cos(2*pi*1336/Fs);  % 1.93014734462309
    coeff_1477 = 2*cos(2*pi*1477/Fs);  % 1.91388067146442
    coeff_1633 = 2*cos(2*pi*1633/Fs);  % ~1.89757 (for A,B,C,D symbols)

    power_low = [
        goertzel_power(chunk, coeff_697), ...
        goertzel_power(chunk, coeff_770), ...
        goertzel_power(chunk, coeff_852), ...
        goertzel_power(chunk, coeff_941)
    ];

    power_high = [
        goertzel_power(chunk, coeff_1209), ...
        goertzel_power(chunk, coeff_1336), ...
        goertzel_power(chunk, coeff_1477), ...
        goertzel_power(chunk, coeff_1633)
    ];
end

function power_val = goertzel_power(samples, coeff)
%   Energi dinormalisasi dengan N^2 agar hasilnya proporsional terhadap
%   amplitudo sinyal (bukan tumbuh kuadratik terhadap jumlah sampel).
%   Perbandingan relatif antar frekuensi tetap valid karena semua dibagi N^2.
    N  = numel(samples);
    q1 = 0;
    q2 = 0;
    for n = 1:N
        q0 = samples(n) + coeff * q1 - q2;
        q2 = q1;
        q1 = q0;
    end
    raw_power = abs(q1 * q1 + q2 * q2 - coeff * q1 * q2);
    power_val = raw_power / (N * N);   % Normalisasi: satuan ~amplitudo^2
end
