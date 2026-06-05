# Catatan Implementasi: DecodeDTMF_v2

**Tanggal:** 2026-06-05  
**Status:** ✅ Simulasi unit test berhasil  
**Referensi MATLAB:** `MATLAB/DTMF/DTMF_Receiver/`

---

## Ringkasan

Modul `DecodeDTMF_v2` adalah DTMF Receiver berbasis FPGA yang mengimplementasikan:
1. **Goertzel Filter Bank** — 8 filter paralel (4 low-group + 4 high-group)
2. **Comparator** — menentukan frekuensi dominan tiap grup
3. **Decision** — memetakan (code_low, code_high) → kode DTMF 4-bit
4. **Shift-Add Accumulator** — merangkai 8 × 4-bit menjadi output 32-bit

Seluruh RTL telah disinkronkan dengan kode referensi MATLAB di `dtmf_receiver_top.m`, `goertzel_detector.m`, `comparator.m`, `decision.m`, dan `shift_add.m`.

---

## Parameter Sistem

| Parameter | Nilai |
|---|---|
| Sample rate (`Fs`) | 32.000 Hz |
| Block size (`N`) | 640 sampel/simbol |
| Durasi per simbol | 20 ms |
| Jumlah simbol per frame | 8 simbol |
| Output width | 32-bit (`8 × 4-bit`) |

---

## Frekuensi Goertzel Filter Bank

| Filter | Frekuensi | Koefisien (`2·cos(2π·f/32000)`) |
|---|---|---|
| Low 1 | 697 Hz | 1.98113868088715 |
| Low 2 | 770 Hz | 1.97537668119028 |
| Low 3 | 852 Hz | 1.96885313617978 |
| Low 4 | 941 Hz | 1.96530655866142 |
| High 1 | 1209 Hz | 1.94006250638909 |
| High 2 | 1336 Hz | 1.93014734462309 |
| High 3 | 1477 Hz | 1.91388067146442 |
| High 4 | **1633 Hz** | **1.89757206489700** ← *ditambahkan* |

---

## Tabel Mapping DTMF (decision.vhd)

Encoding: **natural hex representation** — sesuai `decision.m`

|  | 1209 Hz (`"001"`) | 1336 Hz (`"010"`) | 1477 Hz (`"011"`) | 1633 Hz (`"100"`) |
|---|---|---|---|---|
| **697 Hz** (`"001"`) | `'1'` → `0x1` | `'2'` → `0x2` | `'3'` → `0x3` | `'A'` → `0xA` |
| **770 Hz** (`"010"`) | `'4'` → `0x4` | `'5'` → `0x5` | `'6'` → `0x6` | `'B'` → `0xB` |
| **852 Hz** (`"011"`) | `'7'` → `0x7` | `'8'` → `0x8` | `'9'` → `0x9` | `'C'` → `0xC` |
| **941 Hz** (`"100"`) | `'*'` → `0xE` | `'0'` → `0x0` | `'#'` → `0xF` | `'D'` → `0xD` |

---

## Perubahan RTL dari Versi Sebelumnya

### 1. `Goertzel_top.vhd`
- Ditambahkan instance `GOERTZEL_1633` dengan `COEFF = 1.89757206489700`
- Port baru: `power_1633 : out std_logic_vector(DATA_WIDTH downto 0)`
- Logika `in_ready` dan `out_valid` di-AND dengan signal filter 1633 Hz

### 2. `highcomparator.vhd`
- Port baru: `input1633 : in STD_LOGIC_VECTOR(16 downto 0)`
- Logika diperluas dari **3-way** menjadi **4-way comparator**
- Output `"100"` berarti 1633 Hz dominan (untuk simbol A/B/C/D)

### 3. `decision.vhd` *(perubahan terbesar)*
- Diperluas dari **8 simbol** menjadi **16 simbol penuh**
- Encoding diubah dari skema arbitrer lama ke **natural hex** (sesuai `decision.m`):
  - Lama: `'1'→"1000"`, `'0'→"1111"`
  - Baru: `'1'→"0001"`, `'0'→"0000"`
- Ditambahkan encoding 7-segment untuk semua 16 karakter
- Reset value `sevseg` diubah ke `"1111111"` (semua segment OFF)

### 4. `shift_add.vhd` *(ditulis ulang)*
- Output diperlebar: **24-bit → 32-bit** (menampung 8 × 4-bit)
- Logika shift diperbaiki: dari "cek MSB, shift 3-bit" → **"selalu shift 4-bit, OR kode baru"**
- `out_valid` sekarang hanya HIGH setelah `counter ≥ 8`
- Otomatis reset `temp_sig` dan `counter` saat `out_ready = '1'`

### 5. `top_dtmfencode.vhd`
- Port baru: `corr_1633 : in STD_LOGIC_VECTOR(16 downto 0)`
- `encode_out` diperlebar: **24-bit → 32-bit**
- Component declaration `highcomparator` dan `shift_add` diperbarui
- Port map `comp_high` disambungkan ke `corr_1633`

### 6. `dtmf_system.vhd`
- Signal baru: `power_1633 : std_logic_vector(DATA_WIDTH downto 0)`
- `encode_out` diperlebar: **24-bit → 32-bit**
- Port map kedua instance diperbarui

### 7. `DecodeDTMF.vhd`
- Signal `encode_out` diperlebar: **24-bit → 32-bit**

### File Tidak Diubah
| File | Alasan |
|---|---|
| `Audio_interface.vhd` | Sudah benar (Fs=32kHz, interface Ldone/Lin) |
| `Goertzel.vhd` | Generik, dikonfigurasi via generic map |
| `lowcomparator.vhd` | Low-group (4 frekuensi) sudah lengkap |
| `i2c.vhd` | Tidak terkait logika DTMF |

---

## Hasil Simulasi Unit Test

**Testbench:** `top_dtmfencode_tb_v2.vhd`  
**Tool:** ModelSim (compile dengan `run_sim.do`, mode `"unit"`)  
**Status: ✅ PASS**

### Sekuens Uji

| Urutan | Simbol | Frekuensi | Code | Akumulasi `encode_out` |
|---|---|---|---|---|
| 1 | `#` | 941Hz + 1477Hz | `0xF` | `0x0000000F` |
| 2 | `#` | 941Hz + 1477Hz | `0xF` | `0x000000FF` |
| 3 | `1` | 697Hz + 1209Hz | `0x1` | `0x00000FF1` |
| 4 | `5` | 770Hz + 1336Hz | `0x5` | `0x0000FF15` |
| 5 | `*` | 941Hz + 1209Hz | `0xE` | `0x000FF15E` |
| 6 | `7` | 852Hz + 1209Hz | `0x7` | `0x00FF15E7` |
| 7 | `A` | 697Hz + **1633Hz** | `0xA` | `0x0FF15E7A` |
| 8 | `C` | 852Hz + **1633Hz** | `0xC` | **`0xFF15E7AC`** ✅ |

### Verifikasi

```
encode_out RTL   = 0xFF15E7AC
encode_out MATLAB = 0xFF15E7AC  (dari run_receiver_test.m)
Status           = MATCH ✅
```

Simbol `A` (simbol ke-7) dan `C` (simbol ke-8) menggunakan frekuensi **1633 Hz** yang merupakan fitur baru. Keduanya ter-decode dengan benar.

---

## Cara Menjalankan Simulasi

```tcl
# Di ModelSim console, cd ke folder hdl/:
cd ".../DecodeDTMF_v2/hdl"
do run_sim.do
```

Script `run_sim.do` mendukung dua mode (set di baris pertama script):

| Mode | Testbench | File yang dikompile | Tujuan |
|---|---|---|---|
| `"unit"` | `top_dtmfencode_tb_v2` | 5 RTL + 1 TB | Verifikasi encoding (cepat) |
| `"system"` | `dtmf_system_tb` | 8 RTL + 1 TB + Goertzel (-2008) | Verifikasi pipeline penuh |

> **Catatan kompilasi:** `Goertzel.vhd` dan `Goertzel_top.vhd` wajib dikompile dengan flag `-2008` karena menggunakan `ieee.fixed_pkg`. Library `ieee_proposed` telah digantikan.

---

## Langkah Selanjutnya

- [ ] System test (`dtmf_system_tb`) — verifikasi pipeline Goertzel + encode
- [ ] Quartus Analysis & Synthesis — cek tidak ada error/warning width mismatch
- [ ] Timing Analysis (TimeQuest) — cek Fmax di clock domain `AUD_XCK` (~18.432 MHz)
- [ ] Hardware test di board DE2-115 — input audio DTMF nyata dari telepon/generator
