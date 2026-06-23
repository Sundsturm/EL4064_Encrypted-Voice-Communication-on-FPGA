function total_power = total_calc(acc_sinsignal, acc_cossignal)
    % Fixed-point configuration Q12.4 -> 16-bit
    F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');
    squared_acc_sinsignal = acc_sinsignal .^ 2;
    squared_acc_cossignal = acc_cossignal .^ 2;
    power = squared_acc_sinsignal + squared_acc_cossignal;
    total_power = fi(power, 1, 16, 4, 'fimath', F);
end
