# Frame Synchronization v3 — RTL Documentation

Modul ini mengimplementasikan **Frame Synchronization** untuk mendeteksi sync point 4-simbol DTMF **`##3#`** pada sinyal audio. Output utamanya adalah sinyal `enable` yang mengaktifkan modul Goertzel (DTMF Receiver) untuk mendekode payload/data DTMF.

---

## Daftar File

| File | Tipe | Deskripsi |
|---|---|---|
| `toplevelv1.vhd` | Top-level (untuk testbench) | Instansiasi semua komponen dan digunakan oleh `toplevel_tb1/tb2` |
| `toplevel_iq.vhd` | Top-level (alternatif) | Versi alternatif top-level dengan interface `std_logic_vector` pada input |
| `dec_control.vhd` | Control unit | Mux valid/ready: routing data ke `flagging` atau `marking` |
| `flaggingv2.vhd` | Decision — Flagging | Deteksi dua simbol `#` berurutan (941 Hz + 1477 Hz) |
| `markingv1.vhd` | Decision — Marking | Deteksi simbol `3` (697 Hz naik + memastikan 697 Hz dan 1477 Hz paling dominan) |
| `slidingv5.vhd` | Sliding Window | Akumulasi nilai korelasi per batch (16 frame) |
| `powercalcv1.vhd` | Power Calculator | Hitung `sin² + cos²` dari akumulasi |
| `Framingv2.vhd` | Framing / Accumulator | Akumulasi sample per frame (40 sample) |
| `multv6.vhd` | Multiplier | Perkalian input dengan LUT sin/cos per frekuensi |
| `lutsin_block.vhd` | LUT Sin | Tabel referensi sinus (697, 941, 1477 Hz) |
| `lutcos_block.vhd` | LUT Cos | Tabel referensi kosinus (697, 941, 1477 Hz) |
| `toplevel_tb1.vhd` | Testbench | Testbench minimal (input: `dtmf_signal.txt`) |
| `toplevel_tb2.vhd` | Testbench | Testbench lengkap dengan monitor batch (input: `dtmf_signal_v2.txt`) |

---

## Arsitektur Pipeline

Setiap komponen berkomunikasi menggunakan **valid/ready handshake**. Sinyal `vNvM` dan `rNrM` merupakan koneksi antar stage:

```mermaid
flowchart TD
    IN["Input dataA\n(Q3.13 / 16-bit SLV)"]

    subgraph LUT ["LUT Block (combinatorial)"]
        LUTSIN["lutsin_block\n697 / 941 / 1477 Hz"]
        LUTCOS["lutcos_block\n697 / 941 / 1477 Hz"]
    end

    MULT["multv6\nMultiplier\n× sin &amp; × cos\n— Q3.13 —"]
    FRAME["Framingv2\nAccumulator\n40 samples/frame\n— Q8.8 —"]
    POWER["powercalcv1\nPower Calculator\nsin² + cos²\n— Q12.4 —"]
    SLIDING["slidingv5\nSliding Window\n16 frames/batch\n— Q15.1 —"]
    CTRL["dec_control\nControl Unit\nRouting valid/ready"]

    subgraph DECISION ["Decision Block"]
        FLAG["flaggingv2\nFlagging\nDeteksi ##\n941Hz + 1477Hz"]
        MARK["markingv1\nMarking\nDeteksi 3\n697Hz naik + guard"]
    end

    OUT(["enable\n(goertzel_enable)"])

    IN --> MULT
    LUT -->|"sin / cos LUT values"| MULT
    MULT -->|"v2v1 / r2r1"| FRAME
    FRAME -->|"v2v2 / r2r2"| POWER
    POWER -->|"v2v3 / r2r3"| SLIDING
    SLIDING -->|"v2v4 / r2r4\ndbg_batch_valid"| CTRL

    CTRL -->|"flag_invalid\nflag_outready"| FLAG
    CTRL -->|"mark_invalid\nmark_outready"| MARK

    FLAG -->|"flag_inready\nflag_outvalid"| CTRL
    MARK -->|"mark_inready\nmark_outvalid"| CTRL

    FLAG -->|"onoff_mark\n(SR latch permanen)"| CTRL
    CTRL -->|"mark_in → mark_out"| OUT
```

### Parameter Fixed-Point

| Stage | Format | VHDL Range |
|---|---|---|
| Input (`dataA`) | Q3.13 | `SFIXED(2 downto -13)` |
| Multiplier output | Q3.13 | `SFIXED(2 downto -13)` |
| Accumulator output | Q8.8 | `SFIXED(7 downto -8)` |
| Power output | Q12.4 | `SFIXED(11 downto -4)` |
| Batch sum output | Q15.1 | `SFIXED(14 downto -1)` |

---

## Penjelasan Sinyal Handshake

| Sinyal | Arah | Makna |
|---|---|---|
| `v2v1` | `multv6 → Framingv2` | Output multiplier valid |
| `v2v2` | `Framingv2 → powercalc` | Output akumulasi valid |
| `v2v3` | `powercalc → slidingv5` | Output power valid |
| `v2v4` | `slidingv5 → dec_control` | **Batch baru siap** (≡ `dbg_batch_valid`) |
| `rNrM` | arah balik | Backpressure (downstream siap) |

`v2v4` (alias `dbg_batch_valid`) berarti **satu sliding window batch telah selesai dihitung**, setara dengan satu iterasi `slide_i` pada MATLAB `sliding.m`.

---

## Perubahan Modul

Perubahan berikut dilakukan untuk menyesuaikan logika RTL dengan referensi MATLAB `exp 1.7 fixed point v6`.

Referensi MATLAB: `MATLAB/Frame Synchronization/exp 1.7 fixed point v6/`

---

### Revisi `flaggingv2.vhd`

**Referensi MATLAB:** `flagging.m`

**Tujuan:** Deteksi dua simbol `#` berurutan dengan cara membandingkan nilai batch saat ini dengan nilai 32-batch lalu. Jika keduanya (941 Hz dan 1477 Hz) masing-masing memenuhi threshold ≥ 5 kali berturut-turut, flag dikonfirmasi dan `onoff_mark` di-assert.

#### Perubahan dari versi sebelumnya

| Aspek | Sebelum | Sesudah |
|---|---|---|
| **Counter** | 1 counter gabungan — naik hanya jika 941 Hz **DAN** 1477 Hz memenuhi syarat **secara bersamaan** | 2 counter **independen**: `count_941` dan `count_1477` — masing-masing naik/reset sendiri |
| **Reset counter** | Reset keduanya sekaligus jika salah satu gagal | Hanya counter yang gagal yang di-reset; yang lain tetap |
| **Circular buffer** | 25 slot (delay ~24 batch) | **33 slot** (delay 32 batch — sesuai MATLAB `slide_i - 32`) |
| **SR latch per frekuensi** | Tidak ada | `detect_941` dan `detect_1477`: latch permanen, hanya bisa `0→1` |
| **Threshold RTL** | `counter >= 5` (checks nilai lama sebelum increment) | `count >= 4` — kompensasi 1-cycle clocked delay; setara MATLAB `count >= 5` setelah increment |
| **`onoff_mark`** | Bisa berfluktuasi (di-set lalu counter di-reset) | **SR latch permanen**: sekali `'1'`, tidak pernah kembali ke `'0'` kecuali reset global |

#### Alur logika (sesuai MATLAB `flagging.m`)

```
Setiap batch baru masuk (full = '1'):

  941 Hz:
    if curr_941 >= 3 * prev_941_32batches_ago:
        count_941 = min(count_941 + 1, 5)
    else:
        count_941 = 0
    if count_941 >= 4:   ← RTL threshold (≡ MATLAB >= 5 setelah increment)
        detect_941 = '1' (latch)

  1477 Hz: (sama, independen)
    ...
    if count_1477 >= 4:
        detect_1477 = '1' (latch)

  Konfirmasi:
    if detect_941 = '1' AND detect_1477 = '1':
        onoff_mark = '1'  ← permanen, tidak pernah reset
```

---

### Revisi `markingv1.vhd`

**Referensi MATLAB:** `marking.m`

**Tujuan:** Setelah flagging mengaktifkan modul ini (via `dec_control`), deteksi simbol `3` menggunakan **dua kondisi sekuensial**.

#### Perubahan dari versi sebelumnya

| Aspek | Sebelum | Sesudah |
|---|---|---|
| **Port input** | Hanya `in_697` | `in_697` + **`in_941`** (baru) + **`in_1477`** (baru) |
| **Kondisi deteksi** | Mencari nilai maksimum `max697` — logika tidak sesuai MATLAB | Dua kondisi sekuensial sesuai `marking.m` |
| **Kondisi 1** | `max697 > in_697` (mencari puncak) | `curr_697 > prev_697` (697 Hz sedang **naik**) |
| **Kondisi 2 (guard)** | Tidak ada | `curr_697 > curr_941 AND curr_1477 > curr_941` (697 Hz **dominan** atas 941 Hz) |
| **Counter** | Counter tidak relevan (berbasis 5 iterasi) | Dihapus |
| **`enable`** | Latch tidak reliable | SR latch permanen via `enable_i` internal |

#### Alur logika (sesuai MATLAB `marking.m`)

```
Setiap batch masuk (setelah flagging aktif):

  KONDISI 1: Apakah 697 Hz sedang naik?
    if curr_697 > prev_697:

      KONDISI 2 (guard): Apakah 697 Hz dominan di atas 941 Hz?
        if curr_697 > curr_941 AND curr_1477 > curr_941:
          enable = '1'  ← permanen (goertzel_enable)

  prev_697 ← curr_697  (update untuk batch berikutnya)
```

Kondisi guard memastikan ini benar-benar simbol `3` (697+1477 Hz) dan bukan noise atau overlap dengan simbol `#` (941+1477 Hz).

---

### Revisi `toplevelv1.vhd`

**Perubahan:** Sinkronisasi dengan interface baru `markingv1` (penambahan port `in_941` dan `in_1477`).

1. **Component declaration** `markingv1`: tambah `in_941` dan `in_1477`
2. **Port map** `mark_unit`: hubungkan `sum941 → in_941` dan `sum1477 → in_1477`

---

### Revisi `toplevel_iq.vhd`

Perubahan identik: update component declaration dan port map untuk `markingv1`.

---

## Cara Menjalankan Testbench (ModelSim)

### Compile order

```tcl
vcom -2008 lutsin_block.vhd
vcom -2008 lutcos_block.vhd
vcom -2008 multv6.vhd
vcom -2008 Framingv2.vhd
vcom -2008 powercalcv1.vhd
vcom -2008 slidingv5.vhd
vcom -2008 flaggingv2.vhd
vcom -2008 markingv1.vhd
vcom -2008 dec_control.vhd
vcom -2008 toplevelv1.vhd
vcom -2008 topiq_tb_unified.vhd
```
atau jalankan **"Compile All"** pada **ModelSim** (pastikan menggunakan mode VHDL-2008).

### Pembangkitan Stimulus Pengujian
Untuk menghasilkan file stimulus `.txt` realistis yang diuji, jalankan skrip Python:
```bash
python generate_test_signals.py
```
Skrip ini akan menghasilkan 6 file pengujian dengan preapplied silence 1280 sample (untuk lookback buffer alignment):
- `test_1key_standard.txt`: Sinyal ideal preamble + payload standar.
- `test_worst_case_payload.txt`: Payload yang sengaja diisi simbol mirip preamble (untuk menguji ketahanan FSM agar tidak re-trigger).
- `test_silence_gaps.txt`: Sinyal dengan jeda hening antar-simbol (inter-symbol silence).
- `test_low_snr.txt`: Sinyal dengan AWGN 5 dB (skala amplitudo 30%).
- `test_freq_offset.txt`: Sinyal dengan drift frekuensi DTMF sebesar +1.5%.
- `test_impulse_noise.txt`: Sinyal dengan noise spike impulsif amplitudo ±1.8.

### Menjalankan Simulasi Unified Testbench
Unified testbench menerima generic `INPUT_FILE_NAME` untuk memilih file stimulus. Jalankan perintah berikut di console ModelSim:

```tcl
# Skenario 1: Ideal / Standard
vsim -gINPUT_FILE_NAME="test_1key_standard.txt" topiq_tb_unified
run -all

# Skenario 2: Worst-Case Payload
vsim -gINPUT_FILE_NAME="test_worst_case_payload.txt" topiq_tb_unified
run -all

# Skenario 3: Silence Gaps
vsim -gINPUT_FILE_NAME="test_silence_gaps.txt" topiq_tb_unified
run -all

# Skenario 4: Low SNR (5 dB)
vsim -gINPUT_FILE_NAME="test_low_snr.txt" topiq_tb_unified
run -all

# Skenario 5: Frequency Offset (+1.5% drift)
vsim -gINPUT_FILE_NAME="test_freq_offset.txt" topiq_tb_unified
run -all

# Skenario 6: Impulsive Noise
vsim -gINPUT_FILE_NAME="test_impulse_noise.txt" topiq_tb_unified
run -all
```

### Hasil Uji & Checklist Verifikasi

- [x] **Case 1 (Standard / Ideal)**: PASS (Sync detected 1 times)
- [x] **Case 2 (Worst-Case Payload)**: PASS (Sync detected 1 times) — Menguji ketahanan terhadap double-triggering. Sinyal `enable` tidak ter-trigger ulang oleh data payload.
- [x] **Case 3 (Silence Gaps)**: PASS (Sync detected 1 times) — Berhasil mendeteksi preamble walaupun ada jeda hening antar-simbol.
- [x] **Case 4 (Low SNR 5 dB)**: PASS (Sync detected 1 times) — Handal mendeteksi di bawah noise floor AWGN 5 dB.
- [x] **Case 5 (Freq Offset +1.5%)**: PASS (Sync detected 1 times) — Mengatasi drift frekuensi nominal DTMF.
- [x] **Case 6 (Impulse Noise)**: PASS (Sync detected 1 times) — Kebal terhadap impulsive noise spikes amplitudo ±1.8.

---

## Referensi

- MATLAB Golden Model: `MATLAB/Frame Synchronization/exp 1.7 fixed point v6/`
  - `flagging.m` — referensi untuk `flaggingv2.vhd`
  - `marking.m` — referensi untuk `markingv1.vhd`
  - `frame_sync.m` — alur top-level (Steps 1–6)
  - `sliding.m` — referensi untuk `slidingv5.vhd`
- Parameter simulasi: Fs = 32 kHz, frame_size = 40, batch_size = 16
- Format fixed-point utama: Q3.13 (input) → Q15.1 (batch sum output)

## Perbaikan/Revisi
### Revisi 1: Perbaikan Flagging dan Marking - Perubahan logika deteksi yang lebih sadar terhadap kondisi kanal yang bisa saja meredam frekuensi tertentu
Saya ingin modifikasi modul frame synchronization pada kedua modul ini.
- `flaggingv2.vhd`
Logic untuk pendeteksian ini kan memerlukan circular buffer untuk menampung batch sebelumnya. Namun, ternyata jumlah batch atau ukuran circular buffer ini harus disesuaikan dengan kombinasi sampel per frame dan frame per batch yang dipilih, yaitu 40 sampel per frame dan 16 frame per batch
  - 1 simbol itu adalah 640 sampel sehingga 1 simbol adalah 1 batch

**Pertanyaan**: Apakah logic pendeteksian yang sekarang ini sudah robust atau bisa diimprove lebih baik lagi?
> Catatan penting dari flagging adalah hal ini akan memengaruhi keseluruhan sistem komunikasi DTMF yang diimplementasikan di `../../../hdl` terutama pada pengaturan `align_fsm` dan ukuran dari circular buffer.
- `markingv1.vhd`:
Logic pendeteksian yang sekarang diimplementasikan ini belum memerhatikan keterbatasan kanal audio di sisi hardware sepenuhnya karena masih ada implementasi kondisi *guard* yang membandingkan *current batches*, terutama pada kondisi *guard* ke-2.
  - Harapannya adalah kondisi *guard* ini bisa dihilangkan dan diganti dengan kondisi yang *robust* dalam mendeteksi simbol "3" dengan cara membandingkan batch sekarang terhadap batch sebelumnya pada frekuensi tertentu
    - Salah satu kondisi guard yang bisa dibandingkan dengan kondisi sebelumnya adalah memastikan frekuensi 941 Hz yang bergerak menurun atau batch sekarang nilainya lebih kecil daripada batch sebelumnya dengan kata lain

**Pertanyaan**: Apakah harapan modifikasi ini robust dalam mendeteksi simbol "3" yang merupakan kombinasi dari frekuensi 697 Hz dan 1477 Hz?