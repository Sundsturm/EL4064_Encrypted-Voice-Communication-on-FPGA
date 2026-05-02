function result = cosines_mult(segment, ref_cos)
% COSINES_MULT - perkalian sinyal dengan referensi cosinus (sample-aware)
%
% INPUT:
%   segment  : [1 x N] window sinyal input
%   ref_cos  : [1 x N] referensi cosinus (LUT)
%
% OUTPUT:
%   result   : hasil perkalian element-wise

    % Cek dimensi
    if length(segment) ~= length(ref_cos)
        error('Ukuran segment dan ref_cos harus sama');
    end

    % Perkalian
    result = segment .* ref_cos;

end