# **Rencana Kerja Akhir (Revisi): *Voice-Band Modem* DTMF (D-13 s.d 9 Juni 2026\)**

**Proyek:** Desain dan Implementasi *Voice-Band Modem* Berbasis FPGA menggunakan Sekuens DTMF Kontinu

**Tim:** Rafi Ananta Alden (13222087) & Kean Malik Aji Santoso (13222083)

**Dosen Pembimbing:** Prof. Ir. Arif Sasongko, S.T, M.T, Ph.D.

## **I. Arsitektur Sistem & Spesifikasi Antarmuka I/O**

`[ SISI PENGIRIM (TX) - Alden ]`

`+------------------+     +-------------------+     +------------------+`

`| PC / Tombol KEY  | --> | FSM Generator TX  | --> | Audio Codec DAC  | --> Kabel Jack/VoIP`

`| (Trigger Blast)  |     | (32-bit Key, DTMF)|     | (Play Out Tone)  |`

`+------------------+     +-------------------+     +------------------+`

                                    `||`

                                    `v`

                         `[ KANAL VOICE-BAND / VoIP ]`

                                    `||`

                                    `v`

`[ SISI PENERIMA (RX) - Bareng ]`

                         `+-------------------+`

                         `|  Audio Codec ADC  | (Disadap Paralel)`

                         `| (WM8731 @ 32 kHz) |`

                         `+-------------------+`

                                   `|`

                `+------------------+------------------+`

                `| (Alden's Loopback)                   | (Kean's DSP)`

                `v                                     v`

     `+--------------------+                 +--------------------+`

     `|  Audio Codec DAC   |                 | Goertzel Detector  |`

     `| (Bunyi Nada Riil)  |                 | (Pattern Match RX) |`

     `+--------------------+                 +--------------------+`

                `|                                     |`

             `Speaker                                  v`

                                            `+--------------------+`

                                            `| Periodic Sampler   |`

                                            `+--------------------+`

                                                      `|`

                                                      `v`

                                            `+--------------------+`

                                            `|   Shift-Add 32-bit |`

                                            `+--------------------+`

                                                      `| (Kunci Rekonstruksi)`

                                                      `v`

                                            `+--------------------+`

                                            `|   Alden's HEX0-5    | (Multiplex via SW0)`

                                            `|   (32-bit Display) |`

                                            `+--------------------+`

## **II. Lini Masa & Pembagian Kerja Detil (27 Mei \- 9 Juni 2026\)**

### **FASE 1: Pemodelan MATLAB & Sinkronisasi (27 Mei \- 30 Mei)**

*Target: Validasi fungsionalitas algoritma boundary sampling secara simulasi.*

* **Alden (TX Generator):**  
  * Membuat skrip generator gelombang DTMF kontinu (modulasi 16-simbol) tanpa jeda sunyi (*silence gap*) dengan durasi 20 ms per nada.  
* **Kean (RX Receiver & Sync):**  
  * Membuat algoritma deteksi Preamble \#, \#, 3, \# menggunakan korelasi silang / demodulator kuadratur IQ.  
  * Mengembangkan logika *Periodic Sampler* yang mencuplik energi Goertzel tepat di perbatasan sampel tengah (sampel ke-320 \+ N\*640).  
* **Bersama (Integrasi MATLAB):**  
  * Menggabungkan file pengirim dan penerima di MATLAB. Menguji dengan memberikan sinyal derau. Memastikan transmisi 32-bit kunci pulih dengan BER \= 0%.

### **FASE 2: Penulisan RTL VHDL di IDE (31 Mei \- 3 Juni)**

*Target: Penyuntingan kode VHDL mandiri sesuai porsi kerja masing-masing.*

* **Alden (Audio, TX RTL, & HEX0-5):**  
  * Menulis atau memodifikasi generate\_dtmf\_signed.vhd untuk mendukung 16 simbol DTMF (frekuensi baris/kolom penuh) dan FSM *blast* kontinu.  
  * Membuat logika *multiplexing* untuk Seven-Segment DE10-Standard (HEX0 s.d HEX5) dikendalikan oleh SW(0) untuk menampilkan register kunci 32-bit:  
    * SW(0) \= '0' → Menampilkan 24-bit LSB (6 digit heksadesimal terbawah).  
    * SW(0) \= '1' → Menampilkan 8-bit MSB (2 digit heksadesimal teratas \+ 4 digit kosong \----).  
  * Mengatur kontrol pemicu (*trigger*) pengiriman lewat push-button KEY(1) atau via UART PC.  
* **Kean (DSP & RX Sync RTL):**  
  * Memperbarui filter Goertzel di FPGA agar mampu mendeteksi 16 simbol DTMF secara kontinu.  
  * Membuat FSM pendeteksi preamble \#, \#, 3, \# di Framingv2.vhd / toplevel\_iq.vhd.

### **FASE 3: Simulasi ModelSim & Integrasi Top-Level (4 Juni \- 5 Juni)**

*Target: Mengawinkan modul TX Alden dan RX Kean dalam satu testbench fungsional.*

* **Bersama (Top-Level Integration):**  
  * Mengintegrasikan AcakCakap\_Top.vhd yang baru tanpa modul FFT.  
  * Menghubungkan output generator Farhan langsung ke detektor Kean di simulasi.  
  * Membuat testbench komprehensif untuk menyimulasikan laju data asinkron dari codec.  
  * Memastikan seluruh bit kunci sukses berpindah dari generator ke register display penerima dengan status *Zero Errors*.

### **FASE 4: Pengujian Hardware & Analisis Performa (6 Juni \- 8 Juni)**

*Target: Implementasi fisik pada dua board DE10-Standard dan pengambilan data BER.*

* **Rafi (Audio & I/O Loopback):**  
  * Mengompilasi desain top-level pengirim di Quartus dan memprogram ke FPGA pengirim.  
  * Menghubungkan kabel *Audio Line-Out* pengirim ke *Audio Line-In* penerima.  
  * Mengonfigurasi codec penerima agar membunyikan nada secara langsung ke speaker eksternal (loopback DAC murni).  
* **Kean (DSP Lock & Demodulation):**  
  * Memprogram FPGA penerima.  
  * Menguji penguncian sinkronisasi preamble pada saluran bising.  
* **Bersama (Koleksi Data Pengujian):**  
  * Menguji performa modem pada 3 jenis kanal analog:  
    1. *Kabel Loopback Langsung*: Mengukur Bit Error Rate (BER).  
    2. *Kanal Akustik Udara (Wireless Speaker-to-Mic)*: Menguji ketahanan terhadap *ambient noise*.  
    3. *Kanal Aplikasi VoIP (WhatsApp/LINE)*: Menguji ketahanan sekuens kontinu terhadap algoritma kompresi audio VoIP.

### **D-DAY: Presentasi Akhir Penelitian Rekayasa (9 Juni 2026\)**

*Target: Menyelesaikan semua kewajiban akademis.*

* Melakukan demo langsung di depan Pak Arif Sasongko dan tim dosen penguji.  
* Mengumpulkan laporan akhir Penelitian Rekayasa (EL4064).

## **III. Matriks Pembagian Tugas Spesifik**

| Kegiatan Utama | Rafi Ananta Alden (13222087) | Kean Malik Aji Santoso (13222083) |
| :---- | :---- | :---- |
| **MATLAB Model** | Generator DTMF Kontinu (16-simbol) | Detektor Preamble & Periodic Sampler |
| **VHDL RTL Coding** | 1\. Modifikasi generate\_dtmf\_signed.vhd 2\. Integrasi HEX0-HEX5 (SW0 Mux) 3\. Pengaturan Audio DAC Playback (Loopback) | 1\. Modifikasi Filter Goertzel (16-simbol) 2\. Modifikasi Framingv2.vhd (Periodic Counter) 3\. Modul Shift-Add 32-bit |
| **Verification** | Testbench Generator & Simulasi ModelSim TX | Testbench Demodulator & Simulasi ModelSim RX |
| **Hardware Test** | Wiring audio fisik & konfigurasi PC serial/tombol trigger | Pengukuran performa BER, SER, dan Frame Lock Rate |

