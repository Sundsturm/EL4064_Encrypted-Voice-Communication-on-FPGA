function result = sin_mult(segment, ref_sin)
% SIN_MULT - perkalian sinyal dengan referensi sinus (sample-aware)
%
% INPUT:
%   segment  : [1 x N] window sinyal input
%   ref_sin  : [1 x N] referensi sinus (LUT)
%
% OUTPUT:
%   result   : hasil perkalian element-wise

    % Cek dimensi
    if length(segment) ~= length(ref_sin)
        error('Ukuran segment dan ref_sin harus sama');
    end

    % Perkalian
    result = segment .* ref_sin;

end