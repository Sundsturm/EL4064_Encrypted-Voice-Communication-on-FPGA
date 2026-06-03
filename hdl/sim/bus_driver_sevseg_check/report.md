# Laporan Analisis Pengujian Multiplexer Visualisasi Seven-Segment
**Berkas Pengujian:** [tb_bus_driver_sevseg_check.v]
**Skrip Eksekusi:** [run_tb_bus_driver_sevseg_check.do]
**Waktu Eksekusi Pengujian:** 3 Juni 2026

## Deskripsi Pengujian
Pengujian ini dirancang untuk memverifikasi kebenaran pemetaan jalur data (*endianness alignment*) dan pemotongan bit (*bit slicing*) dari register kunci 32-bit (`reconstructed_key_32bit`) ke penampil fisik 7-Segment (`HEX5` s.d `HEX0`) pada modul top-level `AcakCakap_Top.vhd`. Melalui kendali switch fisik `SW[0]`, pengujian ini memvalidasi bahwa penampil seven-segment dapat secara akurat menampilkan 24-bit LSB (saat `SW[0] = '0'`) maupun 8-bit MSB (saat `SW[0] = '1'`) dengan konversi Active-Low yang benar sesuai dengan spesifikasi perangkat keras DE10-Standard.

---

## 1. Hasil Eksekusi Konsol (Transcript)

Simulasi pengetesan jalur bus visualisasi seven-segment berjalan secara instan dan sukses (LULUS) 100%:

```
===============================================================
[3000000] MEMULAI UJI QA: MULTIPLEXER DISPLAY 7-SEGMENT (ENDIANNESS)
===============================================================
[3000000] INJEKSI: Memaksa sinyal internal 'reconstructed_key_32bit' menjadi 0x3A7C9B1D

[4000000] [SCENARIO 1] Menguji LSB Mode (SW[0] = 0). Menunggu 10 us...
[14000000] [SCENARIO 1] Memeriksa Output Fisik HEX...
 -> [PASS] HEX5..HEX0 berhasil menampilkan '7C9B1D'

[14000000] [SCENARIO 2] Menguji MSB Mode (SW[0] = 1). Menunggu 10 us...
[24000000] [SCENARIO 2] Memeriksa Output Fisik HEX...
 -> [PASS] HEX5..HEX0 berhasil menampilkan '3A----'

===============================================================
[24000000] STATUS QA: LULUS (ALL PASSED) - Pemetaan bus data dan bit-slicing sudah sempurna dan selaras (endian-correct).
===============================================================
```

---

## 2. Analisis Bentuk Gelombang (Waveform Analysis)

Berdasarkan data tangkapan layar bentuk gelombang yang dilampirkan:

1. **Reset & Inisiasi Awal (t = 0 s.d 3 us):**
   - Sinyal `reconstructed_key_32bit` bernilai `XXXXXXXXXXXXXXXX` di awal, kemudian menjadi `00000000` saat tombol `KEY[0]` (Reset) ditekan.
   - Sinyal penampil `HEX5` s.d `HEX0` bernilai `3F` (menampilkan karakter `-` secara default) selama masa inisiasi.

2. **Injeksi Kunci Dinamis (t = 3 us):**
   - Sinyal internal `reconstructed_key_32bit` dipaksa bernilai heksadesimal penanda `3A7C9B1D`.

3. **Scenario 1: LSB Mode (t = 4 us s.d 14 us, SW[0] = 0):**
   - Sinyal kendali `SW[0]` bernilai `0`.
   - Port keluaran fisik berubah secara instan ke pola Active-Low berikut:
     - `HEX5` = `7h78` (merepresentasikan karakter `7`)
     - `HEX4` = `7h46` (merepresentasikan karakter `C`)
     - `HEX3` = `7h10` (merepresentasikan karakter `9`)
     - `HEX2` = `7h03` (merepresentasikan karakter `B`)
     - `HEX1` = `7h79` (merepresentasikan karakter `1`)
     - `HEX0` = `7h21` (merepresentasikan karakter `D`)
   - Gabungan display secara akurat menampilkan string kunci 24-bit LSB: **`7C9B1D`**.

4. **Scenario 2: MSB Mode (t = 14 us s.d 24 us, SW[0] = 1):**
   - Sinyal kendali `SW[0]` dipaksa bernilai `1` pada t = 14 us.
   - Penampil port fisik berubah secara instan ke pola Active-Low baru:
     - `HEX5` = `7h30` (merepresentasikan karakter `3`)
     - `HEX4` = `7h08` (merepresentasikan karakter `A`)
     - `HEX3` s.d `HEX0` = `7h3F` (merepresentasikan karakter strip `-`)
   - Gabungan display secara akurat menampilkan string kunci 8-bit MSB diikuti strip kosong: **`3A----`**.

---

## 3. Kesimpulan

Pengujian menunjukkan bahwa:
* **Pola Bit-Slicing & Endianness:** Pembagian register kunci 32-bit `reconstructed_key_32bit` ke port penampil sudah selaras secara tepat sesuai dengan format byte memory pada hardware fisik.
* **Logika Multiplexing Dinamis:** Switch `SW[0]` secara responsif dan tanpa delay sekuensial (bersifat kombinasional penuh) mampu memindahkan fokus penayangan dari LSB (24-bit bawah) ke MSB (8-bit atas + strip).
* **Hasil Akhir:** Modul visualisasi dinyatakan **LULUS (100% PASSED)** dan siap diimplementasikan langsung pada papan DE10-Standard.
