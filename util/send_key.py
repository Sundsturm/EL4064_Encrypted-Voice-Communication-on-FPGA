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

try:
    # Membuka koneksi port serial
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
    time.sleep(0.5) # Tunggu inisialisasi koneksi
    
    # Payload kunci dinamis: 0x3A7C9B1D + 0x0A (Line Feed = trigger transmisi)
    # Urutan byte: MSB dulu, diakhiri 0x0A sebagai trigger
    # payload = bytes([0x3A, 0x7C, 0x9B, 0x1D, 0x0A])
    key = random.randint(0x00000000, 0xFFFFFFFF)
    payload = key.to_bytes(4, byteorder='big') + b'\x0a'
    
    # print("Mengirim kunci dinamis via CP2102 ke {COM_PORT} (Key: 0x{key:08X})...")
    print(f"Mengirim kunci dinamis via CP2102 ke {COM_PORT} (Key: 0x{key:08X})...")
    ser.write(payload)
    ser.flush()
    print("Kunci dinamis berhasil dikirim!")
    
    ser.close()
except Exception as e:
    print(f"Gagal mengirim data: {e}")