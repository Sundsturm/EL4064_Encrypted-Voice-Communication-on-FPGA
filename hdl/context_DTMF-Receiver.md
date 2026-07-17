# Context Codebase: Sistem Penerima DTMF Terenkripsi (FPGA)

Dokumen ini adalah catatan mendalam menyeluruh tentang seluruh codebase sistem komunikasi suara terenkripsi berbasis DTMF pada FPGA (Cyclone V). Ditujukan agar AI lain dapat memahami sistem ini secara detail tanpa harus membaca semua file satu per satu.

---

## 1. Gambaran Sistem & Arsitektur

### 1.1 Konsep Utama
Sistem ini adalah **DTMF Voice Modem** berbasis FPGA yang:
- **Mengirim** kunci enkripsi 32-bit sebagai 8 simbol DTMF payload (didahului 4 simbol preamble `#,#,3,#`)
- **Menerima** sinyal audio DTMF, mendeteksi preamble, mendekode 8 simbol payload, dan merekonstruksi kunci 32-bit
- Menggunakan codec audio **Wolfson WM8731** (sample rate 32 KHz, clock `AUD_XCK` ≈ 18.432 MHz)
- Durasi per simbol DTMF: **640 sampel = 20 ms**

### 1.2 Struktur Frame Transmisi
```
[PRE_SILENCE: 1600 sampel / 50 ms]
[Seg 0: # (941+1477 Hz)] [Seg 1: # (941+1477 Hz)] [Seg 2: 3 (697+1336 Hz)] [Seg 3: # (941+1477 Hz)]
[Seg 4..11: 8 simbol payload DTMF = kunci 32-bit, MSB dulu]
```

**Mapping Segmen ke Kunci:**
- Seg 4 → `payload[31:28]`, Seg 5 → `payload[27:24]`, ..., Seg 11 → `payload[3:0]`

### 1.3 Pipeline Alur Data (End-to-End)

```
Audio ADC (Lin, 16-bit signed)
        │
        ▼
[KORELATOR IQ: toplevel_iq_fpga]
  multv6 → Framingv2 → powercalcv1 → slidingv5 → flaggingv2
                                                  → dec_control → markingv1
                                                                 → enable (SR latch)
        │ enable='1'
        ▼
[GOERTZEL_ALIGN_FSM: AcakCakap_Top]
  Menunggu align_counter=817 Ldone setelah rising edge enable
        │ goertzel_aligned='1'
        ▼
[GOERTZEL_RX: Goertzel_top] (8 filter paralel, BLOCK_SIZE=640)
  → power_697..power_1633 (17-bit)
        │ out_valid='1'
        ▼
[DTMF_ENCODER_RX: top_dtmfencode]
  lowcomparator → decision → shift_add (key_collector)
  highcomparator ↗
        │ out_valid='1' (setelah 8 simbol)
        ▼
reconstructed_key_32bit (32-bit) → display_key → HEX5..HEX0
```

### 1.4 Domain Clock & Reset
| Signal | Sumber | Frekuensi |
|--------|--------|-----------|
| `AUD_XCK` | PLL dari CLOCK_50 | ~18.432 MHz |
| `CLOCK_50` | Oscillator board | 50 MHz |
| `clk` (alias di Top) | `AUD_XCK` | ~18.432 MHz |
| `aud_rst` | Asynchronous assert (KEY0), synchronous deassert (AUD_XCK) | — |
| `rx_rst` | Soft reset penerima; aktif saat `out_valid=1`, timeout, atau cooldown | — |

---

## 2. `AcakCakap_Top.vhd` — Top-Level FPGA

**Entitas:** `AcakCakap_Top`  
**Generics:** `DEBOUNCE_LIMIT : integer := 1000000`

### 2.1 Port Utama
| Port | Arah | Fungsi |
|------|------|--------|
| `CLOCK_50` | in | Clock utama 50 MHz |
| `KEY(3:0)` | in | KEY0=Reset, KEY1=Transmit trigger |
| `SW(9:0)` | in | SW(8)=mode UART/SW, SW(7:0)=kunci statis |
| `AUD_XCK` | buffer | Clock audio dari PLL |
| `FPGA_I2C_SCLK/SDAT` | out/inout | Konfigurasi codec WM8731 |
| `AUD_ADCDAT` | in | Data ADC serial |
| `AUD_DACDAT` | out | Data DAC serial |
| `HEX5..HEX0` | out | Seven-segment display (kunci terdekode) |
| `UART_RXD` | in | UART RX untuk injeksi kunci via PC |

### 2.2 Sinyal Internal Penting
```vhdl
signal Lin, Rin        : signed(15 downto 0);    -- Sample audio ADC (left/right)
signal Ldone, Rdone    : std_logic;               -- Pulsa 1-cycle per sample baru
signal enable          : std_logic;               -- Output korelator IQ (preamble terdeteksi)
signal goertzel_enable : std_logic;               -- = Ldone AND enable AND goertzel_aligned
signal out_valid       : std_logic;               -- Kunci berhasil dikumpulkan (8 simbol)
signal rx_rst          : std_logic;               -- Soft reset seluruh receiver chain
signal display_key     : std_logic_vector(31 downto 0); -- Kunci terakhir yang valid
signal reconstructed_key_32bit : std_logic_vector(31 downto 0);
```

### 2.3 FSM Transmitter: `FSM_DTMF_TRANSMITTER`
**States:** `IDLE | PRE_SILENCE | TRANSMIT`

| State | Aksi |
|-------|------|
| `IDLE` | `dtmf_tone_enable='0'`; tunggu `start_transmission='1'` |
| `PRE_SILENCE` | Diam selama **1600 Ldone** (50 ms); `dtmf_tone_enable='0'` |
| `TRANSMIT` | Kirim 12 simbol (index 0–11); tiap simbol = **640 Ldone** (20 ms); `dtmf_tone_enable='1'`; setelah simbol ke-11 → `IDLE` |

**Konstanta:**
```vhdl
SAMPLES_20MS      : integer := 640   -- Durasi 1 simbol DTMF
SAMPLES_PRE_SILENCE : integer := 1600  -- Durasi silence pra-transmisi (50 ms)
```

**Mapping Simbol:**
```vhdl
-- SEGMENT_TO_DTMF_DECODER (combinational)
Seg 0,1,3 → x"F"  (DTMF '#', 941+1477 Hz)
Seg 2     → x"3"  (DTMF '3', 697+1336 Hz)
Seg 4..11 → payload_data[31:28] down to [3:0]
```

### 2.4 FSM Command (Tombol): `FSM_COMMAND`
**States:** `WAIT_FOR_PRESS | WAIT_FOR_RELEASE | RELEASE_STATE`

Mencegah transmisi berulang karena bouncing tombol. `command='1'` hanya satu siklus saat KEY1 dilepas.

### 2.5 GOERTZEL_ALIGN_FSM (Kritis!)
```vhdl
-- Setelah rising edge 'enable' dari korelator IQ terdeteksi,
-- tahan goertzel_enable selama 817+1=818 Ldone pulse,
-- lalu set goertzel_aligned='1' (SR latch).
-- Nilai 817 dipilih agar jendela Goertzel pertama jatuh
-- tepat di batas simbol payload pertama (Seg 4).
if align_counter = 817 then
    goertzel_aligned <= '1';
else
    align_counter <= align_counter + 1;
end if;
```

**Sinyal FSM:**
- `enable_d` — delay 1 siklus dari `enable` (untuk deteksi rising edge)
- `align_armed` — '1' setelah rising edge `enable` terdeteksi
- `align_counter` — range `0 to 2047`; batas efektif: **817**
- `goertzel_aligned` — SR latch permanen setelah penyelarasan selesai; direset oleh `rx_rst`

### 2.6 Receiver Reset Chain
```
out_valid='1'  ─┐
rx_timeout_rst ─┼─→ rx_cooldown_active='1' (cooldown 1600 Ldone = 50 ms)
                │
rx_rst = out_valid OR rx_timeout_rst OR rx_cooldown_active
```
- **`rx_rst`** direset oleh `aud_rst` (master reset KEY0)
- **Soft reset**: hanya mereset FSM state + SR latch; buffer historis korelator dipertahankan

### 2.7 Watchdog Timer: `WATCHDOG_PROC`
```vhdl
-- Jika enable='1' (Goertzel aktif) selama >300 ms tanpa out_valid:
if rx_timeout_cnt = 5529600 then  -- 5529600 = 300 ms × 18.432 MHz
    rx_timeout_rst <= '1';
end if;
```

### 2.8 Cooldown Timer
```vhdl
rx_cooldown_cnt <= 1600;  -- 40 ms cooldown setelah decode berhasil/timeout
```

### 2.9 UART Protocol FSM
- Clock: `AUD_XCK` (18.432 MHz)
- Baud rate: 115200 bps → `CLKS_PER_BIT = 160`
- Menerima 4 byte kunci, lalu `0x0A` (Line Feed) sebagai trigger transmisi
- Register geser: `uart_key_reg(23:0) & uart_rx_data`

### 2.10 Multiplexer Kunci (SW vs UART)
```vhdl
payload_data <= uart_key_reg when SW(8)='1' else
                SW(7:0) & SW(7:0) & SW(7:0) & SW(7:0);  -- Kunci statis 8-bit direplikasi 4×
```

### 2.11 Visualisasi Seven-Segment
```vhdl
-- SW(0)='0': Tampilkan 24-bit bawah (HEX5=bit23..20, HEX0=bit3..0)
-- SW(0)='1': Tampilkan 8-bit atas (HEX5=bit31..28, HEX4=bit27..24), HEX3..0='-'
```

### 2.12 Instansiasi Modul Utama
| Instance | Entity | Generics Penting |
|----------|--------|-----------------|
| `Audio_interface` | `Audio_interface` | `SAMPLE_RATE=32` (KHz) |
| `DTMF_corr` | `toplevel_iq_fpga` | `GUARD_FLOOR=32.0`, mult=Q2.14, acc=Q6.10, power=Q10.6, batch=Q14.2 |
| `GOERTZEL_RX` | `Goertzel_top` | `DATA_WIDTH=16`, `BLOCK_SIZE=640` |
| `DTMF_ENCODER_RX` | `top_dtmfencode` | `THRESHOLD_VAL=800` |
| `UART_RX_INST` | `uart_rx` | `CLKS_PER_BIT=160` |
| `DTMF_generator` | `generate_dtmf_signed` | `addr_bits=9`, `data_bits=16` |

---

## 3. `i2c.vhd` — Pengontrol I2C Audio Codec

**Entitas:** `i2c`  
**Generics:**
```vhdl
clk_freq : integer := 50000000  -- Input clock 50 MHz
i2c_freq : integer := 20000     -- I2C 20 KHz
```

### 3.1 Fungsi
Menginisialisasi **10 register** codec WM8731 secara berurutan via protokol I2C, lalu sinyal `done='0'` setelah selesai.

### 3.2 Array Konfigurasi `Audio_init` (10 register)
| Idx | Nilai | Register WM8731 | Keterangan |
|-----|-------|-----------------|------------|
| 0 | `0x001C` | Left Line In | Gain input kiri +7.5 dB (LINVOL=0x1C) |
| 1 | `0x001C` | Right Line In | Gain input kanan +7.5 dB (RINVOL=0x1C) |
| 2 | `0x0475` | Left Headphone Out | Volume medium (0x75) |
| 3 | `0x0675` | Right Headphone Out | Volume medium (0x75) |
| 4 | `0x0812` | Analogue Audio Path | Line→ADC, DAC on, no bypass |
| 5 | `0x0A06` | Digital Audio Path | De-emphasis 48 KHz |
| 6 | `0x0C00` | Power Down Control | Semua aktif |
| 7 | `0x0E01` | Digital Interface | MSB first, left-justified, 16-bit |
| 8 | `0x1002` | Sampling Control | Dikontrol SAMPLE_CTRL port (48 KHz) |
| 9 | `0x1201` | Active Control | Activate codec |

**Catatan Gain:** `0x1C` = +7.5 dB. Nilai aman: `0x17` (0 dB) s/d `0x1F` (+12.0 dB). Setiap step = +1.5 dB. Pernah diuji `0x1D` = +9.0 dB untuk meningkatkan SNR.

### 3.3 FSM I2C: `audio_config`
**States:** `s1 | s2 | s3 | s4 | s5`

| State | Aksi |
|-------|------|
| `s1` | Load register ke `i2c_out`: jika `num=8` pakai `SAMPLE_CTRL`, selainnya pakai `Audio_init(num)`; set `go=true` |
| `s2` | Tunggu `i2c_end='1'` (transmisi selesai); set `go=false` |
| `s3` | Cek ACK: jika `ack="000"` → s4; selainnya → s1 (retry) |
| `s4` | Increment `num`; → s5 |
| `s5` | Jika `num<10` → s1 (register berikutnya); jika `num=10` → `done='0'` (selesai) |

### 3.4 FSM I2C Port: `I2C_Port`
Mengontrol sinyal fisik `I2C_SCLK` dan `I2C_SDAT` (SDO) berdasarkan index 0..32:

| Index | Aksi |
|-------|------|
| 0 | Idle: SDO='1', SCLK='1' |
| 1 | START: SDO='0' (SDA turun saat SCL tinggi) |
| 3..10 | Kirim 8-bit alamat (0x34, write) |
| 11 | Release SDA untuk ACK byte 1 |
| 12..19 | Kirim `i2c_out[15:8]` (byte atas register) |
| 20 | Release SDA untuk ACK byte 2 |
| 21..28 | Kirim `i2c_out[7:0]` (byte bawah register) |
| 29 | Release SDA untuk ACK byte 3 |
| 30 | STOP setup: SCLK='0' |
| 32 | STOP: SDO='1'; `i2c_end='1'` |

**Alamat I2C:** `0x34` (WM8731, 7-bit=0x1A, + bit write=0)

---

> **[LANJUTAN PART 2: receiver_hdl pipeline]**

---

## 4. `receiver_hdl/` — Pipeline Korelator IQ Preamble

Pipeline ini memproses sinyal audio input secara real-time untuk mendeteksi pola preamble `#,#,3,#` dan menghasilkan sinyal `enable` yang mengaktifkan Goertzel decoder.

### 4.1 Urutan Pipeline & Koneksi Sinyal

```
dataA (Lin, 16-bit) ──→ [multv6] ──→ [Framingv2] ──→ [powercalcv1] ──→ [slidingv5]
        ↑ LUT sin/cos                                                          │
 [lutsin_block]                                                          sum_697/941/1477
 [lutcos_block]                                                                │
                                                                        ┌──────▼──────┐
                                                                        │ [dec_control]│
                                                                        │  (mux)       │
                                                                        └──┬────────┬──┘
                                                              flag_invalid │        │ mark_invalid
                                                                           ▼        ▼
                                                                     [flaggingv2] [markingv1]
                                                                      onoff_mark   enable/markout
                                                                           │             │
                                                                     mark_enable ──→ dec_control → enable (out)
```

Semua modul menggunakan **valid-ready handshake** (AXI-Stream style).

---

### 4.2 `multv6.vhd` — Multiplier IQ

**Entity:** `multv6`

**Fungsi:** Mengalikan sampel audio input `dataA` dengan nilai sin dan cos dari LUT untuk 3 frekuensi preamble (697, 941, 1477 Hz). Menghasilkan 6 produk fixed-point (sin×data, cos×data per frekuensi).

**Format Data:**
- Input `dataA`: 16-bit signed → dikonversi ke `sfixed Q3.13`
- Input LUT sin/cos: 16-bit → dikonversi ke `sfixed Q3.13`
- Output `multsin/cos_*`: `sfixed Q3.13` (Q format: `mult_INT_BITS=3`, `mult_FRAC_BITS=13`)

**FSM States:** `IDLE | COMPUTE | STORE`

| State | Aksi |
|-------|------|
| `IDLE` | Konversi `dataA`, sin, cos ke sfixed; `in_ready='1'`; saat `in_valid='1'` → `COMPUTE` |
| `COMPUTE` | Hitung 6 perkalian: `tempinput * tempsin697`, dst; → `STORE` |
| `STORE` | Output 6 hasil ke port; increment `address_internal` (mod 640); tunggu `out_ready='1'`; → `IDLE` |

**Address LUT:** `address_internal` range `0..640`, increment tiap sample. Address 10-bit ini digunakan bersama oleh `lutsin_block` dan `lutcos_block` sebagai index tabel sin/cos.

---

### 4.3 `Framingv2.vhd` — Accumulator Frame (40 Sampel)

**Entity:** `Framingv2`

**Fungsi:** Mengakumulasi 40 produk IQ (hasil multv6) menjadi satu frame. Ini setara dengan integrasi koheren selama 40 sampel (≈1.25 ms pada 32 KHz).

**Format Data:**
- Input: `sfixed Q3.13` (data_INT_BITS=3, data_FRAC_BITS=13)
- Output (accumulator): `sfixed Q8.8` (acc_INT_BITS=8, acc_FRAC_BITS=8)

**Sinyal internal:**
```vhdl
signal counter : INTEGER range 0 to 40 := 0;
signal run_sin697, run_sin941, run_sin1477 : sfixed Q8.8;
signal run_cos697, run_cos941, run_cos1477 : sfixed Q8.8;
```

**FSM States:** `IDLE | COMPUTE | STORE`

| State | Aksi |
|-------|------|
| `IDLE` | `in_ready='1'`; saat `in_valid='1'` → `COMPUTE` |
| `COMPUTE` | `run_sin697 += multsin697`; dst untuk semua 6 akumulator; jika `counter<39`: counter++, → `IDLE`; jika `counter=39`: → `STORE` |
| `STORE` | Output 6 nilai akumulator ke port; reset semua akumulator ke 0; `counter=0`; `out_valid='1'`; tunggu `out_ready='1'`; → `IDLE` |

**Catatan:** Setiap frame = 40 input sample. Counter berjalan 0..39 (40 iterasi IDLE→COMPUTE). Akumulator direset di STORE (bukan di IDLE) agar nilai bersih untuk frame berikutnya.

---

### 4.4 `powercalcv1.vhd` — Kalkulasi Daya IQ

**Entity:** `powercalcv1`

**Fungsi:** Menghitung daya 3 frekuensi: `power = sin² + cos²` (magnitude kuadrat IQ).

**Format Data:**
- Input: `sfixed Q8.8` (in_INT_BITS=8, in_FRAC_BITS=8)
- Temp (sq): `sfixed Q12.4` (sq_INT_BITS=12, sq_FRAC_BITS=4)
- Output: `sfixed Q12.4` (out_INT_BITS=12, out_FRAC_BITS=4)

**FSM States:** `IDLE | COMPUTE | STORE`

| State | Aksi |
|-------|------|
| `IDLE` | Hitung `tempsin* = in_sin* * in_sin*` dan `tempcos* = in_cos* * in_cos*` (6 squaring); tunggu `in_valid='1'`; → `COMPUTE` |
| `COMPUTE` | `power_697 = tempsin697 + tempcos697`; dst untuk 941 dan 1477; → `STORE` |
| `STORE` | Output `out_697/941/1477`; `out_valid='1'`; tunggu `out_ready='1'`; → `IDLE` |

**Catatan:** Squaring dilakukan di IDLE (satu siklus lebih awal) untuk mengurangi latency pipeline.

---

### 4.5 `slidingv5.vhd` — Sliding Window Sum (16 Batch)

**Entity:** `slidingv5`

**Fungsi:** Menjumlahkan daya dari 16 batch terakhir (sliding window) untuk memperhalus kurva energi dan mengurangi efek noise transien.

**Format Data:**
- Input (per batch): `sfixed Q12.4` (in_INT_BITS=12, in_FRAC_BITS=4)
- Output (sum 16 batch): `sfixed Q15.1` (out_INT_BITS=15, out_FRAC_BITS=1)

**Buffer Circular:** Ukuran tetap 16 slot (hardcoded), satu per frekuensi:
```vhdl
type cbuffer_697 is array (0 to 15) of sfixed Q15.1;
signal cbuffer697, cbuffer941, cbuffer1477 : cbuffer_*;
signal index      : integer range 0 to 15 := 0;
signal fill_count : integer range 0 to 16 := 0;
```

**FSM States:** `IDLE | COMPUTE | STORE`

| State | Aksi |
|-------|------|
| `IDLE` | Tulis nilai input ke `cbuffer*(index)` (write-on-entry); `in_ready='1'`; saat `in_valid='1'` → `COMPUTE` |
| `COMPUTE` | Jumlahkan semua 16 slot cbuffer697/941/1477 (flat sum); increment `index` (mod 16); jika `fill_count<14`: fill_count++, → `IDLE`; jika `fill_count>=14`: → `STORE` |
| `STORE` | Output `sum_697/941/1477`; `out_valid='1'`; tunggu `out_ready='1'`; → `IDLE` |

**Threshold Pengisian:** Output hanya aktif setelah `fill_count >= 14` (buffer cukup terisi). Buffer tidak dikosongkan pada soft reset (`rx_rst`), hanya pada `master_reset` (KEY0).

**Reset Behavior:**
- `master_reset='1'`: Reset semua (state, buffer, index, fill_count, sum)
- `reset='1'` (soft): Hanya reset state dan akumulator sum; **buffer, index, fill_count dipertahankan** → recovery time ≈ beberapa siklus clock vs ~320 ms jika buffer ikut direset

---

### 4.6 `flaggingv2.vhd` — Detektor Simbol `##` (Preamble Awal)

**Entity:** `flaggingv2`

**Fungsi:** Mendeteksi kehadiran dua simbol `#` berturut-turut dengan memeriksa kenaikan energi pada 941 Hz dan 1477 Hz secara independen menggunakan sliding window lookback.

**Generics (nilai aktif di hardware):**
```vhdl
in_INT_BITS     : natural := 15    -- Format sfixed Q15.1
in_FRAC_BITS    : natural := 1
LOOKBACK_DEPTH  : natural := 16    -- Ukuran circular buffer lookback
THRESHOLD_COEFF : integer := 5     -- Pengali threshold: curr >= 5 * prev_lookback
GUARD_FLOOR     : real    := 32.0  -- Batas daya minimum absolut
```

**Buffer Circular Lookback:**
```vhdl
type cbuf_t is array (0 to LOOKBACK_DEPTH) of sfixed Q15.1;  -- 17 slot
signal cbuffer941, cbuffer1477 : cbuf_t;
signal index : integer range 0 to LOOKBACK_DEPTH := 0;
signal full  : std_logic := '0';   -- '1' setelah slot LOOKBACK_DEPTH (index=16) terisi
```

**Counter Independen & SR Latch Per Frekuensi:**
```vhdl
signal count_941, count_1477 : integer range 0 to 5 := 0;
signal detect_941, detect_1477 : std_logic := '0';  -- Level-sensitive, bukan SR latch permanen
```

**FSM States:** `IDLE | COMPUTE | STORE`

| State | Aksi |
|-------|------|
| `IDLE` | Capture `new941=in_941`, `new1477=in_1477`; Baca `old_941 = THRESHOLD_COEFF * cbuffer941(index)` (nilai lookback lalu); saat `in_valid='1'` → `COMPUTE` |
| `COMPUTE` | **941 Hz:** jika `new941 >= old_941 AND new941 > GUARD_FLOOR`: `count_941++` (maks 5); selain itu: `count_941=0`. **1477 Hz:** sama independen. **Deteksi level-sensitive:** `detect_941 = (count_941 >= 4)`; `detect_1477 = (count_1477 >= 4)`. **SR latch onoff_mark:** jika `detect_941='1' AND detect_1477='1'`: `onoff_mark <= '1'` (tidak pernah kembali '0' kecuali reset). → `STORE` |
| `STORE` | Tulis `in_941/in_1477` ke `cbuffer*(index)`; jika `index=LOOKBACK_DEPTH`: `full='1'`; advance index (mod LOOKBACK_DEPTH+1); → `IDLE` |

**Catatan COMPUTE timing RTL:** Karena clocked, nilai `count_941` baru efektif di siklus berikutnya. Threshold RTL `>= 4` setara MATLAB `>= 5` (kompensasi 1-cycle delay).

**Level-Sensitive (bukan SR latch):** `detect_941/1477` di-clear jika counter turun di bawah 4. Ini mencegah akumulasi noise spike dari waktu berbeda memicu false flag.

**Reset Behavior:**
- `master_reset='1'`: Reset semua termasuk buffer dan `full`
- `reset='1'` (soft): Reset state, count, detect, onoff_mark; **buffer dan index dipertahankan**

---

### 4.7 `markingv1.vhd` — Detektor Transisi Simbol `3`

**Entity:** `markingv1`

**Fungsi:** Setelah `##` terdeteksi (onoff_mark='1'), mendeteksi simbol `3` (697 Hz dominan) untuk memastikan pola `##3#` lengkap, lalu mengunci `enable='1'` secara permanen (SR latch).

**Generics (nilai aktif):**
```vhdl
in_INT_BITS     : natural := 15
in_FRAC_BITS    : natural := 1
THRESHOLD_COEFF : real    := 0.53   -- ≈ 0.55 target MATLAB v7; sfixed(0 downto -16)
GUARD_FLOOR     : real    := 32.0   -- Batas daya minimum 697 Hz
```

**Logika Utama (Normalized Power Difference / NPD):**
```vhdl
-- Kondisi yang harus terpenuhi (dari MATLAB v7 marking.m):
-- P697 >= THRESHOLD_COEFF * (P697 + P941)
-- Implementasi VHDL (tanpa divisi):
constant THRESHOLD_VAL : sfixed(0 downto -16) := to_sfixed(THRESHOLD_COEFF, 0, -16);
-- Di state COMPUTE:
if (curr_697 >= resize(THRESHOLD_VAL * (curr_697 + curr_941), curr_697)) AND
   (curr_697 > to_sfixed(GUARD_FLOOR, curr_697)) then
    enable_i <= '1';  -- SR latch: sekali '1', tidak pernah kembali '0'
end if;
```

**FSM States:** `IDLE | COMPUTE | STORE`

| State | Aksi |
|-------|------|
| `IDLE` | `in_ready='1'`; saat `in_valid='1'`: capture `curr_697=in_697`, `curr_941=in_941`; → `COMPUTE` |
| `COMPUTE` | Jika `enable_i='0'`: cek kondisi NPD; jika terpenuhi: `enable_i='1'`; → `STORE` |
| `STORE` | `out_valid='1'`; tunggu `out_ready='1'`; → `IDLE` |

**SR Latch:** `enable_i` hanya bisa '0'→'1', tidak pernah '1'→'0'. Direset hanya oleh `reset='1'`.

**Catatan Historis:** Sebelumnya modul ini menggunakan:
1. Pembandingan diferensial `curr_697 > curr_941` (v11 Jul)
2. Pelacakan dinamis ref_697/ref_941 (Opsi B, 12 Jul Rev2)
3. Debounce `consec_cnt` 2-batch (12 Jul Rev2, dihapus di Rev10 13 Jul)

Versi saat ini (Rev10 13 Jul): **NPD langsung assert SR latch tanpa debounce**.

---

### 4.8 `dec_control.vhd` — Mux Kontrol Flagging/Marking

**Entity:** `dec_control`

**Fungsi:** Multiplexer handshake. Mengarahkan sinyal `in_valid/out_ready` dari upstream ke modul `flaggingv2` atau `markingv1` bergantung status `mark_enable`.

```vhdl
-- mark_enable='0': routing ke flagging
-- mark_enable='1': routing ke marking
if mark_enable = '1' then
    in_valid_mark  <= in_valid;   -- routing ke markingv1
    out_ready_mark <= out_ready;
    in_ready       <= in_ready_mark;
    out_valid      <= out_valid_mark;
    in_valid_flag  <= '0';
else
    in_valid_flag  <= in_valid;   -- routing ke flaggingv2
    out_ready_flag <= out_ready;
    in_ready       <= in_ready_flag;
    out_valid      <= out_valid_flag;
    in_valid_mark  <= '0';
end if;
mark_out <= mark_in;  -- Pass-through enable signal
```

`mark_enable` terhubung ke `onoff_mark` dari `flaggingv2`. Setelah `##` terdeteksi, semua batch berikutnya diarahkan ke `markingv1`.

---

### 4.9 `toplevel_iq_fpga.vhd` — Wrapper Korelator IQ (Hardware)

**Entity:** `toplevel_iq_fpga`

**Generics (nilai instansiasi di AcakCakap_Top):**
```vhdl
mult_INT_BITS   => 2,   mult_FRAC_BITS  => 14,  -- Q2.14
acc_INT_BITS    => 6,   acc_FRAC_BITS   => 10,  -- Q6.10
power_INT_BITS  => 10,  power_FRAC_BITS => 6,   -- Q10.6
batch_INT_BITS  => 14,  batch_FRAC_BITS => 2,   -- Q14.2
GUARD_FLOOR     => 32.0
```

**Instansiasi Komponen Internal:**
| Instance | Entity | Parameter Kunci |
|----------|--------|-----------------|
| `mult_unit` | `multv6` | Q3.13 → Q3.13 |
| `lutsin_unit` | `lutsin_block` | address 10-bit → sin 697/941/1477 Hz |
| `lutcos_unit` | `lutcos_block` | address 10-bit → cos 697/941/1477 Hz |
| `framing` | `Framingv2` | Q3.13 → Q8.8, 40 samples/frame |
| `powercalc` | `powercalcv1` | Q8.8 → Q12.4 |
| `batch_unit` | `slidingv5` | Q12.4 → Q15.1, window=16 |
| `flag_unit` | `flaggingv2` | `LOOKBACK_DEPTH=16`, `THRESHOLD_COEFF=5`, `GUARD_FLOOR=GUARD_FLOOR` |
| `mark_unit` | `markingv1` | `THRESHOLD_COEFF=0.53`, `GUARD_FLOOR=GUARD_FLOOR` |
| `cntrl_unit` | `dec_control` | — |

**Sinyal Handshake Rantai:**
```
in_valid→[multv6]→v2v1→[Framingv2]→v2v2→[powercalcv1]→v2v3→[slidingv5]→v2v4→[dec_control]→enable
         r2r1←         r2r2←             r2r3←              r2r4←      r2r4←
```

**Output `enable`:** Dihubungkan via `cntrl_unit` yang mem-pass-through `markout` (output `markingv1`) ke port `enable` wrapper.

---

> **[LANJUTAN PART 3: dtmf_detect_hdl pipeline]**

---

## 5. `dtmf_detect_hdl/` — Pipeline Dekoder DTMF Payload

Pipeline ini memproses sinyal audio aktif (setelah `goertzel_enable='1'`) untuk mendeteksi frekuensi DTMF per simbol dan mengumpulkan 8 simbol payload menjadi kunci 32-bit.

### 5.1 Urutan Pipeline

```
goertzel_enable (= Ldone AND enable AND goertzel_aligned)
        │
        ▼
[Goertzel_top] — 8 filter paralel, BLOCK_SIZE=640 sampel per simbol
  power_697, power_770, power_852, power_941 (low group)
  power_1209, power_1336, power_1477, power_1633 (high group)   (17-bit each)
        │ goertzel_out_valid='1'
        ▼
[top_dtmfencode]
  ┌── [lowcomparator] → codelow (3-bit)  ──┐
  │                                         ├── [decision] → dtmf_code (4-bit) → [shift_add] → output32 (32-bit)
  └── [highcomparator] → codehigh (3-bit) ──┘
```

---

### 5.2 `Goertzel.vhd` — Filter Goertzel Satu Frekuensi

**Entity:** `Goertzel`

**Generics:**
```vhdl
DATA_WIDTH : integer := 16      -- Lebar data input/output
BLOCK_SIZE : integer := 640     -- Jumlah sampel per window (20 ms @ 32 KHz)
COEFF      : real := 1.98113... -- 2*cos(2*pi*f/32000), berbeda tiap frekuensi
```

**Format Fixed-Point Internal:**
| Signal | Format | Keterangan |
|--------|--------|-----------|
| `coeff_sfixed` | Q2.14 | Koefisien filter Goertzel |
| `DTMF_sampled` | Q2.14 | Sample input |
| `Q0/Q1/Q2_reg` | Q13.3 | Register delay rekursi |
| `coeff_Q1` | Q14.2 | Produk koeff × Q1 |
| `x_min_q2` | Q13.3 | Selisih x − Q2 |
| `power_fix` | sfixed(23..0) | Hasil daya sebelum output |
| `power` (output) | 17-bit | Hasil daya ter-saturasi |

**Algoritma Goertzel — Fase Rekursi** (per sampel, `BLOCK_SIZE` iterasi):
```
Q0 = coeff * Q1 - Q2 + x[n]
Q2 = Q1
Q1 = Q0
```

**Algoritma Goertzel — Fase Kalkulasi Daya** (setelah BLOCK_SIZE sampel):
```
Power = |Q1|² + |Q2|² - coeff * Q1 * Q2
```

**FSM States:** `IDLE | COMPUTE_FILTER_1..3 | STORE_TO_Q0 | UPDATE | COMPUTE_POWER_1..5 | OUTPUT`

| State | Aksi |
|-------|------|
| `IDLE` | `in_ready='1'`; capture `DTMF_sampled`; → `COMPUTE_FILTER_1` |
| `COMPUTE_FILTER_1` | Load multiplier (coeff × Q1) dan subtractor (x − Q2); → `COMPUTE_FILTER_2` |
| `COMPUTE_FILTER_2` | Simpan hasil: `coeff_Q1`, `x_min_q2`; → `COMPUTE_FILTER_3` |
| `COMPUTE_FILTER_3` | Load adder (`coeff_Q1 + x_min_q2`); → `STORE_TO_Q0` |
| `STORE_TO_Q0` | `Q0_reg = resize(add_out)`; → `UPDATE` |
| `UPDATE` | `Q2=Q1`, `Q1=Q0`; jika `counter<BLOCK_SIZE-1`: counter++, → `IDLE`; jika `counter=BLOCK_SIZE-1`: counter=0, → `COMPUTE_POWER_1` |
| `COMPUTE_POWER_1` | Square Q1, multiply coeff×Q1; → `COMPUTE_POWER_2` |
| `COMPUTE_POWER_2` | Simpan `Q1_squared`, `coeff_Q1`; square Q2; → `COMPUTE_POWER_3` |
| `COMPUTE_POWER_3` | Simpan `Q2_squared`; load `mult_coeff_q1 * Q2`; → `COMPUTE_POWER_4` |
| `COMPUTE_POWER_4` | `Q1_sq+Q2_sq = Q2_squared+Q1_squared`; **`coeff_Q1_Q2 = resize(mult_out_2, 23, 0)`** (bug fix kritis!); → `COMPUTE_POWER_5` |
| `COMPUTE_POWER_5` | `power_fix = abs(sfixed(Q1_sq+Q2_sq) - coeff_Q1_Q2)`; → `OUTPUT` |
| `OUTPUT` | Konversi ke 17-bit (saturasi); `out_valid='1'`; saat `out_ready='1'`: reset Q0/Q1/Q2 dan register temp, → `IDLE` |

**Bug Fix Kritis (Revisi 12 Jul 2026):** Register `coeff_Q1_Q2` sebelumnya tidak diperbarui di `COMPUTE_POWER_4`. Akibatnya daya filter tidak akurat dan menyebabkan misdeteksi (misal '8' terbaca '5' pada kunci `0x88888888`). Diperbaiki dengan menambahkan:
```vhdl
-- COMPUTE_POWER_4:
coeff_Q1_Q2 <= resize(mult_out_2, 23, 0);
```

---

### 5.3 `Goertzel_top.vhd` — Bank 8 Filter Goertzel Paralel

**Entity:** `Goertzel_top`

**Generics:** `DATA_WIDTH=16`, `BLOCK_SIZE=640`

**Koefisien Frekuensi** (`2*cos(2*pi*f/32000)`):
| Frekuensi | Konstanta | Nilai |
|-----------|-----------|-------|
| 697 Hz | `COEFF_697` | 1.981299751034064 |
| 770 Hz | `COEFF_770` | 1.977185350114547 |
| 852 Hz | `COEFF_852` | 1.972079326472499 |
| 941 Hz | `COEFF_941` | 1.965958931999434 |
| 1209 Hz | `COEFF_1209` | 1.943911740684265 |
| 1336 Hz | `COEFF_1336` | 1.931580353106243 |
| 1477 Hz | `COEFF_1477` | 1.916483020260862 |
| 1633 Hz | `COEFF_1633` | 1.898236173491410 |

**Sinyal Ready/Valid:**
```vhdl
-- Top-level ready = semua filter siap
in_ready <= ready_697 AND ready_770 AND ... AND ready_1633;
-- Top-level valid = semua filter output valid
out_valid <= valid_697 AND valid_770 AND ... AND valid_1633;
```

Semua 8 filter menerima input yang sama (`in_valid`, `DTMF_sig`) dan bekerja paralel.

---

### 5.4 `lowcomparator.vhd` — Komparator Frekuensi Rendah

**Entity:** `lowcomparator`

**Generics:** `THRESHOLD_VAL : integer := 800`

**Fungsi:** Menentukan frekuensi dominan dari grup rendah (697, 770, 852, 941 Hz) dengan membandingkan nilai daya. Output `code` 3-bit mengidentifikasi baris DTMF.

**Threshold:** `THRESHOLD : SLV(16:0) = to_unsigned(THRESHOLD_VAL, 17)` = 800

**FSM States:** `IDLE | COMPUTE | STORE`

**Logika COMPUTE (priority encoder):**
```
Jika 697 > 770 AND 697 > 852 AND 697 > 941 AND 697 > THRESHOLD: code="001"
Jika 770 > 697 AND 770 > 852 AND 770 > 941 AND 770 > THRESHOLD: code="010"
Jika 852 > 697 AND 852 > 770 AND 852 > 941 AND 852 > THRESHOLD: code="011"
Jika 941 > 697 AND 941 > 770 AND 941 > 852 AND 941 > THRESHOLD: code="100"
Selain itu (noise/silence): code="000"
```

**Catatan:** Kondisi prioritas diurut 697→770→852→941. Jika ada seri (energi sama), code="000".

---

### 5.5 `highcomparator.vhd` — Komparator Frekuensi Tinggi

**Entity:** `highcomparator`

**Generics:** `THRESHOLD_VAL : integer := 800`

**Fungsi:** Menentukan frekuensi dominan dari grup tinggi (1209, 1336, 1477, 1633 Hz).

**Logika COMPUTE (identik dengan lowcomparator, grup tinggi):**
```
Jika 1209 > 1336 AND 1209 > 1477 AND 1209 > 1633 AND 1209 > THRESHOLD: code="001"
Jika 1336 > 1209 AND 1336 > 1477 AND 1336 > 1633 AND 1336 > THRESHOLD: code="010"
Jika 1477 > 1209 AND 1477 > 1336 AND 1477 > 1633 AND 1477 > THRESHOLD: code="011"
Jika 1633 > 1209 AND 1633 > 1336 AND 1633 > 1477 AND 1633 > THRESHOLD: code="100"
Selain itu: code="000"
```

---

### 5.6 `decision.vhd` — Dekoder Simbol DTMF

**Entity:** `decision`

**Fungsi:** Menggabungkan `code_low` (3-bit baris) dan `code_high` (3-bit kolom) menjadi nilai simbol DTMF 4-bit.

**FSM States:** `IDLE | COMPUTE | STORE`

**Tabel Dekoding (state COMPUTE):**
| codelow | codehigh | dtmf_code | Simbol |
|---------|----------|-----------|--------|
| 001 (697) | 001 (1209) | 0001 | 1 |
| 001 (697) | 010 (1336) | 0010 | 2 |
| 001 (697) | 011 (1477) | 0011 | 3 |
| 001 (697) | 100 (1633) | 1010 | A |
| 010 (770) | 001 (1209) | 0100 | 4 |
| 010 (770) | 010 (1336) | 0101 | 5 |
| 010 (770) | 011 (1477) | 0110 | 6 |
| 010 (770) | 100 (1633) | 1011 | B |
| 011 (852) | 001 (1209) | 0111 | 7 |
| 011 (852) | 010 (1336) | 1000 | 8 |
| 011 (852) | 011 (1477) | 1001 | 9 |
| 011 (852) | 100 (1633) | 1100 | C |
| 100 (941) | 001 (1209) | 1110 | * (E) |
| 100 (941) | 010 (1336) | 0000 | 0 |
| 100 (941) | 011 (1477) | 1111 | # (F) |
| 100 (941) | 100 (1633) | 1101 | D |
| lainnya | — | 0000 | (silence/noise) |

**Alur FSM:**
- `IDLE`: Saat `in_valid='1'`: latch `codelow/codehigh`; → `COMPUTE`
- `COMPUTE`: Lakukan lookup tabel → simpan ke `code_temp` dan `sevseg`; → `STORE`
- `STORE`: `out_valid='1'`; saat `out_ready='1'`: output `dtmf_code=code_temp`; → `IDLE`

---

### 5.7 `shift_add.vhd` — Pengumpul Kunci 32-bit

**Entity:** `shift_add`

**Fungsi:** Menerima 8 simbol DTMF 4-bit secara berurutan dan menggesernya ke register 32-bit. Menghasilkan `out_valid='1'` setelah tepat 8 simbol diterima.

**Sinyal Internal:**
```vhdl
signal counter  : integer range 0 to 8 := 0;
signal temp_sig : std_logic_vector(31 downto 0) := (others => '0');
```

**FSM States:** `IDLE | COMPUTE | STORE`

| State | Aksi |
|-------|------|
| `IDLE` | `in_ready='1'`, `out_valid='0'`; saat `in_valid='1'` → `COMPUTE` |
| `COMPUTE` | `temp_sig = shift_left(temp_sig, 4)`; `temp_sig(3:0) = input3`; `counter++`; → `STORE` |
| `STORE` | Jika `counter=8`: `output32=temp_sig`, `out_valid='1'`, `counter=0`; Jika `counter<8`: `out_valid='0'`; tunggu `out_ready='1'`; → `IDLE` |

**Urutan Pengisian:** MSB masuk pertama (Seg 4 → bit31..28), digeser kiri 4 bit per simbol. Setelah 8 simbol: `output32 = [Seg4][Seg5][Seg6][Seg7][Seg8][Seg9][Seg10][Seg11]`.

**Catatan Historis:** Modul ini sempat dimodifikasi dengan Mekanisme 1 (Time-Slotted Key Collector, Revisi 12 Jul) yang menambahkan port `tone_present` dan `false_trigger`, namun **di-rollback total pada Revisi 8 (12 Jul)** karena meningkatkan frame loss. Versi saat ini adalah arsitektur FIFO asli: shift hanya saat `tone_valid='1'` (nada DTMF valid terdeteksi).

---

### 5.8 `top_dtmfencode.vhd` — Wrapper Dekoder DTMF

**Entity:** `top_dtmfencode`

**Generics:** `THRESHOLD_VAL : integer := 1000` (di file), namun di instansiasi `AcakCakap_Top` dikirim **`THRESHOLD_VAL => 800`**

**Sinyal Kontrol Internal:**
```vhdl
signal r2r1, v2vh, v2vl : STD_LOGIC;   -- Handshake
signal r2r2, v2v2, v2v3 : STD_LOGIC;   -- v2v2=low&high valid, v2v3=decision out
signal lowready, highready : STD_LOGIC;
signal codelow, codehigh  : STD_LOGIC_VECTOR(2 downto 0);
signal code_dtmf          : STD_LOGIC_VECTOR(3 downto 0);  -- Output decision
signal tone_valid         : STD_LOGIC;
```

**Logika Kombinatorial:**
```vhdl
in_ready  <= lowready AND highready;   -- Siap terima jika kedua komparator siap
v2v2      <= v2vl AND v2vh;           -- Valid ke decision jika keduanya valid
tone_valid <= '1' when (v2v3='1' AND codelow/="000" AND codehigh/="000") else '0';
             -- Nada valid: decision sudah output DAN bukan silence
r2r1 <= '1';  -- out_ready selalu '1' untuk decision (non-blocking)
```

**Instansiasi dan Koneksi:**
| Instance | Entity | Sinyal Kunci |
|----------|--------|-------------|
| `comp_low` | `lowcomparator` | `in_valid=in_valid`, `out_ready=r2r2`, `out_valid=v2vl`, `code=codelow` |
| `comp_high` | `highcomparator` | `in_valid=in_valid`, `out_ready=r2r2`, `out_valid=v2vh`, `code=codehigh` |
| `dec_DTMF` | `decision` | `in_valid=v2v2`, `out_ready=r2r1('1')`, `in_ready=r2r2`, `out_valid=v2v3` |
| `key_collector` | `shift_add` | `in_valid=tone_valid`, `out_ready=out_ready`, `out_valid=out_valid` |

**Alur Data Per Simbol:**
```
Goertzel selesai → [lowcomp + highcomp] paralel → v2v2='1' → [decision] → v2v3='1'
→ tone_valid (jika code≠000) → [shift_add] → setelah 8 simbol: out_valid='1' → kunci 32-bit
```

---

## 6. Tabel Parameter Kritis & Threshold

| Parameter | Nilai | Lokasi | Keterangan |
|-----------|-------|--------|-----------|
| `SAMPLES_PRE_SILENCE` | 1600 | `AcakCakap_Top` | 50 ms silence sebelum preamble |
| `SAMPLES_20MS` | 640 | `AcakCakap_Top` | 1 simbol DTMF = 640 sampel |
| `align_counter` limit | **817** | `AcakCakap_Top` | Penyelarasan window Goertzel ke batas simbol payload |
| Cooldown duration | 1600 | `AcakCakap_Top` | 40 ms setelah decode/timeout |
| Watchdog timeout | 5529600 | `AcakCakap_Top` | 300 ms @ 18.432 MHz |
| `CLKS_PER_BIT` UART | 160 | `AcakCakap_Top` | 18.432 MHz / 115200 bps |
| `DEBOUNCE_LIMIT` | 1000000 | `AcakCakap_Top` | Debounce KEY @ 50 MHz |
| `THRESHOLD_VAL` Goertzel | **800** | Instansiasi top | Min daya simbol DTMF valid (17-bit) |
| `GUARD_FLOOR` korelator | **20.0** | Instansiasi DTMF_corr | Min daya absolut preamble (sfixed) — diturunkan dari 32.0 pada 17 Jul |
| `THRESHOLD_COEFF` flagging | **4** | `flaggingv2` instansiasi | curr >= 4 × prev_lookback — diturunkan dari 5 pada 17 Jul |
| `LOOKBACK_DEPTH` flagging | 16 | `flaggingv2` instansiasi | Depth circular buffer lookback |
| count threshold flagging | **3** (RTL) ≡ 4 (MATLAB) | `flaggingv2` COMPUTE | Level-sensitive detect threshold — diturunkan dari 4(RTL)/5(MATLAB) pada 17 Jul |
| `THRESHOLD_COEFF` marking | **0.47** | `markingv1` instansiasi | NPD ratio — diturunkan dari 0.53 pada 17 Jul |
| `GUARD_FLOOR` marking | **32.0** | `markingv1` instansiasi | Min daya 697 Hz untuk marking |
| `BLOCK_SIZE` Goertzel | 640 | `Goertzel_top` | Sampel per window analisis |
| WM8731 Lin/Rin gain | `0x1C` (+7.5 dB) | `i2c.vhd` Audio_init[0,1] | Gain input ADC |
| fill_count threshold | 14 | `slidingv5` | Buffer dianggap "cukup terisi" |
| Framingv2 frame size | 40 | `Framingv2` counter | Sampel per batch IQ |

---

## 7. Catatan Penting untuk Modifikasi

1. **Mengubah `align_counter`**: Nilai 817 adalah hasil kalibrasi empiris dan simulasi. Perubahan gain WM8731, panjang kabel, atau karakteristik saluran dapat menggeser timing rising edge `enable` dan membutuhkan penyesuaian nilai ini. Sweep otomatis pernah dilakukan dari 850 hingga 870 (nilai lama 857).

2. **Threshold `GUARD_FLOOR`**: Nilai 32.0 adalah kompromi antara sensitivitas preamble dan imunitas noise. Naikkan jika false trigger banyak di environment berisik; turunkan jika frame loss tinggi di environment sunyi.

3. **Soft Reset vs Hard Reset**: Selalu bedakan `rx_rst` (soft) dan `aud_rst` (hard/KEY0). Buffer korelator di `slidingv5` dan `flaggingv2` **tidak dikosongkan** pada soft reset untuk menghindari blind period ~320 ms.

4. **SR Latch `onoff_mark` dan `enable_i`**: Kedua sinyal ini tidak pernah kembali ke '0' kecuali soft reset. Ini by design agar korelator tidak "lupa" preamble yang sudah terdeteksi.

5. **`tone_valid` vs `v2v3`**: `tone_valid` adalah `v2v3 AND codelow≠"000" AND codehigh≠"000"`. Perbedaan ini penting: `v2v3` muncul tiap simbol (termasuk silence), `tone_valid` hanya untuk simbol dengan nada DTMF yang teridentifikasi jelas.

6. **Goertzel `coeff_Q1_Q2`**: Pastikan register ini selalu diupdate di `COMPUTE_POWER_4` (bug fix 12 Jul). Tanpa ini, daya filter tidak akurat.

7. **Level-Sensitive Detection di `flaggingv2`**: `detect_941/1477` sekarang bukan SR latch permanen. Keduanya di-clear jika counter turun. Ini mencegah false flag dari spike noise berselang di waktu berbeda.

---

## 8. Hubungan Kuantitatif Antar-Layer Pipeline (Kritis untuk Timing Debug)

### 8.1 Hirarki Waktu Satu Simbol DTMF

```
1 simbol DTMF = 640 sampel audio @ 32 KHz = 20 ms
                │
                ├── Framingv2 batch: 40 sampel per batch
                │   → 640 / 40 = 16 batch per simbol
                │
                └── slidingv5 window: 16 batch
                    → 1 simbol = mengisi tepat 1 putaran penuh sliding window
```

**Implikasi:** `LOOKBACK_DEPTH = 16` di `flaggingv2` bukan angka sembarang — ini setara persis dengan durasi 1 simbol DTMF dalam satuan batch. Artinya perbandingan `curr >= THRESHOLD_COEFF * prev_lookback` membandingkan energi batch saat ini dengan energi batch dari **1 simbol yang lalu** (320 ms ke belakang tidak berlaku — ini hanya 16 batch = 1 simbol = 20 ms ke belakang).

### 8.2 Derivasi `align_counter = 817`

Masalah yang dipecahkan: Setelah `enable` naik (preamble terdeteksi), kapan tepatnya Goertzel harus mulai membaca agar jendela 640-sampelnya jatuh **tepat** di awal Seg 4 (payload pertama)?

**Kronologi sampel dalam satu frame:**

| Sampel ke- | Event |
|-----------|-------|
| 0 – 1599 | PRE_SILENCE (50 ms, 1600 sampel) |
| 1600 – 2239 | Seg 0: `#` (simbol 0) |
| 2240 – 2879 | Seg 1: `#` (simbol 1) |
| 2880 – 3519 | Seg 2: `3` (simbol 2) |
| 3520 – 4159 | Seg 3: `#` (simbol 3, terakhir preamble) |
| **4160** | **Seg 4 dimulai (payload pertama)** |

**Kapan `enable` naik?**

Modul `markingv1` mendeteksi simbol `3` (Seg 2) menggunakan NPD dari output `slidingv5`. `slidingv5` mengeluarkan output setelah `fill_count >= 14`, dan setiap output mewakili 1 batch = 40 sampel. Deteksi biasanya terpicu di sekitar tengah atau akhir Seg 2 (saat energi 697 Hz mendominasi). Berdasarkan kalibrasi simulasi (testbench `tb_receiver_isolated`), `enable` naik sekitar **sampel ke-3302** (± beberapa batch).

**Perhitungan delay yang dibutuhkan:**
```
Sampel awal Seg 4       = 4160
Sampel enable naik (est) ≈ 3302
Selisih                 ≈ 858 sampel → 858 - 1 = 857 (indeks dari 0)
```

**Nilai saat ini di kode: `align_counter = 817`** — lebih kecil dari 857 karena:
- Timing tepat `enable` naik bergantung pada karakteristik hardware riil (gain codec, noise floor)
- Nilai 817 diperoleh dari sweep hardware dan memberikan hasil decode 100% pada pengujian riil
- Nilai 857 pernah dipakai di testbench simulasi (`tb_receiver_isolated`)

> **Kesimpulan untuk debugger:** Jika payload terpotong di awal (beberapa bit pertama hilang), coba **naikkan** `align_counter`. Jika simbol preamble terakhir (`#` Seg 3) masuk ke Goertzel, coba **turunkan** `align_counter`. Rentang aman untuk eksperimen: **800 – 870**.

### 8.3 Mekanisme `goertzel_enable` — Gating 3-Jalur

```vhdl
goertzel_enable <= Ldone AND enable AND goertzel_aligned;
```

Ketiga kondisi harus '1' secara bersamaan:

| Sinyal | Sumber | Kapan '1' |
|--------|--------|-----------|
| `Ldone` | Audio_interface | Pulsa 1 siklus per sampel audio baru (@ 32 KHz) |
| `enable` | toplevel_iq_fpga → markingv1 SR latch | Setelah preamble `##3#` terdeteksi; permanen hingga rx_rst |
| `goertzel_aligned` | GOERTZEL_ALIGN_FSM | SR latch: set setelah 818 Ldone dari rising edge enable; reset oleh rx_rst |

**Diagram urutan (cycle-accurate):**

```
           rising edge enable
           │
Ldone:     _│‾_‾_‾_‾_... (tiap sampel audio)
enable:    __│‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾...
enable_d:  ___│‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾...
align_armed:   │'1' permanent─────────────────...
align_counter: 0,1,2,...816,817 → stop
goertzel_aligned: ──────────────────────────│'1'─...
goertzel_enable:  ________________________________│‾_‾_‾... (tepat 818 Ldone setelah enable naik)
```

---

## 9. Siklus Reset Setelah `out_valid='1'` (Urutan Cycle-by-Cycle)

Ini adalah urutan tepat yang terjadi setelah 8 simbol payload berhasil dikumpulkan:

```
Siklus N:   shift_add STORE: counter=8 → out_valid='1', output32 valid
Siklus N:   AcakCakap_Top: out_valid='1' terdeteksi
              → rx_cooldown_cnt <= 1600
              → rx_cooldown_active <= '1'   [di proses cooldown timer]
              → display_key <= reconstructed_key_32bit  [di proses display]

Siklus N+1: rx_rst (registered) <= out_valid OR rx_timeout_rst OR rx_cooldown_active
              = '1' OR '0' OR '1' = '1'
              rx_rst aktif mulai siklus ini

Siklus N+1: GOERTZEL_ALIGN_FSM menerima rx_rst='1':
              → enable_d='0', align_armed='0', align_counter=0, goertzel_aligned='0'
              (Goertzel sekarang tidak bisa aktif lagi meski enable masih '1')

Siklus N+1: toplevel_iq_fpga menerima reset='1' (rx_rst):
              → slidingv5: FSM=IDLE, sum di-nol (buffer DIPERTAHANKAN)
              → flaggingv2: FSM=IDLE, count=0, detect=0, onoff_mark='0' (buffer DIPERTAHANKAN)
              → markingv1: FSM=IDLE, enable_i='0'
              → dec_control: in_ready=0, out_valid=0, mark_out='0'
              (enable output dari toplevel_iq_fpga = '0' karena markout='0')

Siklus N+1 .. N+1600: rx_cooldown_active='1' → rx_rst='1' terus
              (Goertzel tetap terkunci; korelator "dingin" tapi buffer terjaga)

Siklus N+1601: rx_cooldown_cnt mencapai 0 → rx_cooldown_active='0'
               → rx_rst='0' (kembali ke '0' 1 siklus kemudian, karena registered)

Siklus N+1602: rx_rst='0' → sistem kembali IDLE, korelator mulai menerima data lagi
               Buffer slidingv5 dan flaggingv2 masih berisi data historis
               → flaggingv2 dapat langsung membandingkan threshold tanpa mengisi ulang buffer
```

> **Key insight:** Setelah cooldown selesai, `enable` dari korelator masih '0' (karena `markingv1` sudah direset). Receiver harus menunggu preamble `##3#` berikutnya terdeteksi ulang dari awal. Total waktu buta efektif = **1600 Ldone ≈ 50 ms** (bukan 320 ms seperti sebelum perbaikan soft reset).

---

## 10. LUT Sin/Cos (`lutsin_block.vhd` & `lutcos_block.vhd`)

### 10.1 Fungsi
Dua file LUT ROM berisi nilai sin dan cos untuk 3 frekuensi preamble (697, 941, 1477 Hz) yang digunakan oleh korelator IQ. Ukuran file masing-masing ~25 KB karena berisi tabel nilai lengkap.

### 10.2 Struktur LUT
- **Panjang tabel:** 1024 entry (address 10-bit, `0` s/d `1023`)
- **Nilai yang digunakan:** hanya address `0` s/d `639` (mod 640, sesuai 1 periode simbol)
- **Format nilai output:** 16-bit signed (interpretasi Q3.13 oleh `multv6`)
- **Normalisasi:** Nilai sin/cos dinormalisasi ke rentang signed 16-bit (−32768 s/d +32767)

### 10.3 Hubungan Address dengan Frekuensi
Address LUT dihasilkan oleh `multv6.address_internal` yang increment mod 640 per sampel. Tiga frekuensi (697, 941, 1477 Hz) dibuat dengan menentukan step size yang berbeda dalam LUT yang sama sehingga dalam 640 sampel (20 ms), setiap frekuensi menyelesaikan tepat N setengah siklus:

```
697 Hz  × 640 sampel / 32000 sampel/detik = 13.94 siklus ≈ 14 siklus
941 Hz  × 640 / 32000 = 18.82 siklus ≈ 19 siklus
1477 Hz × 640 / 32000 = 29.54 siklus ≈ 30 siklus
```

Nilai dalam LUT adalah sampel dari gelombang sin/cos pada masing-masing frekuensi ini, sehingga perkalian `dataA × sin(f)` menghasilkan komponen IQ yang dapat diakumulasikan secara koheren.

### 10.4 Catatan Penting
- LUT dibangkitkan secara offline (bukan di VHDL runtime) dan disimpan sebagai konstanta ROM
- Address shared antara `lutsin_block` dan `lutcos_block` — keduanya menerima address yang sama dari `multv6`
- Wrapping address di mod 640 (bukan mod 1024) menjamin phase coherence referensi IQ

---

## 11. Perbedaan `toplevel_iq_fpga.vhd` vs `toplevel_iq_text.vhd`

| Aspek | `toplevel_iq_fpga` | `toplevel_iq_text` |
|-------|-------------------|-------------------|
| **Tujuan** | Implementasi hardware FPGA | Simulasi ModelSim dari file audio |
| **Input data** | `dataA: std_logic_vector(15:0)` dari ADC codec | Dari file teks/stimulus testbench |
| **Port instansiasi** | Terhubung ke `AcakCakap_Top` | Terhubung ke testbench `toplevel_tb*.vhd` |
| **Generic defaults** | Sesuai hardware (GUARD_FLOOR=32.0, dll.) | Mungkin berbeda untuk keperluan simulasi |
| **Status** | File aktif di proyek Quartus | File simulasi only (tidak di-compile ke bitstream) |

Kedua file memiliki **arsitektur internal yang identik** (instansiasi komponen yang sama). Perbedaan hanya pada port yang terhubung ke lingkungan yang berbeda.

Untuk debugging dengan ModelSim, gunakan `toplevel_iq_text.vhd` bersama testbench yang relevan (`tb_receiver_isolated.vhd`, `tb_alignment_multiframe.vhd`).


