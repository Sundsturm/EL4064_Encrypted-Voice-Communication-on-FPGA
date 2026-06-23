
# Garis Besar Laporan Penelitian Akhir

## 1. Masalah (Problem Statement)
*   **1.1. Latar Belakang & Baseline Senior:** Penjelasan mengenai sistem legacy pengacak sinyal suara berbasis FFT & pertukaran kunci DTMF-Goertzel (Kelompok TA2324.02.005).
*   **1.2. Masalah Teknis Utama:** Mengapa sistem terdahulu tidak stabil (isu *loopback* fisik pada *hardware* dan masalah *timing domain crossing*).
*   **1.3. Pivot Solusi:** Pengalihan fokus menjadi sistem transmisi data digital satu arah (*Simplex Voice-Band Modem*) untuk pengiriman paket kunci 32-bit secara deterministik melalui saluran suara analog/VoIP.
*   **1.4. Batasan & Tantangan Rekayasa:** 
    *   Ketiadaan jeda sunyi (*no silence period*) pada transisi simbol (*Continuous Handshake Blast*).
    *   Pengaruh derau lingkungan (*ambient noise*) di sisi pengirim.
    *   Keterbatasan tampilan visual fisik board DE10-Standard (hanya memiliki 6 penampil 7-segment untuk data 32-bit).

## 2. Spesifikasi (Specification)
*   **2.1. Parameter Sinyal Masukan/Keluaran:** Frekuensi sampling ($f_s$) tepat 32 kHz, format audio ditapis/diisolasi.
*   **2.2. Protokol Modulasi & Matriks Nada:** Modulasi DTMF kontinu berbasis standar ITU-T 16-Simbol ($0\text{-}9, \text{A}\text{-}\text{D}, *, \#$) menggunakan *Low Group* (697–941 Hz) dan *High Group* (1209–1633 Hz).
*   **2.3. Struktur Bingkai Sinyal (Framing):** 12 simbol berurutan (durasi total 240 ms / 7680 sampel pada 32 kHz):
    *   *Preamble:* `[#, #, 3, #]` (80 ms) untuk sinkronisasi awal.
    *   *Payload:* `[K1 s.d. K8]` (160 ms) membawa data kunci 32-bit (4-bit per simbol).
*   **2.4. Kriteria Keberhasilan:** Transmisi dengan *Bit Error Rate* (BER) 0% pada simulasi *loopback* digital asinkron, sinkronisasi fasa tahan terhadap *clock drift*, serta penayangan visual yang benar di board.

## 3. Rancangan (System Design)
*   **3.1. Arsitektur Top-Level:** Diagram blok keseluruhan sistem pada [AcakCakap_Top.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/AcakCakap_Top.vhd).
*   **3.2. Perancangan Sisi Pengirim (Transmitter - TX):**
    *   *Pemicu Ganda (Dual-Trigger):* Integrasi pemicu tombol fisik `KEY(1)` dan UART dari PC (`0x53` / 'S').
    *   *Generator DTMF:* Modul generator gelombang sinus digital berbasis tabel pencarian/interpolasi pada [sine_gen_signed.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/sender_hdl/sine_gen_signed.vhd) dan modulator [generate_dtmf_signed.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/sender_hdl/generate_dtmf_signed.vhd).
    *   *Isolasi Audio:* Desain pemutusan otomatis (*mute*) jalur mikrofon saat pemancaran aktif (`tx_active = '1'`) untuk mencegah infiltrasi *ambient noise*.
*   **3.3. Perancangan Sisi Penerima (Receiver - RX):**
    *   *Parallel Tapping:* Pembagian jalur data ADC dari codec Wolfson WM8731 ke DAC (*passthrough loopback* instan) dan unit pemrosesan DSP secara simultan.
    *   *Detektor Preamble & Sinkronisasi:* Struktur *In-Phase Quadrature Preamble Detector* untuk mengunci $T=0$.
    *   *Pencuplikan Berkala (Latching):* Formula matematis penentuan titik tengah cuplikan untuk menghindari *Inter-Symbol Interference* (ISI):
        $$\text{index} = \text{sync\_lock\_index} + 320 + (N \times 640)$$
    *   *Demodulator DSP:* Bank filter Goertzel untuk mendeteksi 8 frekuensi nada DTMF pada [Goertzel.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/dtmf_detect_hdl/Goertzel.vhd).
*   **3.4. Rancangan Penampil Visual (Bank-Switching):** Metode multiplexing tampilan 32-bit ke 6 panel Seven-Segment menggunakan pemilih Slide Switch `SW(0)` (LSB Mode vs MSB Mode).

## 4. Implementasi (Implementation)
*   **4.1. Implementasi RTL VHDL:** Penjelasan detail mengenai pemetaan *port* dan FSM pengendali di modul utama serta sub-komponen seperti [toplevel_iq.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/receiver_hdl/toplevel_iq.vhd) dan [Framingv2.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/receiver_hdl/Framingv2.vhd).
*   **4.2. Konfigurasi Codec Audio & PLL:** Integrasi antarmuka I2C untuk konfigurasi register WM8731 serta pemanfaatan IP Altera PLL untuk clocking audio 18.432 MHz.
*   **4.3. Konversi Floating-to-Fixed Point:** Penerapan pustaka `ieee_proposed.fixed_pkg` untuk komputasi DSP real-time pada filter Goertzel.

## 5. Hasil & Analisis (Results & Analysis)
*   **5.1. Simulasi Testbench Integrasi:** Hasil pengujian menggunakan file [tb_dtmf_integration.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/tb_dtmf_integration.vhd) yang membuktikan kembalinya data kunci 32-bit tanpa galat (*Zero Bit Errors*).
*   **5.2. Analisis Sinkronisasi & Latching:** Pembuktian ketahanan algoritma deteksi preamble terhadap pergeseran fasa dan ISI.
*   **5.3. Analisis Fungsionalitas Hardware:** Hasil pengujian fisik *bank-switching* visual 7-segment dan pemicu ganda (UART & KEY).
*   **5.4. Pemanfaatan Sumber Daya (Resource Utilization):** Laporan jumlah Logic Elements (LEs), Registers, dan blok multiplier DSP yang terpakai pada Cyclone V.

## 6. Kesimpulan (Conclusion)
*   **6.1.** Pencapaian target desain berupa sistem transmisi kunci digital 32-bit simplex melalui saluran suara analog dengan andal.
*   **6.2.** Validasi performa sistem yang menunjukkan tingkat keberhasilan deteksi preamble dan pengenalan nada DTMF pada laju sampling 32 kHz tanpa adanya galat bit dalam kondisi uji coba *loopback*.

## 7. Saran (Future Work)
*   **7.1.** Implementasi pengodean koreksi galat (misalnya *Hamming Code* atau *Reed-Solomon*) untuk memperkuat keandalan data pada media transmisi fisik yang memiliki derau tinggi (*noisy channels*).
*   **7.2.** Pengembangan sistem ke arah komunikasi dua arah (*Full Duplex Modem*).
*   **7.3.** Optimasi penggunaan memori/blok DSP filter Goertzel agar dapat diimplementasikan pada FPGA dengan kapasitas lebih kecil.

## 8. Referensi (References)
*   Standar ITU-T Q.23 & Q.24 untuk spesifikasi teknis dan batasan penerimaan DTMF.
*   Dokumentasi teknis board DE10-Standard System CD dan codec Wolfson WM8731.
*   Pustaka akademik terkait algoritma Goertzel untuk analisis spektral resolusi tinggi yang efisien pada FPGA.