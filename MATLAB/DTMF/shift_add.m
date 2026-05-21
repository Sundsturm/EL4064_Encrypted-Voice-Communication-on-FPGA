function new_key = shift_add(current_key, decode_val)
% SHIFT_ADD Ekivalen MATLAB dari shift_add.vhd
% Menerima kunci akumulasi saat ini dan bit terbaru, kemudian menggeser
% kunci 3-bit ke kiri dan menambahkan nilai bit terbaru.

    % Geser ke kiri 3 bit
    shifted_key = bitshift(uint32(current_key), 3);
    
    % Tambahkan dengan nilai dekode 3-bit terbaru
    new_key = shifted_key + uint32(decode_val);
    
    % --- Log Keluaran ---
    fprintf('  -> [Shift-Add] Akumulasi Kunci  : %s (Hex)\n', dec2hex(new_key, 6));
end
