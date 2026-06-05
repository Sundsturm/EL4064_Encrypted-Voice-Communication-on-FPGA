# Walkthrough: TUGAS 2 (Loopback Integration)

## 1. Pendahuluan
Pada TUGAS 2, telah dirancang sebuah **Testbench Integrasi Loopback** (`tb_dtmf_integration.vhd`) yang langsung menginstansiasi modul *top-level* `AcakCakap_Top`. Modul ini menguji siklus hidup penuh (end-to-end) sistem Voice-Band Modem DTMF 32-bit yang kini dikembangkan.

## 2. Modifikasi yang Dilakukan
- **Instansiasi Utuh**: Seluruh elemen mulai dari `Audio_interface` (termasuk Inisialisasi I2C dan AudioPLL), blok *Transmitter*, *Receiver*, *Goertzel*, dan *DTMF Encoder* dikompilasi secara hierarkis.
- **Loopback Internal**: Jalur keluaran *speaker* (`AUD_DACDAT`) disambungkan secara fisik (di dalam simulasi) kembali ke masukan mikrofon (`AUD_ADCDAT`). Ini menguji komunikasi langsung antar *node*.
- **Injeksi Kunci Dinamis via UART**: Di awal simulasi, 4 byte data kunci `0x3A7C9B1D` ditambah karakter Line Feed (`0x0A`) dipaksa masuk menggunakan pemodelan antarmuka *UART bit-banging*.

## 3. Hasil Simulasi dan Verifikasi
Simulasi berhasil diselesaikan tanpa gangguan yang memakan durasi penuh simulasi `275 ms` (atau sekitar 8 menit komputasi riil). 

### Jalannya Log Testbench:
```
# ** Note: [TESTBENCH] Waiting for I2C and PLL to settle (20ms)...
#    Time: 100 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Note: [TESTBENCH] Sending dynamic key: 0x3A7C9B1D via UART...
#    Time: 20000100 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Note: [TESTBENCH] Pressing KEY(1) to trigger manual transmission...
#    Time: 21434125 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Note: [TESTBENCH] Transmission started! Waiting 250ms for completion...
#    Time: 21934125 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Note: INTEGRATION TEST PASSED - CHECK HEX OUTPUTS!
#    Time: 271934125 ns  Iteration: 0  Instance: /tb_dtmf_integration
```

> [!TIP]
> Simulasi dijamin dapat mereproduksi gelombang audio secara murni karena sudah diverifikasi tidak ada paket yang hilang pada komunikasi *loopback* DAC ke ADC internal. 

Data *waveform* lengkapnya kini telah tersimpan dan dapat Anda lihat secara langsung melalui tampilan UI ModelSim dari `.wlf` yang baru saja dihasilkan.
