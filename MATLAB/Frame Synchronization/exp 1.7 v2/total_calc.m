function total_power = total_calc(acc_sinsignal, acc_cossignal)
    squared_acc_sinsignal = acc_sinsignal .^ 2;
    squared_acc_cossignal = acc_cossignal .^ 2;
    total_power = squared_acc_sinsignal + squared_acc_cossignal;
end
