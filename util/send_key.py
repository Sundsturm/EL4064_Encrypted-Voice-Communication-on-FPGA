import serial
import time
import random

# =========================================================
# KONFIGURASI PORT SERIAL
# =========================================================
# PENTING: Gunakan COM port dari adapter CP2102 (bukan USB Mini-B board!)
# USB Mini-B board (COM7) terhubung ke HPS, BUKAN ke FPGA fabric.
#
# Koneksi fisik CP2102:
#   CP2102 TX  -->  GPIO_0[0] (PIN_AC18, pin pertama header GPIO_0 papan pengirim)
#   CP2102 GND -->  GND header GPIO_0
#
# Cek COM port CP2102 di Device Manager:
#   Device Manager > Ports (COM & LPT) > Silicon Labs CP210x USB to UART Bridge
#
# Ganti 'COM3' di bawah dengan nomor COM port CP2102 Anda:
COM_PORT = 'COM3'
BAUD_RATE = 115200

# Mode pengiriman kunci: 'hardcoded' atau 'random'
KEY_MODE = 'random'

try:
    # Membuka koneksi port serial
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
    time.sleep(0.5) # Tunggu inisialisasi koneksi
    
    # Payload kunci dinamis: diakhiri 0x0A sebagai trigger (Line Feed)
    # Urutan byte: MSB dulu
    if KEY_MODE == 'hardcoded':
        key = 0x3A7C9B1D
        # payload = bytes([0x3A, 0x7C, 0x9B, 0x1D, 0x0A])
        payload = bytes([0x12, 0x34, 0x56, 0x78, 0x0A])
        print(f"Mengirim kunci dinamis via CP2102 ke {COM_PORT} (Key: 0x{key:08X}, Mode: {KEY_MODE})...")
    else:
        key = 0
        payload = b''
        print(f"Mengirim kunci dinamis via CP2102 ke {COM_PORT} (Mode: {KEY_MODE})...")
    
    # =========================================================
    # AUTO-RETRANSMIT: Kirim 2x dengan jeda 350ms
    # =========================================================
    # Masalah: Window Goertzel penerima berjalan dengan fase acak
    # relatif terhadap awal transmisi. Trigger pertama bisa saja
    # terpotong di tengah window sehingga preamble ##3# tidak terdeteksi.
    # Solusi: Kirim ulang setelah satu transmisi penuh selesai (~240ms).
    # =========================================================
    RETRANSMIT_COUNT = 10       # Jumlah pengiriman
    RETRANSMIT_DELAY = 1       # Jeda antar pengiriman (> 240ms = 12 simbol × 20ms)
    
    for i in range(RETRANSMIT_COUNT):
        if KEY_MODE == 'random':
            key = random.randint(0x00000000, 0xFFFFFFFF)
            payload = key.to_bytes(4, byteorder='big') + b'\x0a'
            print(f"  Paket ke-{i+1}/{RETRANSMIT_COUNT} dikirim (Key: 0x{key:08X}).")
        else:
            print(f"  Paket ke-{i+1}/{RETRANSMIT_COUNT} dikirim.")
            
        ser.write(payload)
        ser.flush()
        if i < RETRANSMIT_COUNT - 1:
            time.sleep(RETRANSMIT_DELAY)  # Tunggu transmisi DTMF selesai
    
    print("Selesai.")
    
    ser.close()
except Exception as e:
    print(f"Gagal mengirim data: {e}")