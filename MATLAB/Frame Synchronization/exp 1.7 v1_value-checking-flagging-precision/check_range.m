function check_range(x, name)
    x_double = double(x);
    max_val = max(x_double(:));
    min_val = min(x_double(:));

    fprintf('\n[%s]\n', name);
    fprintf('  Range actual  : [%.6f, %.6f]\n', min_val, max_val);

    if isfi(x)
        WL = x.WordLength;
        FL = x.FractionLength;

        max_theoretical = (2^(WL-FL-1)) - 2^(-FL);
        min_theoretical = -2^(WL-FL-1);

        sat_high = sum(x_double(:) >= max_theoretical);
        sat_low  = sum(x_double(:) <= min_theoretical);
        total    = numel(x);

        fprintf('  Format        : Q%d.%d (WL=%d)\n', WL-FL, FL, WL);
        fprintf('  Range theory  : [%.6f, %.6f]\n', min_theoretical, max_theoretical);
        fprintf('  Saturation    : High=%d (%.3f%%), Low=%d (%.3f%%)\n', ...
            sat_high, 100*sat_high/total, sat_low, 100*sat_low/total);
    else
        fprintf('  Type          : Floating-point\n');
    end
end