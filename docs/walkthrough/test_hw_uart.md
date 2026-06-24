# Walkthrough: Skenario Pengujian 2 — Injeksi Kunci Dinamis via UART (Hardware)

## 1. Pendahuluan

Dokumen ini merangkum proses pengujian **Skenario 2: Injeksi Kunci Dinamis via Serial UART** pada perangkat keras nyata (DE10-Standard + CP2102 USB-to-TTL Adapter). Pengujian ini memverifikasi bahwa kunci 32-bit dapat dikirimkan dari PC melalui antarmuka UART, memicu transmisi nada DTMF, dan berhasil direkonstruksi oleh papan penerima.

---

## 2. Konfigurasi Hardware

### Perangkat yang Digunakan

| Peran | Perangkat |
|-------|-----------|
| Papan Pengirim | Terasic DE10-Standard (Cyclone V SoC, `5CSXFC6D6F31C6`) |
| Papan Penerima | Terasic DE10-Standard (bitstream identik) |
| Adapter UART | Silicon Labs CP2102 USB-to-TTL |
| PC | Windows 11, Python 3.x + `pyserial` |

### Interkoneksi Fisik

```
[PC] --- USB --> [CP2102 Adapter] --- TX --> [GPIO_0[0] / JP1 Pin-1]
                                 +-- GND --> [GND GPIO Header      ]
                                                  |
                                           Papan PENGIRIM
                                           (PIN_W15, 3.3V LVTTL)

[Papan PENGIRIM] -- Line Out --- Y-Cable --> [Papan PENERIMA / Line In]
                                         +-> [Speaker]
```

> [!IMPORTANT]
> Konektor USB Mini-B pada DE10-Standard terhubung ke **HPS UART** (FT232R -> PIN_B25/C25),
> **bukan** ke FPGA fabric. Untuk UART ke FPGA fabric, **wajib menggunakan adapter eksternal**
> yang dihubungkan ke header GPIO.

### Pin Assignment UART (QSF)

```tcl
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to UART_RXD
set_location_assignment PIN_W15 -to UART_RXD
```

`PIN_W15` = `GPIO_0[0]` = JP1 Pin-1 (ujung kiri atas header GPIO_0 DE10-Standard).

---

## 3. Konfigurasi Desain

### UART Receiver (`uart_rx.vhd`)

- **Clock domain:** `CLOCK_50` (50 MHz, selalu stabil sejak power-on)
- **`CLKS_PER_BIT`:** `434` (= 50.000.000 / 115.200 bps)
- Clock domain `AUD_XCK` (18.432 MHz dari PLL) **tidak digunakan** untuk UART,
  karena baru aktif setelah I2C inisialisasi selesai (~beberapa detik).

### Clock-Domain Crossing (CDC): `CLOCK_50` -> `AUD_XCK`

Menggunakan **toggle-based CDC** (bukan 2-FF synchronizer konvensional):

```
CLOCK_50 domain:
  - Setiap byte valid diterima -> flip bit uart_toggle
  - Latch uart_data_latch <- uart_rx_data

AUD_XCK domain:
  - 2-FF synchronizer pada uart_toggle (uart_tog_meta -> uart_tog_sync)
  - Edge detection: setiap perubahan uart_tog_sync = 1 byte baru siap diproses
```

> [!NOTE]
> Toggle-based CDC dipilih karena `uart_rx_valid` hanya HIGH selama 1 cycle `CLOCK_50` (~20 ns),
> lebih pendek dari 1 period `AUD_XCK` (~54 ns). 2-FF synchronizer konvensional tidak dapat
> menangkap pulse sesingkat ini secara andal.

### Protokol Payload UART

```
Byte 1: KEY[31:24]  (MSB)
Byte 2: KEY[23:16]
Byte 3: KEY[15:8]
Byte 4: KEY[7:0]   (LSB)
Byte 5: 0x0A       (Line Feed = trigger transmisi DTMF)
```

Saat byte `0x0A` diterima, sinyal `uart_trigger` HIGH selama 1 cycle AUD_XCK,
memulai FSM transmisi DTMF (12 simbol: `##3#` + 8 nibble kunci).

### MUX Pemilihan Sumber Kunci

```vhdl
payload_data <= uart_key_reg when SW(8) = '1'  -- Kunci dari UART
             else SW(7 downto 0) & SW(7 downto 0) & ...;  -- Kunci statis SW
```

**SW(8) harus dalam posisi ON** saat menggunakan injeksi UART.

---

## 4. Skrip Python (`util/send_key.py`)

Skrip mengirimkan kunci 32-bit (statis atau acak) ke papan pengirim:

```python
# Kunci acak (mode default setelah pengujian awal berhasil):
key = random.randint(0x00000000, 0xFFFFFFFF)
payload = key.to_bytes(4, byteorder='big') + b'\x0a'
ser.write(payload)
ser.flush()
```

Untuk pengujian ulang dengan kunci tetap, gunakan:

```python
payload = bytes([0x3A, 0x7C, 0x9B, 0x1D, 0x0A])
```

---

## 5. Prosedur Pengujian

1. **Program kedua papan** dengan bitstream `quartus/output_files/AcakCakap_Top.sof`
2. **Hubungkan kabel audio:** Line Out papan PENGIRIM -> Line In papan PENERIMA (+ speaker)
3. **Hubungkan CP2102:** TX -> GPIO_0[0] (JP1 Pin-1), GND -> GND GPIO header
4. **Konfigurasi papan PENGIRIM:**
   - `SW(8)` = **ON** (aktifkan kunci UART)
   - `KEY(0)` = tidak ditekan (tidak reset)
5. **Tunggu ~3-5 detik** setelah power-on (I2C WM8731 inisialisasi)
6. **Jalankan skrip:**
   ```powershell
   cd util
   python send_key.py
   ```
7. **Verifikasi:**
   - Nada DTMF terdengar dari speaker (~240 ms, 12 nada berturut-turut)
   - Seven-Segment papan PENERIMA berubah menampilkan kunci yang diterima

---

## 6. Hasil Pengujian

| Aspek | Hasil |
|-------|-------|
| Pengiriman payload UART | Berhasil |
| Transmisi nada DTMF via audio | Terdengar |
| Rekonstruksi kunci di papan penerima | Kunci tampil di Seven-Segment |
| Kunci acak (`random.randint`) | Dapat dikirim dan didekode |

---

## 7. Proses Debugging (Riwayat Masalah & Solusi)

Berikut riwayat masalah yang ditemui selama pengujian hardware, sebagai referensi troubleshooting ke depan.

| # | Gejala | Root Cause | Solusi |
|---|--------|------------|--------|
| 1 | UART tidak berfungsi meski skrip sukses | COM7 (USB Mini-B) terhubung ke **HPS**, bukan FPGA fabric | Gunakan adapter CP2102 eksternal ke GPIO header |
| 2 | CP2102 error `semaphore timeout` | Koneksi fisik ke pin GPIO yang salah (PIN_AC18 = milik DE1-SoC) | Identifikasi board sebagai **DE10-Standard**, pin yang benar = **PIN_W15** |
| 3 | Data diterima CP2102 tapi FPGA tidak merespons | `uart_rx_valid` pulse 20 ns tidak tertangkap 2-FF CDC di AUD_XCK domain | Ganti ke **toggle-based CDC** |
| 4 | UART tidak aktif saat papan baru dinyalakan | UART RX di domain `AUD_XCK` yang baru stabil setelah I2C init | Pindahkan UART ke domain `CLOCK_50` (`CLKS_PER_BIT = 434`) |
| 5 | Pin assignment UART tidak ada di QSF | `UART_RXD` tidak di-assign, Quartus pilih pin acak (AH24) | Tambahkan `set_location_assignment PIN_W15 -to UART_RXD` di QSF |

---

## 8. Temuan & Rencana Optimasi

### 8.1 Diperlukan Multiple Trigger untuk Update Seven-Segment Penerima

**Gejala:** Trigger pertama kerap hanya membunyikan speaker tanpa memperbarui tampilan
Seven-Segment. Trigger kedua diperlukan untuk tampilan berubah.

**Dugaan penyebab:**
- Timing window IQ Correlator/Goertzel belum sinkron dengan awal penerimaan nada DTMF pada
  trigger pertama. Penerima menangkap paket di pertengahan frame sehingga rekonstruksi 32-bit
  kunci tidak lengkap.
- FSM `top_dtmfencode` membutuhkan seluruh 12 simbol (`##3#` + 8 nibble) untuk men-commit kunci
  ke `reconstructed_key_32bit`. Jika satu simbol terpotong, kunci tidak terupdate.

**Rencana perbaikan:** Kirim payload dua kali berturut-turut dengan jeda 50-100 ms, atau
tambahkan mekanisme retransmission otomatis di `send_key.py`.

---

### 8.2 Segmen Tengah HEX[4] (Segmen G) Tidak Menyala

**Gejala:** Strip horizontal tengah pada display HEX[4] tidak pernah menyala, terlepas
dari nilai digit yang ditampilkan.

**Dugaan penyebab:** Pin `HEX4[6]` salah di-assign di QSF, atau ada kerusakan hardware
(dry joint/open trace) di papan yang bersangkutan.

**Langkah verifikasi:**
1. Cek pin assignment `HEX4[6]` di QSF vs. tabel manual DE10-Standard.
2. Uji dengan program sederhana yang menyalakan semua segmen HEX4 (output `"0000000"`)
   untuk konfirmasi apakah masalah di hardware atau software.

---

### 8.3 Bouncing / Glitch pada SW[0] saat Ganti Mode Tampilan

**Gejala:** Saat mengubah `SW[0]` dari ON (mode MSB) ke OFF (mode LSB), tampilan terkadang
masih menunjukkan MSB. Diperlukan penekanan ulang beberapa kali untuk beralih ke LSB.

**Root cause:** Proses `VISUALIZATION_MUX` bersifat **kombinasional murni** tanpa debouncing.
Slide switch DE10-Standard tidak memiliki rangkaian debounce hardware, sehingga transisi
menghasilkan pulsa palsu (bounce).

```vhdl
-- Kondisi saat ini (rentan bounce):
VISUALIZATION_MUX : process(SW(0), reconstructed_key_32bit)
```

**Rencana perbaikan:** Tambahkan debouncer digital pada `SW(0)`:

```vhdl
-- Debouncer berbasis counter ~1-5 ms (DEBOUNCE_LIMIT = 50000 untuk CLOCK_50 = 50 MHz -> 1 ms)
DEBOUNCE_SW0 : process(CLOCK_50)
begin
    if rising_edge(CLOCK_50) then
        if SW(0) /= sw0_stable then
            debounce_cnt <= debounce_cnt + 1;
            if debounce_cnt = DEBOUNCE_LIMIT then
                sw0_stable   <= SW(0);
                debounce_cnt <= 0;
            end if;
        else
            debounce_cnt <= 0;
        end if;
    end if;
end process;
-- Gunakan sw0_stable sebagai selektor MUX, bukan SW(0) langsung
```
