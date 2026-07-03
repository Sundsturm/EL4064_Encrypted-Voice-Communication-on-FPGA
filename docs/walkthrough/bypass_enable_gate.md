# Walkthrough: Perbaikan Sementara — Opsi D (Bypass Enable Gate)

Dokumen ini merangkum detail implementasi dan analisis hasil pengujian dari **Opsi D (Bypass Enable Gate)** tanpa penyertaan **Fix 3 (Frame Timeout)** sebagai solusi perbaikan sementara untuk modem DTMF pada FPGA.

---

## 1. Deskripsi Perubahan (Opsi D)

Untuk mengatasi masalah **Goertzel Block Misalignment** yang menyebabkan pergeseran simbol secara berantai (*serial shift* / *offset frame*), kita melakukan pembongkaran pada gerbang pengaktifan Goertzel. 

Sebelumnya, Goertzel hanya dinyalakan (`goertzel_enable = '1'`) setelah IQ Correlator selesai memverifikasi preamble (gated by `enable`). Hal ini menyebabkan Goertzel mulai memproses audio secara "terlambat" di tengah-tengah simbol pertama payload, sehingga batas blok Goertzel (640 sampel) tidak sinkron dengan simbol DTMF.

### Modifikasi Kode pada `AcakCakap_Top.vhd`
Kita memaksa Goertzel untuk **selalu aktif dalam kondisi stabil (*steady-state*)** dengan memanfaatkan generic `SIM_MODE := true` di tingkat top-level:

```vhdl
-- hdl/AcakCakap_Top.vhd
entity AcakCakap_Top is
    generic (
        SIM_MODE : boolean := true  -- Diaktifkan di hardware untuk mem-bypass gate enable
    );
```

Dengan setelan ini, sinyal `goertzel_enable` akan langsung terikat pada `Ldone` (aktif segera setelah interface audio siap):
```vhdl
goertzel_enable <= Ldone; -- Goertzel selalu memproses sampel audio
```

---

## 2. Analisis Performa Hasil Pengujian

Pengujian dilakukan dengan mengirimkan 20 kunci acak melalui UART (`send_key.py`) dengan jeda antarkunci sebesar 10 detik. Log hasil pengujian dapat dilihat di [log.txt (Bypass Enable Gate)](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/results/bypass_enable_gate/log.txt).

### Ringkasan Metrik
*   **Word Error Rate (WER):** **65.00 %** (7 dari 20 kunci berhasil didekode sempurna).
*   **Symbol Error Rate (SER):** **27.50 %** (44 dari 160 digit salah).
*   **Bit Error Rate (BER):** **15.31 %** (98 dari 640 bit salah).
*   **Frame Loss Rate:** **21.05 %** (4 paket mengalami *stuck*/*hold-over* pada visualisasi segmen).

### Karakteristik & Dampak Positif
1.  **Hilangnya Isu Serial Shift:** Pada seluruh paket yang mengalami mismatch (seperti paket 2, 4, 5, 6, 9), data berhasil didekode secara **selaras (perfectly aligned)** dengan jumlah kesalahan simbol yang sangat minim (hanya 1 sampai 3 digit salah).
    *   *Contoh (Paket 2):* TX: `35E244C4` $\rightarrow$ RX: `35E244B4` (Hanya 1 simbol salah, tanpa pergeseran offset!).
2.  **Peningkatan Akurasi Bit (BER):** Nilai BER turun menjadi **15.31%** (dibandingkan baseline ~17.6% dan hasil error latch ~27%).

---

## 3. Limitasi Perbaikan Sementara

Meskipun kualitas alignment meningkat secara drastis, perbaikan ini masih memiliki kelemahan yang dikategorikan sebagai perbaikan sementara:

> [!WARNING]
> **Isu Kerentanan terhadap Noise (Frame Loss):**
> Karena Goertzel selalu menyala, modul ini terus memproses sinyal derau analog (noise/static) dari line input selama jeda hening 10 detik antar-paket. 
> Derau ini sesekali dapat memicu deteksi nada DTMF palsu yang menggeser FSM penerima keluar dari state `WAIT_HASH`. Tanpa adanya mekanisme timeout/reset FSM, FSM akan tersesat saat paket kunci berikutnya tiba, menyebabkan **Frame Loss (stuck pada kunci lama)** sebesar 21.05% (terjadi pada paket 7, 8, 10, dan 11).

---

## 4. Kesimpulan & Langkah Jangka Panjang
Opsi D sukses membuktikan secara empiris bahwa **akar masalah modem DTMF di hardware nyata adalah sinkronisasi Goertzel (Warm-up & Alignment)**, bukan masalah SR Latch. 

Langkah jangka panjang yang direncanakan adalah menerapkan metode **Preamble Bypass via Enable Gating** yang akan mengunci FSM penerima selama waktu hening untuk menangkal noise, namun langsung mengizinkan decode payload secara sinkron tanpa mengecek ulang preamble di sisi Goertzel.
