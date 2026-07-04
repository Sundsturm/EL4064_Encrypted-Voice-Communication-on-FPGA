# Walkthrough: Goertzel Free-Running dengan FSM Timeout 300ms (Opsi A)

Dokumen ini merangkum detail implementasi dan analisis performa dari **Opsi A** (Preamble Penuh + FSM Timeout 300 ms) pada modem penerima DTMF di FPGA.

---

## 1. Deskripsi Masalah Awal & Pendekatan Opsi A

Sebelumnya, pengujian dengan **Preamble Bypass via Enable Gating** menghasilkan **100% Word Error Rate (WER)** karena FSM langsung masuk ke pengumpulan payload tanpa verifikasi preamble, menyebabkan sisa nada preamble ikut terbaca sebagai payload (*serial shift* / pergeseran frame).

Sebagai solusinya, **Opsi A** menerapkan pendekatan hibrida:
1. **Preamble Penuh (`##3#`):** Mengembalikan verifikasi preamble secara penuh di dalam FSM `top_dtmfencode.vhd`. Hal ini menjamin penyelarasan frame yang sempurna (**0% Serial Shift**).
2. **Goertzel Free-Running:** Menghilangkan gerbang kontrol `enable` dengan memetakan port `enable => '1'` dan parameter generic `SIM_MODE => true` agar Goertzel terus-menerus memproses sampel audio.
3. **Robust FSM Timeout (300 ms):** Menambahkan register timeout `frame_timeout` sebesar **300 ms** (5.529.600 siklus clock `AUD_XCK` @ 18.432 MHz). Jika derau (noise) tidak sengaja memicu status FSM di luar `WAIT_HASH`, FSM akan pulih (*self-healing*) dan kembali ke state awal dalam 300 ms, menjamin penerima siap ketika paket kunci asli tiba.

---

## 2. Ringkasan Hasil Pengujian (Opsi A)

Pengujian dilakukan dengan mengirimkan 20 kunci acak menggunakan utilitas penguji `send_key.py` (jeda hening 10 detik). Hasil pengujian direkam di [log.txt (Opsi A)](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/results/log.txt).

### Metrik Performa
* **Word Error Rate (WER):** **45.00 %** (11 dari 20 kunci sukses didekode 100% sempurna).
* **Symbol Error Rate (SER):** **18.75 %** (30 dari 160 digit salah).
* **Bit Error Rate (BER):** **9.22 %** (59 dari 640 bit salah).
* **Frame Loss Rate:** **15.79 %** (3 paket mengalami *stuck*/*hold-over* kunci lama pada paket 9, 14, dan 15).

### Analisis & Hasil Positif
1. **Keberhasilan Dekode Sempurna:** Sebanyak 11 paket berhasil didekode secara **100% OK** tanpa ada kesalahan simbol sama sekali.
2. **Koreksi Mismatch Tanpa Pergeseran:** Pada paket-paket yang mengalami mismatch (seperti paket 5, 6, 7, 18, 19, 20), data didekode dalam posisi selaras sempurna (*perfectly aligned*) dengan jumlah kesalahan simbol yang sangat minim (hanya 1 sampai 3 digit salah).
3. **Pengurangan Frame Loss:** Tingkat *Frame Loss* turun menjadi **15.79%** (dari sebelumnya 63% saat menggunakan timeout agresif 20 ms), membuktikan timeout 300 ms berhasil mencegah false-reset di tengah jalan.

---

## 3. Limitasi & Rencana Selanjutnya

Meskipun performa meningkat pesat, sisa **15.79% Frame Loss** (paket 9, 14, dan 15) teridentifikasi disebabkan oleh **Goertzel Block Misalignment**. Karena Goertzel berjalan bebas, batas blok 20 ms (640 sampel) dapat bergeser secara acak terhadap simbol DTMF yang datang. Hal ini membagi energi simbol ke dua blok berbeda (*energy splitting*), menurunkan SNR sebesar 3 dB, dan menyebabkan kegagalan deteksi preamble pada kondisi derau.

Langkah selanjutnya yang direncanakan adalah menerapkan **Goertzel Phase-Alignment via IQ Preamble Trigger** untuk me-reset counter Goertzel tepat di akhir preamble agar selaras sempurna 100% dengan payload.
