function result = sin_mult(segment, ref_sin)
% SIN_MULT - Fixed-point sine multiplication (hardware accurate)
%
% INPUT:
%   segment  : Q2.14
%   ref_sin  : Q2.14
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
    if length(segment) ~= length(ref_sin)
        error('Ukuran segment dan ref_sin harus sama');
    end

    % =========================
    % MULTIPLICATION
    % =========================
    result = fi(zeros(size(segment)), T_mult, F);

    for k = 1:length(segment)
        result(k) = fi(segment(k) * ref_sin(k), T_mult, F);
    end

end