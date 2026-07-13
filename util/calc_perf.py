import os
import sys

def get_file_path(filename, default_dir):
    """Mendapatkan path absolut file, baik dijalankan dari root maupun folder util."""
    # Coba relatif terhadap direktori kerja saat ini
    path1 = os.path.abspath(filename)
    if os.path.exists(path1):
        return path1
    
    # Coba relatif terhadap direktori skrip ini
    script_dir = os.path.dirname(os.path.abspath(__file__))
    path2 = os.path.abspath(os.path.join(script_dir, "..", default_dir, os.path.basename(filename)))
    if os.path.exists(path2):
        return path2
        
    return path1

class DualLogger(object):
    def __init__(self, filepath):
        self.terminal = sys.stdout
        self.log = open(filepath, "w", encoding="utf-8")

    def write(self, message):
        self.terminal.write(message)
        self.log.write(message)

    def flush(self):
        self.terminal.flush()
        self.log.flush()

    def close(self):
        self.log.close()

def hex_to_bin_str(hex_char):
    """Mengubah karakter heksadesimal ke string biner 4-bit."""
    try:
        val = int(hex_char, 16)
        return f"{val:04b}"
    except ValueError:
        return "1111"  # Jika karakter tidak valid, asumsikan semua bit salah

def calculate_metrics(tx_path, rx_path):
    log_dir = os.path.dirname(rx_path) if os.path.dirname(rx_path) else "."
    log_path = os.path.join(log_dir, "log.txt")
    
    logger = DualLogger(log_path)
    original_stdout = sys.stdout
    sys.stdout = logger
    
    try:
        print("======================================================================")
        print("  KALKULATOR PERFORMA MODEM DTMF (WER, SER, BER, FRAME LOSS)")
        print("======================================================================")
        
        if not os.path.exists(tx_path):
            print(f"Error: File TX tidak ditemukan di {tx_path}")
            return
        if not os.path.exists(rx_path):
            print(f"Error: File RX tidak ditemukan di {rx_path}")
            return
            
        print(f"Membaca file TX: {tx_path}")
        print(f"Membaca file RX: {rx_path}\n")

        with open(tx_path, 'r') as f:
            tx_lines = [line.strip().upper() for line in f if line.strip()]
            
        with open(rx_path, 'r') as f:
            rx_lines = [line.strip().upper() for line in f if line.strip()]

        num_pairs = min(len(tx_lines), len(rx_lines))
        if len(tx_lines) != len(rx_lines):
            print(f"⚠️ Peringatan: Jumlah baris tidak sama! (TX: {len(tx_lines)} baris, RX: {len(rx_lines)} baris)")
            print(f"Analisis akan dibatasi pada {num_pairs} baris pertama.\n")

        total_keys = num_pairs
        failed_keys = 0
        
        total_symbols = 0
        failed_symbols = 0
        
        total_bits = 0
        failed_bits = 0
        
        frame_losses = 0

        print(f"{'No.':<4} | {'TX Key':<10} | {'RX Key':<10} | {'Key Match':<10} | {'Sym Errors':<10} | {'Bit Errors':<10} | {'Frame Loss':<10}")
        print("-" * 82)

        for i in range(num_pairs):
            tx_key = tx_lines[i]
            rx_key = rx_lines[i]
            
            # Cek apakah persis sama
            key_match = tx_key == rx_key
            if not key_match:
                failed_keys += 1
                
            # Identifikasi frame loss (kunci diterima sama dengan iterasi sebelumnya)
            is_frame_loss = False
            if i > 0:
                if rx_key == rx_lines[i-1]:
                    is_frame_loss = True
                    frame_losses += 1
                
            # Hitung kesalahan simbol dan bit
            max_len = max(len(tx_key), len(rx_key))
            
            word_sym_err = 0
            word_bit_err = 0
            
            for pos in range(max_len):
                tx_char = tx_key[pos] if pos < len(tx_key) else None
                rx_char = rx_key[pos] if pos < len(rx_key) else None
                
                if tx_char is not None and rx_char is not None:
                    total_symbols += 1
                    total_bits += 4
                    
                    if tx_char != rx_char:
                        word_sym_err += 1
                        
                        # Hitung perbedaan bit
                        tx_bin = hex_to_bin_str(tx_char)
                        rx_bin = hex_to_bin_str(rx_char)
                        bit_diffs = sum(1 for b1, b2 in zip(tx_bin, rx_bin) if b1 != b2)
                        word_bit_err += bit_diffs
                else:
                    # Salah satu kosong (panjang tidak sama)
                    total_symbols += 1
                    total_bits += 4
                    word_sym_err += 1
                    word_bit_err += 4  # Asumsikan seluruh 4-bit salah jika karakter hilang/lebih
                    
            failed_symbols += word_sym_err
            failed_bits += word_bit_err
            
            match_str = "OK" if key_match else "MISMATCH"
            loss_str = "LOSS" if is_frame_loss else "-"
            print(f"{i+1:<4} | {tx_key:<10} | {rx_key:<10} | {match_str:<10} | {word_sym_err:<10} | {word_bit_err:<10} | {loss_str:<10}")

        print("-" * 82)
        
        # Kalkulasi Persentase
        wer = (failed_keys / total_keys) * 100 if total_keys > 0 else 0
        ser = (failed_symbols / total_symbols) * 100 if total_symbols > 0 else 0
        ber = (failed_bits / total_bits) * 100 if total_bits > 0 else 0
        flr = (frame_losses / (total_keys - 1)) * 100 if total_keys > 1 else 0

        print("\n================== RINGKASAN METRIK PERFORMA ==================")
        print(f"Total Kunci/Word yang Diuji : {total_keys}")
        print(f"Kunci Salah (Word Errors)   : {failed_keys} paket")
        print(f"Word Error Rate (WER)       : {wer:.2f} %")
        print("-" * 47)
        print(f"Total Simbol/Digit Diuji    : {total_symbols} digit")
        print(f"Simbol Salah (Sym Errors)   : {failed_symbols} digit")
        print(f"Symbol Error Rate (SER)     : {ser:.2f} %")
        print("-" * 47)
        print(f"Total Bit Data Diuji        : {total_bits} bit")
        print(f"Bit Salah (Bit Errors)      : {failed_bits} bit")
        print(f"Bit Error Rate (BER)        : {ber:.2f} %")
        print("-" * 47)
        print(f"Total Frame Loss (Hold-over): {frame_losses} paket")
        print(f"Frame Loss Rate             : {flr:.2f} %")
        print("===============================================================\n")
        
    finally:
        sys.stdout = original_stdout
        logger.close()
        print(f"Log berhasil diekspor ke: {log_path}")

if __name__ == "__main__":
    # Menentukan path file input
    tx_file = get_file_path("TX.txt", "hdl/results")
    rx_file = get_file_path("RX.txt", "hdl/results")
    
    calculate_metrics(tx_file, rx_file)