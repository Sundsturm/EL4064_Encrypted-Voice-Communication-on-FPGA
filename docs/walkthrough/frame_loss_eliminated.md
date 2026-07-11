# Eliminasi Frame Loss pada Penerima Modem DTMF

Dokumen ini mencatat pencapaian implementasi dalam mengeliminasi gejala **Frame Loss** (dari sebelumnya 100% menjadi 0%) pada perangkat keras board FPGA DE10-Standard.

---

## 1. Masalah Awal (Root Cause)
1. **Saturasi ADC Audio (WM8731):** Penguatan input mikrofon/Line-In pada I2C diset ke maksimum (`1F` / +12 dB), menyebabkan kliping sinyal audio yang merusak fasa korelasi IQ Correlator.
2. **Kegagalan Deteksi Preamble:** Akibat kliping, modul IQ Correlator tidak pernah mendeteksi pola preamble `[#, #, 3, #]`, sehingga penerima tidak pernah diaktifkan (100% Frame Loss).

---

## 2. Solusi yang Diterapkan
1. **Reduksi Gain Input I2C:** Menurunkan penguatan input di [i2c.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/i2c.vhd) ke default **`17` (0 dB)**. Sinyal audio menjadi sinusoidal bersih tanpa kliping.
2. **Penyelarasan Threshold Goertzel:** Menurunkan parameter threshold daya di komparator menjadi **`800`** (karena penurunan gain 12 dB mengurangi level daya sebesar 16 kali lipat).
3. **Penyelarasan Fasa Goertzel:** Implementasi pulsa `sync_reset` pada tepi naik `enable` untuk membersihkan akumulator Goertzel tepat setelah preamble berakhir.
4. **Penyederhanaan Jalur Penerima:** Menghapus modul FSM lama `FRAME_COLLECTOR` dan menghubungkan output Goertzel langsung ke `shift_add` yang digerakkan oleh `enable` dari IQ Correlator.

---

## 3. Hasil Pengujian Hardware (`results/log.txt`)
* **Frame Loss: 0.00%** (10 dari 10 paket kunci berhasil ditangkap secara fisik oleh penerima).
* **Word Error Rate (WER): 100.00%** (Kunci mengalami pergeseran/mismatch bit).

### Analisis Mismatch Kunci:
Berdasarkan log pengujian, kunci yang direkonstruksi (`RX Key`) selalu diawali oleh pola **`FF3F`**:
* **TX Key:** `2A593EDA` $\rightarrow$ **RX Key:** `FF3F2A53` (Preamble `#, #, 3, #` ikut tergeser masuk ke register kunci, mendorong digit payload asli keluar).
* Ini mengonfirmasi bahwa gerbang sinkronisasi `enable` atau waktu reset penggeser `shift_add` pada hardware masih mendeteksi digit preamble sebagai bagian dari payload.

---

## 4. Rencana Kerja Selanjutnya (Next Steps)
1. Menyelaraskan timing tepi deteksi `enable` dan sinyal kontrol pada modul `shift_add` di hardware nyata.
2. Memastikan pengosongan akumulator pergeseran dilakukan dengan benar saat preamble terdeteksi agar digit preamble tidak ikut masuk ke kunci 32-bit.
