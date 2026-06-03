# Laporan Analisis Verifikasi Kontinuitas Fase DTMF (Phase Continuity Check)
**Berkas Pengujian:** [tb_dtmf_tx_phase_check.v]
**Skrip Eksekusi:** Skrip eksekusi manual via terminal ModelSim/Questa
**Hasil Eksekusi:** `questa_output.txt`, `matlab_output.txt`
**Visualisasi Gelombang:** `waveform.png`
**Waktu Eksekusi Pengujian:** 3 Juni 2026

## Deskripsi Pengujian
Pengujian ini bertujuan untuk memverifikasi kontinuitas fase (*phase continuity*) dari sinyal DTMF yang dihasilkan oleh modul Direct Digital Synthesis (DDS) (`generate_dtmf_signed.vhd` dan `sine_gen_signed.vhd`). Verifikasi dilakukan ketika terjadi transisi nada antar-simbol secara sekuensial (blast kontinu 12 simbol) untuk memastikan bahwa generator DDS tidak menyebabkan patahan fasa (*phase glitch*) atau lompatan tegangan mendadak yang dapat menimbulkan harmonik liar (*spectral splatter*) dan mengacaukan pemrosesan di penerima.

---

## 1. Hasil Pengujian Fungsional (Console & Simulator Transcript)

Uji verifikasi fase dilakukan secara *continuous blast* dengan memancarkan 12 simbol berturut-turut (preamble + payload 32-bit):
- **Sekuens Simbol:** `F` -> `F` -> `3` -> `F` -> `A` -> `1` -> `B` -> `2` -> `C` -> `3` -> `D` -> `4`
- **Waktu Pancar Per Simbol:** 20 ms (total waktu transmisi aktif `240 ms`).

### Analisis Stempel Waktu (Timestamp):
```
# Memulai Transmisi Continuous Blast DTMF...
# Waktu: 210000 ns | Mengirim Simbol HEX: f
# Waktu: 20000210000 ns | Mengirim Simbol HEX: f
# Waktu: 40000210000 ns | Mengirim Simbol HEX: 3
...
# Waktu: 220000210000 ns | Mengirim Simbol HEX: 4
# Simulasi Selesai secara deterministik. Data tertulis ke tx_waveform_output.txt
```

> [!NOTE]
> **Akurasi Skala Waktu (Unit Typo di Console):**
>
> Nilai waktu yang dicetak di konsol (seperti `20000210000 ns`) sebenarnya memiliki satuan **picoseconds (ps)** bukan **nanoseconds (ns)**. Hal ini terjadi karena testbench menggunakan ``timescale 1ns / 1ps`, sehingga variabel `$time` dibaca pada resolusi simulator (`1 ps`).
>
> Mengonversi `20.000.210.000 ps` menghasilkan **`20,00021 ms`**, membuktikan bahwa pergantian simbol terjadi tepat setiap **`20 ms`** sesuai dengan durasi transmisi fisik yang direncanakan.

---

## 2. Analisis Kontinuitas Fase (Phase Continuity Analysis)

Data gelombang sinus hasil pembangkitan DDS diekspor ke berkas `tx_waveform_output.txt` pada frekuensi sampling `32 kHz`, kemudian dianalisis menggunakan skrip MATLAB untuk mencari patahan fase (*phase-glitch*) pada batas pergantian antar-simbol (setiap 20 ms).

### Temuan Analisis MATLAB:
- **Status:** **`SUCCESS VERIFIED`**
- **Kondisi:** Transisi sinyal antar 12 simbol terbukti berjalan **mulus sempurna**, tanpa ditemukan adanya lompatan fase, patahan gelombang, ataupun lonjakan tegangan sesaat (*Glitch-Free DDS*).

### Mengapa DDS Kita Glitch-Free?
Keberhasilan kontinuitas fase ini disebabkan oleh arsitektur akumulator fase DDS (`sine_gen_signed.vhd`):
1. Akumulator fase tidak di-reset ke nol saat simbol `tone_digit` berganti.
2. Ketika frekuensi berganti (karena perubahan `phase_incr`), akumulator fase melanjutkan perhitungannya dari posisi sudut terakhir (*phase continuity*), bukan memulai ulang dari nol.
3. Ini menghasilkan transisi yang sangat mulus, meminimalkan spuria spektral (*spectral splatter*), dan mencegah kerusakan modulasi saat ditransmisikan ke saluran analog.

---

## 3. Kesimpulan Akhir

Modul pembangkit nada DTMF terbukti memiliki sifat **Continuous-Phase DDS** yang sangat baik. Hasil ini menunjukkan bahwa sistem siap untuk memancarkan sinyal DTMF melalui antarmuka audio fisik (Line Out / DAC) tanpa adanya potensi kegagalan deteksi di sisi penerima akibat distorsi fase transisi.
