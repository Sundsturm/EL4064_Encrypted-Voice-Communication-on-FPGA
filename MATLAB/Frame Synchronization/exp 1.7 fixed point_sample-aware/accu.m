function [I, Q] = accu(segment, ref_cos, ref_sin)

    F = fimath('RoundingMethod','Nearest', ...
               'OverflowAction','Saturate');

    T_mult = numerictype(1, 16, 14);
    T_acc  = numerictype(1, 16, 10);

    % MULTIPLY (vectorized)
    mult_cos = fi(segment .* ref_cos, T_mult, F);
    mult_sin = fi(segment .* ref_sin, T_mult, F);

    % SUM (single call, jauh lebih cepat)
    I = fi(sum(mult_cos), T_acc, F);
    Q = fi(sum(mult_sin), T_acc, F);

end