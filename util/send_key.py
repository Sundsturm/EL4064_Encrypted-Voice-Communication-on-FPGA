import serial
import time

# GANTI 'COM3' dengan port serial USB-to-UART papan pengirim (TX) Anda
# Anda bisa mengecek nomor COM port di Device Manager Windows
COM_PORT = 'COM3' 
BAUD_RATE = 115200

try:
    # Membuka koneksi port serial
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
    time.sleep(1) # Tunggu inisialisasi koneksi
    
    # Payload kunci dinamis: 0x3A7C9B1D + 0x0A (Line Feed trigger)
    payload = bytes([0x3A, 0x7C, 0x9B, 0x1D, 0x0A])
    
    print(f"Mengirim kunci dinamis ke {COM_PORT}...")
    ser.write(payload)
    print("Kunci dinamis berhasil dikirim!")
    
    ser.close()
except Exception as e:
    print(f"Gagal mengirim data: {e}")
