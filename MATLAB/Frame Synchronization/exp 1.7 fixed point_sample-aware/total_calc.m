function power = total_calc(I, Q)
% TOTAL_CALC - Fixed-point power calculation (hardware accurate)
%
% INPUT:
%   I, Q   : Q6.10
%
% OUTPUT:
%   power  : Q10.6 (unsigned)

    % =========================
    % FIXED POINT CONFIG
    % =========================
    F = fimath('RoundingMethod','Nearest', ...
               'OverflowAction','Saturate');

    T_power = numerictype(0, 16, 6); % Q10.6 unsigned

    % =========================
    % POWER CALCULATION
    % =========================
    % Step 1: square (allow growth)
    I_sq = I * I;
    Q_sq = Q * Q;

    % Step 2: sum
    power_raw = I_sq + Q_sq;

    % Step 3: cast to Q10.6 (hardware truncation + saturate)
    power = fi(power_raw, T_power, F);

end