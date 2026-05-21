function decode_val = decision(f_low, f_high)
% DECISION Ekivalen MATLAB dari decision.vhd
% Menerima frekuensi low dan high, lalu mendekodenya menjadi nilai integer 3-bit.

    decode_val = 0; % Default fallback
    
    if f_low == 697 && f_high == 1209
        decode_val = 0; % 000 (DTMF '1')
    elseif f_low == 697 && f_high == 1336
        decode_val = 1; % 001 (DTMF '2')
    elseif f_low == 770 && f_high == 1209
        decode_val = 2; % 010 (DTMF '4')
    elseif f_low == 770 && f_high == 1336
        decode_val = 3; % 011 (DTMF '5')
    elseif f_low == 852 && f_high == 1209
        decode_val = 4; % 100 (DTMF '7')
    elseif f_low == 852 && f_high == 1336
        decode_val = 5; % 101 (DTMF '8')
    elseif f_low == 941 && f_high == 1209
        decode_val = 6; % 110 (DTMF '*')
    elseif f_low == 941 && f_high == 1336
        decode_val = 7; % 111 (DTMF '0')
    else
        warning('Peringatan: Pasangan frekuensi DTMF tidak dikenali (Low: %d, High: %d)', f_low, f_high);
    end
    
    % --- Log Keluaran ---
    fprintf('  -> [Decision] Nilai Dekode (3-bit): %d (biner: %s)\n', decode_val, dec2bin(decode_val, 3));
end
