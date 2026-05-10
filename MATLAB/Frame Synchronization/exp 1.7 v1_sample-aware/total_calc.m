function power = total_calc(I, Q)
% TOTAL_CALC - menghitung power dari hasil korelasi I dan Q
%
% INPUT:
%   I, Q   : hasil akumulasi dari accu.m (sudah di-scale di sana)
%
% OUTPUT:
%   power  : nilai power (I^2 + Q^2)
    power = I.^2 + Q.^2;

end