function [I, Q] = accu(segment, ref_cos, ref_sin)
% ACCU - akumulasi korelasi I/Q untuk satu window (sample-aware)
%
% INPUT:
%   segment   : [1 x N] potongan sinyal (window)
%   ref_cos   : [1 x N] referensi cos
%   ref_sin   : [1 x N] referensi sin
%
% OUTPUT:
%   I, Q      : hasil akumulasi (sudah di-scale untuk hindari overflow)

    SHIFT_ACC = 3;  % Parameter untuk scaling (Sekarang: shift right 3-bit)

    % Scaling input untuk menghindari akumulasi
    segment_s = segment / (2^SHIFT_ACC);

    % =========================
    % AKUMULASI
    % =========================
    I = sum(segment_s .* ref_cos);
    Q = sum(segment_s .* ref_sin);
end
