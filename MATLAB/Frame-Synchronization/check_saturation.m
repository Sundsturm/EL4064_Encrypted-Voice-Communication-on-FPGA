function check_saturation(x, name)
    if ~isfi(x)
        fprintf('[%s] NOT fixed-point\n', name);
        return;
    end

    x_double = double(x);
    max_val = max(x_double(:));
    min_val = min(x_double(:));

    % Ambil info numerik
    WL = x.WordLength;
    FL = x.FractionLength;

    max_theoretical = (2^(WL-FL-1)) - 2^(-FL);
    min_theoretical = -2^(WL-FL-1);

    % Deteksi saturasi
    sat_high = sum(x_double(:) >= max_theoretical);
    sat_low  = sum(x_double(:) <= min_theoretical);
    total    = numel(x);

    fprintf('\n[%s]\n', name);
    fprintf('  Format        : Q%d.%d (WL=%d)\n', WL-FL, FL, WL);
    fprintf('  Range actual  : [%.5f, %.5f]\n', min_val, max_val);
    fprintf('  Range theory  : [%.5f, %.5f]\n', min_theoretical, max_theoretical);
    fprintf('  Saturation    : High=%d (%.3f%%), Low=%d (%.3f%%)\n', ...
        sat_high, 100*sat_high/total, sat_low, 100*sat_low/total);
end