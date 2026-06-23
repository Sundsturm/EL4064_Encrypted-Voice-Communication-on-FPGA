# PROJECT SYSTEM CONTEXT & UNIVERSAL ALIGNMENT FOR AI AGENT IDE
## Proyek: Simplex Voice-Band Modem 32-Bit Berbasis FPGA Cyclone V

---

## 1. METADATA PROYEK & AKADEMIK
- **Mata Kuliah:** EL4064 Penelitian Rekayasa (Teknik Elektro ITB).
- **Dosen Pembimbing:** Prof. Ir. Arif Sasongko, S.T, M.T, Ph.D.
- **Tim Rekayasa:**
  * Rafi Ananta Alden (13222087) — Penanggung Jawab Sisi Pengirim (TX), I/O & Penampil Hardware.
  * Kean Malik Aji Santoso (13222083) — Penanggung Jawab Sisi Penerima (RX), Sinkronisasi Bingkai & DSP.
- **Baseline Proyek Legacy:** Kelompok TA2324.02.005 (Desain Pengacak Sinyal Suara berbasis FFT & Pertukaran Kunci DTMF-Goertzel).

---

## 2. REVISI ARSITEKTUR TOTAL (PIVOT STRATEGIS)
Atas instruksi dosen pembimbing, sistem pengamanan suara (FFT/Kriptografi) senior terdahulu **DIHAPUS TOTAL** karena ketidakstabilan hardware loopback dan *timing domain crossing* yang buruk. 
Sistem dialihkan murni menjadi **Sistem Transmisi Data Digital Satu Arah (Simplex Voice-Band Modem)** yang memanfaatkan saluran pita suara analog/VoIP untuk mengirimkan paket kunci digital secara deterministik.

---

## 3. PARAMETER TEKNIS DETERMINISTIK (MANDATORI)
Setiap pengerjaan penulisan kode RTL (VHDL) maupun pemodelan DSP (MATLAB) wajib mematuhi parameter berikut:
- **Frekuensi Sampling ($f_s$):** Tepat 32000 Hz.
- **Lebar Data Payload Kunci:** 32-bit (Diperluas dari versi 24-bit milik senior).
- **Modulasi Sinyal:** DTMF Kontinu Berbasis Standar ITU-T 16-Simbol ($0\text{-}9, \text{A}\text{-}\text{D}, *, \#$).
- **Matriks Frekuensi Simbol:**
  * *Low Group:* 697 Hz, 770 Hz, 852 Hz, 941 Hz.
  * *High Group:* 1209 Hz, 1336 Hz, 1477 Hz, 1633 Hz.
  * *Simbol Khusus Kolom 4 (1633 Hz):* Mengaktifkan simbol 'A', 'B', 'C', dan 'D' untuk melengkapi data 4-bit per nada.
- **Durasi per Nada/Simbol:** Tepat 20 milidetik ($20\text{ ms} = 640\text{ sampel}$ pada laju 32 kHz).
- **Sifat Transisi Transmisi:** **Continuous Handshake Blast (Murni Tanpa Jeda Diam/Silence Period).**

---

## 4. PROTOKOL FRAMING UTUH MODEM (PACKET STRUCTURE)
Satu kali siklus penembakan data (*burst blast*) terdiri dari total **12 buah simbol berurutan (Durasi Total: 240 ms / 7680 sampel)** dengan susunan:
$$\text{Struktur Bingkai Sinyal:} \quad [\underbrace{\#, \#, 3, \#}_{\text{Preamble (80 ms)}}] \rightarrow [\underbrace{K_1, K_2, K_3, K_4, K_5, K_6, K_7, K_8}_{\text{Payload 32-bit (160 ms)}}]$$

- **Fungsi Preamble:** Sinkronisasi awal bingkai bagi penerima untuk mengunci ketukan awal ($T=0$).
- **Fungsi Payload:** 8 buah simbol berturut-turut di mana tiap simbol membawa nilai heksadesimal 4-bit ($8 \times 4\text{ bit} = 32\text{-bit kunci terkirim}$).

---

## 5. ATURAN REKAYASA FISIK PERANGKAT KERAS (BOARD ALIGNMENT)

### A. Mekanisme Penyadapan Paralel Sinyal (Sisi Penerima)
Data audio digital yang berasal dari Audio ADC (`Lin` / `Rin`) pada chip codec Wolfson WM8731 milik board penerima dicabangkan secara bersamaan (*concurrent assignment*) ke dua jalur silikon independen:
1. **Jalur Loopback Fisik Passthrough:** Bus data ADC langsung dilempar ke register Audio DAC (`Lout` / `Rout`) tanpa hambatan sekuensial agar nada modem dapat langsung terdengar berbunyi nyaring di speaker laboratorium secara *real-time*.
2. **Jalur Pemrosesan DSP:** Bus data yang sama mengalir simultan ke modul *In-Phase Quadrature Preamble Detector* dan rantai filter komputasi Goertzel di latar belakang.

### B. Isolasi Aliran Sinyal Sisi Pengirim (Transmitter Audio Isolation)
- Selama proses pemancaran data berlangsung (`tx_active = '1'`), jalur masukan audio mikrofon/line-in (`Lin`) wajib **di-mute total (diputus)** dari pencampuran DAC output. Hal ini penting untuk mencegah infiltrasi derau bising lingkungan laboratorium (*ambient noise*) yang dapat merusak kemurnian amplitudo sinus DTMF pengirim.

### C. Solusi Sinkronisasi Penerima (Periodic Boundary Sampler)
- Penerima mengatasi ketiadaan jeda sunyi (*no silence period*) dengan menyalakan sebuah **Periodic Counter**. Begitu preamble `#,\#,3,\#` dikenali, sistem mengunci titik $T=0$.
- Pengambilan keputusan biner (pencuplikan data Goertzel) dilakukan secara paksa tepat di **titik tengah/sampel tengah jendela simbol** untuk mencegah interferensi antar-simbol (*Inter-Symbol Interference* / ISI) dan toleran terhadap pergeseran fasa fisis (*clock drift*).
$$\text{Formula Titik Cuplik (Latching Index):} \quad \text{index} = \text{sync_lock_index} + 320 + (N \times 640) \quad \text{untuk } N = 0 \text{ s.d } 7$$

### D. Trik Penampil Visual (Bank-Switching Display Multiplexing)
Board DE10-Standard hanya memiliki 6 buah display Seven-Segment (`HEX0` s.d `HEX5`), sedangkan representasi data 32-bit heksadesimal membutuhkan total 8 buah display. Masalah keterbatasan *resource* fisik ini diatasi menggunakan metode *bank-switching* dikendalikan Slide Switch `SW(0)`:
- **Kondisi `SW(0) = '0'` (LSB Mode):** Menampilkan 24-bit data terbawah (6 digit heksadesimal terbawah). Bit terendah terkunci pada display paling kanan (`HEX0`).
- **Kondisi `SW(0) = '1'` (MSB Mode):** Menampilkan 8-bit data teratas (2 digit heksadesimal teratas) pada display `HEX5` dan `HEX4`. Sisa display (`HEX3` s.d `HEX0`) dipaksa menampilkan karakter strip/minus (`-`) dengan memicu nilai biner `Active-Low` `7'b1111110`.

---

## 6. MEKANISME PEMICU GANDA (DUAL-TRIGGER DESIGN)
Sistem top-level pada `AcakCakap_Top.vhd` wajib merangkai gerbang pemicu `OR` kombinasional-sekuensial untuk memulai sekuens *blast* pengiriman:
1. **Pemicu Hardware:** Melalui penekanan tombol fisik `KEY(1)` yang mendeteksi sinyal *falling-edge* sinkron (beralih dari `'1'` ke `'0'`).
2. **Pemicu Software:** Melalui penerimaan byte instruksi valid (Contoh: `X"53"` atau karakter 'S') dari interupsi register UART PC.

---

## 7. STRUKTUR SIMULASI TESTBENCH LOOPBACK MANDATORI
Semua testbench integrasi menyeluruh (`tb_modem_top_integration.v`) wajib menghubungkan port serial DAC data keluar (`AUD_DACDAT`) milik modulator kembali masuk secara fisis asinkron ke dalam port serial ADC data masuk (`AUD_ADCDAT`) milik demodulator. Di akhir simulasi, jalankan fungsi pemantau makro *assertion* otomatis untuk membuktikan status **PASS (Zero Bit Errors)**.
