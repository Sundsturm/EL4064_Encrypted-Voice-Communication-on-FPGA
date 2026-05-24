function [refsin, refcos] = lut_941()
    Fs = 32000;
    duration = 0.02;
    N = Fs * duration;
    n = 0:(N - 1);

    refsin_d = sin(2 * pi * 941 * n / Fs);
    refcos_d = cos(2 * pi * 941 * n / Fs);

    F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate'); %Q3.13
    refsin = fi(refsin_d, 1, 16, 13, 'fimath', F);
    refcos = fi(refcos_d, 1, 16, 13, 'fimath', F);
end
