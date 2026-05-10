function result = cosines_mult(segment, ref_cos)
% COSINES_MULT - Fixed-point cosine multiplication (hardware accurate)
%
% INPUT:
%   segment  : Q2.14
%   ref_cos  : Q2.14
%
% OUTPUT:
%   result   : Q2.14

    % =========================
    % FIXED POINT CONFIG
    % =========================
    F = fimath('RoundingMethod','Nearest', ...
               'OverflowAction','Saturate');

    T_mult = numerictype(1, 16, 14); % Q2.14

    % =========================
    % VALIDASI DIMENSI
    % =========================
    if length(segment) ~= length(ref_cos)
        error('Ukuran segment dan ref_cos harus sama');
    end

    % =========================
    % MULTIPLICATION
    % =========================
    result = fi(zeros(size(segment)), T_mult, F);

    for k = 1:length(segment)
        result(k) = fi(segment(k) * ref_cos(k), T_mult, F);
    end

end