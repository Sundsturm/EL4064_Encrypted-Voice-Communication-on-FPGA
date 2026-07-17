# Ringkasan Pengujian Loopback Modem DTMF

Dokumen ini menyajikan rangkuman hasil pengujian loopback enkripsi kunci dinamis pada modem DTMF menggunakan skrip pengiriman `send_key.py` dan kalkulator performa `calc_perf.py`. Data diambil dari 5 sesi pengujian yang tercatat dalam log masing-masing.

## 1. Rangkuman Hasil per Sesi

Berikut adalah tabel rekapitulasi data performa dari kelima sesi pengujian (`log1.txt` hingga `log5.txt`):

| Sesi Log | Total Kunci | Kunci Salah (WER) | Total Simbol | Simbol Salah (SER) | Total Bit | Bit Salah (BER) | Frame Loss (FLR) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Sesi 1** (`log1.txt`) | 20 | 7 (35.00%) | 161 | 47 (29.19%) | 644 | 102 (15.84%) | 5 (26.32%) |
| **Sesi 2** (`log2.txt`) | 20 | 4 (20.00%) | 160 | 32 (20.00%) | 640 | 68 (10.62%) | 3 (15.79%) |
| **Sesi 3** (`log3.txt`) | 20 | 7 (35.00%) | 160 | 55 (34.38%) | 640 | 113 (17.66%) | 6 (31.58%) |
| **Sesi 4** (`log4.txt`) | 20 | 7 (35.00%) | 160 | 54 (33.75%) | 640 | 119 (18.59%) | 7 (36.84%) |
| **Sesi 5** (`log5.txt`) | 20 | 5 (25.00%) | 160 | 39 (24.38%) | 640 | 80 (12.50%) | 5 (26.32%) |

---

## 2. Perhitungan Rata-Rata Performa

Rata-rata performa dihitung menggunakan dua metode: **Rata-Rata Sederhana (Simple Average)** dari persentase tiap sesi dan **Rata-Rata Teragregasi (Aggregated Total)** dari total keseluruhan data.

### A. Rata-Rata Sederhana (Simple Average)
*   **Average Word Error Rate (WER)**: **30.00%**
*   **Average Symbol Error Rate (SER)**: **28.34%**
*   **Average Bit Error Rate (BER)**: **15.04%**
*   **Average Frame Loss Rate (FLR)**: **27.37%**

### B. Rata-Rata Teragregasi (Aggregated Total)
*   **Total Kunci Diuji**: 100
*   **Total Kunci Salah (Word Errors)**: 30 paket $\rightarrow$ **WER: 30.00%**
*   **Total Simbol Diuji**: 801 digit
*   **Total Simbol Salah (Sym Errors)**: 227 digit $\rightarrow$ **SER: 28.34%** (presisi: 28.3396%)
*   **Total Bit Diuji**: 3204 bit
*   **Total Bit Salah (Bit Errors)**: 482 bit $\rightarrow$ **BER: 15.04%** (presisi: 15.0437%)
*   **Total Frame Loss (Hold-over)**: 26 paket
*   **Total Peluang Frame Loss**: 95 $\rightarrow$ **FLR: 27.37%** (presisi: 27.3684%)

---

## 3. Analisis Hasil dan Fenomena Sistem

Berdasarkan data di atas dan analisis karakteristik sistem, diperoleh beberapa poin penting mengenai performa modem:

1.  **Bit/Symbol Error Riil yang Sangat Rendah**:
    *   Jika diamati baris per baris pada setiap log sesi, setiap kali paket kunci berhasil diterima (`Key Match: OK`), nilai **Symbol Errors** dan **Bit Errors** selalu **0**.
    *   Ini menunjukkan bahwa saluran transmisi (channel) memiliki noise margin yang sangat baik, dan deteksi nada DTMF (melalui algoritma Goertzel) sangat presisi saat frame berhasil disinkronkan. Hampir tidak pernah terjadi kesalahan bit tunggal (bit flip) di dalam payload kunci yang berhasil didekode.

2.  **Penyebab Utama SER/BER adalah Frame Loss**:
    *   Tingginya nilai rata-rata SER (~28.34%) dan BER (~15.04%) disebabkan oleh **kesalahan total satu frame (frame loss)**, bukan karena noise bit acak di level fisik.
    *   Ketika penerima (RX) mengalami **Frame Loss**, register RX tidak diperbarui dan tetap menyimpan nilai kunci sebelumnya (*hold-over/stuck*) atau tetap `00000000` di awal sesi.
    *   Skrip `calc_perf.py` membandingkan kunci TX baru (yang acak) dengan kunci RX yang stuck tersebut. Karena kedua kunci acak ini dibandingkan secara karakter demi karakter, hal ini menghasilkan tingkat kesalahan simbol (SER) sebesar 7 atau 8 dari 8 simbol (hampir 100% salah pada frame tersebut).
    *   Dengan demikian, nilai SER dan BER yang dilaporkan merupakan **akibat langsung** dari kegagalan sinkronisasi/deteksi frame, bukan degradasi kualitas sinyal payload.

3.  **Masalah Utama: Kegagalan Sinkronisasi (Frame Loss)**:
    *   Dengan rata-rata **Frame Loss Rate (FLR) sebesar 27.37%**, hal ini mengonfirmasi bahwa masalah utama pada sistem saat ini terletak pada **deteksi preamble** (`##3#`) atau kondisi FSM penerima yang mengalami stuck/tidak terdeteksi.
    *   Jika preamble terlewat (misalnya karena window Goertzel berjalan dengan fase acak relatif terhadap awal transmisi), penerima tidak akan memicu state decoding, sehingga seluruh frame kunci dinamis tersebut hilang (mengalami hold-over dari state sebelumnya).

---

## 4. Peran Skrip Pembantu

*   **`send_key.py`**: Mengotomatisasi pengiriman kunci dinamis (mode `random` atau `hardcoded`) sebanyak 20 kali pengiriman dengan jeda tertentu via interface UART CP2102. Jeda ini krusial untuk memberi waktu bagi modem HDL menyelesaikan modulasi dan transmisi DTMF (~240ms per frame).
*   **`calc_perf.py`**: Berperan membandingkan isi file `TX.txt` dan `RX.txt`, mendeteksi hold-over kunci (Frame Loss) secara berurutan, dan menghitung persentase WER, SER, BER, dan FLR secara otomatis serta memformat outputnya ke file log.
