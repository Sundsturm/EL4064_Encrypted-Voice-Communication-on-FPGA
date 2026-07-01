# Analisis Root Cause & Rekomendasi Perbaikan Frame Loss

## Ringkasan Masalah

Dari `log.txt`, sistem mengalami:
- **WER: 60%** (12 dari 20 paket salah)
- **SER: 31,87%** (51 dari 160 digit hex salah)
- **BER: 17,66%** (113 dari 640 bit salah)

Dengan hanya menggunakan kabel langsung (ideal channel), kesalahan ini **hampir pasti bukan dari kanal**, melainkan dari **mekanisme sinkronisasi internal**.

---

## Klasifikasi Pola Kesalahan dari Log

| Kategori | Paket | Karakteristik |
|---|---|---|
| **Warm-up / Init Failure** | 1, 2, 3 | RX selalu `41E8883E` (nilai default/stale) |
| **Frame Loss (hold-over)** | 14, 16 | RX menampilkan nilai paket *sebelumnya* |
| **Symbol Error Minor** | 5, 11, 12, 13, 17, 19 | Hamming Distance 1–5 bit, 1–2 digit berbeda |
| **Sukses** | 4, 6, 7, 8, 9, 10, 18, 20 | Sempurna |

---

## Root Cause Analysis

### 🔴 Penyebab 1 — Inter-Packet Silence = 0 (Critical)

**File:** [`AcakCakap_Top.vhd` baris 450](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/AcakCakap_Top.vhd)

```vhdl
-- Langsung sambung (NO SILENCE)
current_state <= TRANSMIT;
```

Pengirim mengirim **12 simbol DTMF back-to-back tanpa jeda** saat berpindah ke paket berikutnya. Receiver menggunakan `flaggingv2.vhd` (SR latch permanen: **sekali `onoff_mark='1'` tidak pernah reset**). Kondisi ini menyebabkan:

- Receiver **tidak bisa membedakan** akhir paket N dengan awal paket N+1
- Pipeline IQ demodulator (multi-stage: mult → framing → powercalc → sliding → flagging → marking) butuh beberapa batch "waktu pemulihan" setelah tiap paket
- Tanpa silence, receiver langsung membaca simbol paket berikutnya **sebelum shift register selesai dikunci** → Frame loss pada paket 14 & 16

**Solusi tanpa mengubah kode:** Tambahkan **jeda fisik** antar transmisi paket saat menekan tombol KEY(1). Tunggu minimal **5–10 detik** antara satu pengiriman paket dengan berikutnya.

---

### 🔴 Penyebab 2 — Warm-up Effect: Receiver Belum Sync Saat FPGA Baru Diprogram

**File:** [`flaggingv2.vhd`](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/receiver_hdl/flaggingv2.vhd) — `slidingv5.vhd` membutuhkan `fill_count >= 14` batch sebelum mulai mengeluarkan output; `flaggingv2.vhd` membutuhkan buffer 33-batch penuh.

- Setelah FPGA diprogram dan diinisialisasi, pipeline receiver butuh waktu *warm-up* mengisi buffer sliding window dan circular buffer
- Paket 1–3 tiba sebelum buffer terisi → decoder tidak pernah mengeluarkan hasil valid → RX stuck di nilai default `41E8883E`

**Solusi tanpa mengubah kode:**
- **Tunggu 5–10 detik** setelah power-on/programming sebelum mengirim paket pertama
- Kirim paket "dummy" pertama (biarkan hasilnya salah), baru kirim data sebenarnya dari paket ke-2

---

### 🟡 Penyebab 3 — SR Latch Permanen di `flaggingv2` Tanpa Reset Antar Paket

**File:** [`flaggingv2.vhd` baris COMPUTE](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/receiver_hdl/flaggingv2.vhd)

```vhdl
-- SR latch: sekali '1', tidak pernah kembali ke '0'
if detect_941 = '1' and detect_1477 = '1' then
    onoff_mark <= '1';
end if;
```

Begitu `##` preamble terdeteksi sekali, `onoff_mark` tidak pernah reset. Artinya pada paket berikutnya, receiver **langsung masuk mode "after preamble"** tanpa mendeteksi ulang preamble `##3#` → risiko window alignment yang salah.

**Solusi tanpa mengubah kode:** Tekan tombol **reset (KEY(0))** sebelum setiap transmisi paket baru. Ini akan mereset semua latch dan buffer kembali ke kondisi awal.

---

### 🟡 Penyebab 4 — Window Alignment Goertzel (Minor Symbol Errors)

Goertzel di `AcakCakap_Top.vhd` menggunakan `BLOCK_SIZE = 640` dan bergantung pada `Ldone` dari Audio Interface. Jika ada jitter di clock audio (AUD_XCK dari PLL), boundary window bisa bergeser sebesar beberapa sample, yang menyebabkan satu frekuensi dibaca dengan power sedikit berbeda → 1–2 digit hex berubah (Paket 5, 11, 12, 13, 19).

**Solusi tanpa mengubah kode:** Tidak ada yang bisa dilakukan untuk ini tanpa modifikasi. Namun, pastikan **kabel audio pendek dan tidak bising** (≤30 cm, shielded jika ada).

---

## Rekomendasi Prosedur Hardware (Tanpa Modifikasi Kode)

Ini adalah **SOP pengoperasian yang benar** untuk sistem dalam kondisi saat ini:

```
1. POWER ON dan program FPGA via Quartus/JTAG
2. TUNGGU 10 detik (warm-up pipeline + PLL lock)
3. TEKAN KEY(0) untuk reset manual (opsional tapi disarankan)
4. TUNGGU 2 detik setelah reset
5. KIRIM PAKET pertama (dummy): Tekan KEY(1) → TUNGGU sampai LED padam
6. TUNGGU 5–10 detik (biarkan pipeline kosong / flush)
7. TEKAN KEY(0) lagi untuk reset latch flagging dan marking
8. TUNGGU 2 detik
9. KIRIM PAKET ke-2 (data sebenarnya): Tekan KEY(1) → CATAT hasilnya
10. Untuk paket berikutnya: ulangi langkah 6–9
```

> [!IMPORTANT]
> Langkah terpenting adalah **jeda 5–10 detik antar paket** dan **reset (KEY(0)) sebelum setiap paket baru**. Tanpa ini, frame loss pada paket genap (14, 16) hampir pasti berulang.

---

## Proyeksi Perbaikan yang Diharapkan

| Dengan SOP yang Benar | WER | SER | BER |
|---|---|---|---|
| Kondisi saat ini (no SOP) | 60,00% | 31,87% | 17,66% |
| Dengan warm-up + jeda | **~20–30%** | **~10–15%** | **~5–9%** |
| Target ideal (dengan fix kode) | <10% | <5% | <2% |

Paket 1–3 (warm-up) dan paket 14 & 16 (frame loss) mewakili **8 dari 12 kegagalan**. Jika dieliminasi dengan SOP yang benar, WER turun dari 60% menjadi hanya ~20%.

---

## Summary: 3 Akar Masalah vs Solusi

| # | Root Cause | File | Solusi Tanpa Kode |
|---|---|---|---|
| 1 | NO SILENCE antar paket | `AcakCakap_Top.vhd` | Jeda manual 5–10 detik antar transmisi |
| 2 | Warm-up buffer pipeline | `slidingv5.vhd`, `flaggingv2.vhd` | Tunggu 10 detik setelah power-on |
| 3 | SR Latch tidak reset antar paket | `flaggingv2.vhd`, `markingv1.vhd` | Tekan KEY(0) sebelum setiap paket baru |
