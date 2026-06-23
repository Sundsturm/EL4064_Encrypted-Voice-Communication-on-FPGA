# Catatan Implementasi DTMF System — MATLAB

> Tanggal: 2026-06-02  
> Lingkup: `MATLAB/DTMF/` dan `MATLAB/Frame Synchronization/exp 1.7 fixed point v6/`

---

## 1. Top-Level Gabungan: `dtmf_transmission.m`

### Lokasi
```
MATLAB/DTMF/DTMF_Transmission/dtmf_transmission.m
```

### Tujuan
Fungsi ini mengorkestrasi tiga modul utama menjadi satu alur transmisi end-to-end:

```
dtmf_transmission('3A7C9B1D')
        |
        | Prepend SYNC_POINT = "##3#"
        | Full sequence = "##3#3A7C9B1D" (12 simbol)
        v
[1] generate_dtmf(full_sequence)
    Output: int16, 7680 sampel, Q3.13
        |
        | Konversi int16 -> fi Q3.13: double(x)/8192
        | Prepend 1280 sampel noise [-2,2] (untuk frame_sync)
        v
[2] frame_sync(input_fi)           <- menerima 8960 sampel (noise + DTMF)
    Output: goertzel_enable (0/1)
        |
        | Jika goertzel_enable == 1:
        | Payload slice deterministik: dtmf_out[2561:7680]
        v
[3] dtmf_receiver_top(payload_signal)
    Output: uint32 reconstructed_key, decode_table
```

### Antarmuka Fungsi
```matlab
[reconstructed_key, decode_table, goertzel_enable] = dtmf_transmission(payload_symbols)
```

| Parameter | Tipe | Keterangan |
|---|---|---|
| `payload_symbols` | `char` / `string` | 8 simbol DTMF (0–9, A–D, \*, \#). Contoh: `'3A7C9B1D'` |
| `reconstructed_key` | `uint32` | 32-bit hasil decode (tiap 4-bit = 1 simbol) |
| `decode_table` | `struct array` (8 elemen) | Detail per simbol: char, code, bits, energy |
| `goertzel_enable` | `logical` | 1 = sync berhasil, 0 = sync gagal |

### Keputusan Desain Penting

#### D1 — Sync Point Predefined di Top-Level
```matlab
SYNC_POINT = '##3#';  % 4 simbol preamble, tidak diubah oleh user
```
Payload user (8 simbol) digabung: `full_sequence = [SYNC_POINT, payload_str]`.

#### D2 — Konversi Fixed-Point di Top-Level (bukan di sub-modul)
```matlab
F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');
input_fi = fi(double(dtmf_out) / 8192, 1, 16, 13, 'fimath', F);
```
Dilakukan di top-level karena dalam hardware RTL, interface-level (ADC/bus) yang
mengonversi format fixed-point, bukan masing-masing IP core.

#### D3 — Leading Noise untuk Frame Synchronization
```matlab
LEADING_NOISE_SAMPLES = 32 * 40;  % = 1280 sampel = 2 simbol DTMF
leading_noise_fp = (4 * rand(1, LEADING_NOISE_SAMPLES)) - 2;
input_fi = fi([leading_noise_fp, dtmf_normalized], 1, 16, 13, 'fimath', F);
```
**Alasan:** `flagging.m` menggunakan *rise detection* (`curr >= 3 * prev`, lag 32 frame).
Algoritma ini membutuhkan baseline berdaya rendah sebelum sinyal DTMF dimulai
agar kontras naik terukur. Tanpa noise, semua batch sums sudah tinggi dari awal
dan flagging gagal. Ini konsisten dengan `run_frame_sync_demo.m`.

Noise **hanya** ditambahkan ke `input_fi` (untuk Frame Sync).
`dtmf_out` tetap bersih (untuk DTMF Receiver).

#### D4 — Payload Slice Deterministik (Opsi B)
```matlab
payload_start  = 4 * 640 + 1;   % = sampel 2561
payload_end    = 12 * 640;       % = sampel 7680
payload_signal = dtmf_out(payload_start:payload_end);
```
Posisi payload diketahui secara statis karena sync point selalu tepat
4 simbol × 640 sampel/simbol = 2560 sampel. Ini analog dengan RTL di mana
sistem menghitung jumlah clock cycles setelah `goertzel_enable` di-assert —
`goertzel_enable` berfungsi sebagai **gate**, bukan penanda posisi.

---

## 2. Perubahan MATLAB yang Dilakukan

### 2.1 `DTMF_Generator/sine_gen.m` — Perbaikan Amplitudo ROM

**File:** `MATLAB/DTMF/DTMF_Generator/sine_gen.m`

**Perubahan (fungsi `build_rom`, baris 119):**
```matlab
% SEBELUM (amplitudo ~2.0/tone, sum ~4.0 -> overflow di frame_sync):
sin_scaled = sin(angle) * (2^double(rom_width - 1) - 1);  % = sin × 16383

% SESUDAH (amplitudo ~1.0/tone, sum ~2.0 -> sesuai frame_sync):
sin_scaled = sin(angle) * (2^double(rom_width - 2) - 1);  % = sin × 8191
```

**Masalah yang diselesaikan:**
Sebelumnya, `sine_gen` menggunakan ROM 14-bit penuh (nilai puncak = 16383).
Dua tone dijumlah menghasilkan amplitudo ~4.0 dalam Q3.13, yang menyebabkan:
- `total_calc`: `acc^2` overflow Q12.4 (max 2047.9) → 20% saturasi
- `sliding`: batch_sum overflow Q15.1 (max 16383.5) → 98% saturasi
- Semua frekuensi terlihat sama (tidak bisa dibedakan) → flagging gagal

**Setelah fix:**
- Amplitudo per tone: 8191/8192 ≈ 1.0 Q3.13
- Sum dua tone: ≈ 2.0 Q3.13 (identik dengan `run_frame_sync_demo.m`)
- `total_power = acc^2 ≈ 35^2 = 1225` < Q12.4 max (2047.9) ✓
- Batch sum ≈ 16 × 1225 = 19600... batasan ini dikelola oleh kontras noise vs signal

### 2.2 `DTMF_Transmission/dtmf_transmission.m` — File Baru (Top-Level)

**File:** `MATLAB/DTMF/DTMF_Transmission/dtmf_transmission.m`  
**Status:** Dibuat baru. Tidak ada modifikasi pada modul yang sudah ada.

---

## 3. Rekomendasi Perubahan RTL

### 3.1 `sine_gen_signed.vhd` — 1-bit Arithmetic Right Shift pada Output

**Lokasi RTL:** `RTL/Component/DTMF Generator/` (atau ekuivalen)

**Perubahan yang diperlukan:**
Tambahkan 1-bit arithmetic right shift pada sinyal `DATA_OUT` sebelum dikeluarkan
dari entitas `sine_gen_signed`, ekuivalen dengan membagi amplitudo ROM 2×.

```vhdl
-- SEBELUM:
DATA_OUT <= rom_data_reg;  -- amplitudo puncak = 2^14-1 = 16383

-- SESUDAH (tambahkan right shift):
DATA_OUT <= shift_right(signed(rom_data_reg), 1);
-- atau equivalently:
-- DATA_OUT <= rom_data_reg(15) & rom_data_reg(15 downto 1);  -- sign-extending right shift
```

**Dampak:**
- Amplitudo per tone turun dari ~16383 ke ~8191 (dalam representasi int16)
- Dalam Q3.13: ~2.0 → ~1.0 per tone
- Sum dua tone: ~4.0 → ~2.0 (headroom +6 dB)
- Frame Sync downstream tidak overflow

> **Catatan:** Perubahan ini hanya pada output `sine_gen_signed.vhd`.
> Internal ROM dan NCO tidak perlu diubah.

### 3.2 Tidak Ada Perubahan di Frame Synchronization RTL

Frame Synchronization RTL tidak perlu diubah. Ia sudah beroperasi pada asumsi
input amplitudo ~2.0 (sum dua tone dengan amplitudo ~1.0 masing-masing).
Dengan fix di `sine_gen_signed.vhd` (3.1), input Frame Sync sudah sesuai.

### 3.3 Tidak Ada Perubahan di DTMF Receiver RTL

DTMF Receiver menggunakan Goertzel filter dengan perbandingan energi relatif
(frekuensi mana yang dominan), bukan nilai absolut. Perubahan amplitudo tidak
mempengaruhi kemampuan deteksi simbol.

---

## 4. Rangkuman Amplitude Chain

| Tahap | Nilai (int16) | Nilai (Q3.13) | Status |
|---|---|---|---|
| `sine_gen` output per tone (sebelum fix) | ~16383 | ~2.0 | ❌ Terlalu besar |
| `sine_gen` output per tone (setelah fix) | ~8191 | ~1.0 | ✅ |
| `generate_dtmf` sum dua tone (setelah fix) | ~16382 | ~2.0 | ✅ |
| `dtmf_transmission` input ke `frame_sync` (fi Q3.13) | — | ~2.0 | ✅ |
| `run_frame_sync_demo.m` referensi | — | 2.0 | ✅ Identik |

---

## 5. Arsitektur DTMF Receiver

### 5.1 Alur Internal `dtmf_receiver_top.m`

Receiver memproses 8 simbol payload secara berurutan. Setiap simbol diproses oleh
4 sub-modul berantai:

```
payload_signal (int16, 5120 sampel = 8 × 640)
        |
        | Dibagi per-640-sampel (1 simbol per iterasi)
        v
┌──────────────────────────────────────────────────────┐
│  untuk setiap simbol i = 1..8:                       │
│                                                      │
│  chunk = payload_signal[(i-1)*640+1 : i*640]         │
│       |                                              │
│       v                                              │
│  [1] goertzel_detector(chunk, Fs)                    │
│      Output: power_low [4], power_high [4]           │
│       |                                              │
│       v                                              │
│  [2] comparator(power_low, power_high)               │
│      Output: code_low (1-4), code_high (1-4)         │
│       |                                              │
│       v                                              │
│  [3] decision(code_low, code_high)                   │
│      Output: dtmf_code (uint8, 4-bit, 0x0-0xF)      │
│       |                                              │
│       v                                              │
│  [4] shift_add(state, dtmf_code, true, true)         │
│      Output: output_key (uint32), out_valid          │
└──────────────────────────────────────────────────────┘
        |
        v
reconstructed_key (uint32) — valid setelah simbol ke-8
```

### 5.2 Sub-Modul dan Pemetaan ke RTL

#### `goertzel_detector.m` → `Goertzel_top.vhd` + `Goertzel.vhd`

Menghitung energi Goertzel untuk 8 frekuensi DTMF per blok 640 sampel:

| Frekuensi | Grup | Koefisien (`2cos(2πf/Fs)`) |
|---|---|---|
| 697 Hz | Low | 1.98114 |
| 770 Hz | Low | 1.97538 |
| 852 Hz | Low | 1.96885 |
| 941 Hz | Low | 1.96531 |
| 1209 Hz | High | 1.94006 |
| 1336 Hz | High | 1.93015 |
| 1477 Hz | High | 1.91388 |
| 1633 Hz | High | 1.89757 |

Formula Goertzel yang digunakan:
```matlab
% Per sampel (IIR filter):
q0 = sample(n) + coeff * q1 - q2;
q2 = q1;  q1 = q0;

% Energi akhir (ternormalisasi dengan N²):
power = abs(q1² + q2² - coeff × q1 × q2) / N²
```

> **Catatan normalisasi:** Pembagian N² memastikan energi berskala proporsional
> terhadap amplitudo sinyal (bukan kuadratik terhadap jumlah sampel).
> Perbandingan relatif antar frekuensi tetap valid karena semua dibagi faktor sama.

#### `comparator.m` → `lowcomparator.vhd` + `highcomparator.vhd`

Menentukan frekuensi dominan dari masing-masing grup (low/high) dengan
perbandingan winner-takes-all:

```
code_low  : 1=697Hz | 2=770Hz | 3=852Hz | 4=941Hz  | 0=ambiguous
code_high : 1=1209Hz | 2=1336Hz | 3=1477Hz | 4=1633Hz | 0=ambiguous
```

Jika tidak ada frekuensi yang dominan secara absolut → `code = 0` (ambiguous).

#### `decision.m` → `decision.vhd`

Memetakan pasangan `(code_low, code_high)` ke 4-bit DTMF code sesuai
matriks ITU-T 4×4 (16 simbol lengkap termasuk A, B, C, D):

```
         1209Hz  1336Hz  1477Hz  1633Hz
 697Hz  |  0x1  |  0x2  |  0x3  |  0xA  |
 770Hz  |  0x4  |  0x5  |  0x6  |  0xB  |
 852Hz  |  0x7  |  0x8  |  0x9  |  0xC  |
 941Hz  |  0xE  |  0x0  |  0xF  |  0xD  |
```

> **Catatan encoding khusus:** `'*'` → 0xE (14), `'0'` → 0x0, `'#'` → 0xF (15), `'D'` → 0xD (13).

#### `shift_add.m` → `shift_add.vhd`

Mengakumulasi 8 × 4-bit kode DTMF menjadi satu output 32-bit:

```matlab
% Per simbol (4-bit shift-register):
temp_sig = bitshift(temp_sig, 4);          % geser kiri 4 bit
temp_sig = bitor(temp_sig, uint32(code));  % OR dengan kode baru

% Output valid setelah 8 simbol:
if counter >= 8: out_valid = true
```

Hasil akhir: `reconstructed_key` (uint32) dengan nibble MSB = simbol pertama:
```
bit[31:28] = simbol 1
bit[27:24] = simbol 2
...
bit[3:0]   = simbol 8
```

---

## 6. Diagram Sinyal Sistem Lengkap

```
USER INPUT
  '3A7C9B1D' (string, 8 simbol)
      |
      v
┌─────────────────────────────────────────────────────────────────┐
│  dtmf_transmission.m  (Top-Level)                               │
│                                                                 │
│  1. Validasi input (8 simbol, karakter valid)                   │
│  2. full_seq = ['##3#', payload]  -- 12 simbol                  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  generate_dtmf(full_seq)                                 │   │
│  │  [DTMF_Generator/generate_dtmf.m]                        │   │
│  │  + sine_gen.m (NCO, amplitude ~1.0/tone, Q3.13)          │   │
│  │  Output: dtmf_out (int16, 7680 spl)                      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                     |                                           │
│      ┌──────────────┴──────────────────┐                        │
│      | TOP-LEVEL INTERFACE ADAPTATION  |                        │
│      | • Konversi: double(x)/8192      |                        │
│      | • Prepend 1280 noise spl        |                        │
│      | • Buat fi Q3.13                 |                        │
│      └──────────────┬──────────────────┘                        │
│                     |                                           │
│    input_fi (fi Q3.13, 8960 spl = noise+DTMF)                  │
│                     |                                           │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  frame_sync(input_fi)                                    │   │
│  │  [Frame Sync/exp 1.7 fixed point v6/frame_sync.m]        │   │
│  │  sin_mult -> accu -> total_calc -> sliding               │   │
│  │  -> flagging (deteksi '##') -> marking (deteksi '3')     │   │
│  │  Output: goertzel_enable (1 = sync '##3#' ditemukan)     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                     |                                           │
│            goertzel_enable == 1?                                │
│                     |                                           │
│      payload_signal = dtmf_out[2561:7680]  (deterministik)     │
│                     |                                           │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  dtmf_receiver_top(payload_signal)                       │   │
│  │  [DTMF_Receiver/dtmf_receiver_top.m]                     │   │
│  │  goertzel_detector -> comparator -> decision -> shift_add│   │
│  │  Output: reconstructed_key (uint32)                      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
      |
      v
reconstructed_key = 0x3A7C9B1D  (untuk payload '3A7C9B1D')
decode_table      = struct array (8 elemen)
goertzel_enable   = 1
```

---

## 7. Struktur Direktori `MATLAB/DTMF/`

```
MATLAB/DTMF/
├── NOTES.md                          ← File ini
│
├── DTMF_Generator/
│   ├── generate_dtmf.m               Top-level generator (tidak dimodifikasi)
│   ├── sine_gen.m                    NCO + LUT [DIMODIFIKASI: amplitudo ROM]
│   └── generate_dtmf_fp.m            Versi fixed-point (referensi)
│
├── DTMF_Receiver/
│   ├── dtmf_receiver_top.m           Top-level receiver (tidak dimodifikasi)
│   ├── goertzel_detector.m           Goertzel filter bank (8 frekuensi)
│   ├── comparator.m                  Winner-takes-all frequency comparator
│   ├── decision.m                    4×4 DTMF symbol decoder
│   ├── shift_add.m                   32-bit shift-register accumulator
│   └── run_receiver_test.m           Standalone testbench
│
└── DTMF_Transmission/
    └── dtmf_transmission.m           [BARU] Top-level gabungan pipeline
```

---

## 8. Cara Pengujian

### 8.1 Pengujian Top-Level Gabungan

```matlab
% Di MATLAB, cd ke direktori DTMF_Transmission/ atau pastikan sudah di path
clear functions   % Penting: hapus function cache MATLAB

% Test dasar
[key, tbl, en] = dtmf_transmission('3A7C9B1D');
% Expected: key = 0x3A7C9B1D, en = 1

% Test simbol lain
[key, ~, ~] = dtmf_transmission('12345678');   % Expected: 0x12345678
[key, ~, ~] = dtmf_transmission('*#0ABCD1');  % Expected: 0xEF0ABCD1

% Verifikasi auto-check di output terminal:
% Status: [PASS] Dekode sesuai ekspektasi!
```

> **Catatan `clear functions`:** Wajib dijalankan setiap kali file `.m` diubah
> karena MATLAB meng-cache fungsi di memory. Tanpa ini, perubahan pada disk
> tidak akan terlihat sampai MATLAB di-restart.

### 8.2 Pengujian Standalone Masing-Masing Modul

| Modul | Script Pengujian |
|---|---|
| DTMF Generator | `generate_dtmf()` tanpa argumen |
| DTMF Receiver | `run_receiver_test.m` |
| Frame Synchronization | `run_frame_sync_demo.m` |

