"""
TEST LOOPBACK CP2102
====================
Cara penggunaan:
1. Hubungkan TX pin CP2102 ke RX pin CP2102 (short/loopback)
2. Jalankan skrip ini
3. Jika muncul "LOOPBACK OK", adapter CP2102 berfungsi normal
4. Lepas kabel loopback, sambungkan TX ke GPIO_0[0] FPGA

Port: Sesuaikan COM_PORT di bawah dengan port CP2102 Anda
"""
import serial
import time

COM_PORT = 'COM3'  # Ganti dengan COM port CP2102 Anda
BAUD_RATE = 115200

print(f"Membuka port {COM_PORT}...")
try:
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=2)
    time.sleep(0.2)

    test_data = b'HELLO'
    ser.write(test_data)
    time.sleep(0.1)

    received = ser.read(len(test_data))
    
    if received == test_data:
        print(f"✅ LOOPBACK OK! Terima: {received}")
        print("CP2102 berfungsi normal. Sambungkan TX ke GPIO_0[0] FPGA.")
    else:
        print(f"❌ Tidak ada loopback. Terima: {received!r}")
        print("Pastikan TX dan RX adapter sudah dihubungkan (di-short).")
    
    ser.close()
except serial.SerialException as e:
    print(f"❌ Gagal buka port: {e}")
    print("Pastikan:")
    print("  - CP2102 sudah terhubung ke PC")
    print("  - Driver terinstal (Silicon Labs CP210x)")
    print(f"  - COM port benar (saat ini: {COM_PORT})")
except Exception as e:
    print(f"Error: {e}")
