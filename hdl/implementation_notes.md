# Catatan Implementasi & Analisis Sistem Komunikasi Suara Terenkripsi DTMF (FPGA)

Dokumen ini mendokumentasikan riwayat analisis masalah, evolusi arsitektur sistem sinkronisasi frame penerima, hingga perbaikan terbaru yang diterapkan pada modul transiver DTMF.

---

## Riwayat Analisis Masalah Awal & Solusi

### 1. Ketiadaan *Pre-Transmission Silence*
* **Masalah Awal**: Transmitter langsung mengirimkan simbol DTMF begitu tombol trigger ditekan tanpa memberikan jeda diam (*silence*). Hal ini menyebabkan receiver yang masih dalam proses pembersihan filter atau stabilisasi clock salah membaca derau awal sebagai simbol pertama.
* **Analisis & Solusi**: Ditambahkan state `PRE_SILENCE` pada FSM pengirim (`FSM_DTMF_TRANSMITTER` di `AcakCakap_Top.vhd`). Sebelum memancarkan 12 simbol DTMF (4 preamble + 8 payload), pengirim melakukan *silence* selama 50 ms (1600 sampel pada clock audio). Jeda ini memberi waktu bagi filter penerima untuk mengosongkan akumulator energi (*clearing memory*) sebelum mendeteksi preamble sesungguhnya.

### 2. Jeda *Lookback Buffer* & Efek *Circular Buffer*
* **Masalah Awal**: Korelator IQ mendeteksi preamble melalui operasi *sliding correlation* berbasis buffer melingkar (*circular buffer*). Ketika pola korelasi puncak terdeteksi dan sinyal `enable` naik ke `'1'`, data audio yang memicu korelasi tersebut sebenarnya telah lewat beberapa ratus sampel di dalam buffer.
* **Analisis & Solusi**: 
  * Deteksi preamble selesai sepenuhnya setelah korelator mengamati simbol ketiga (`3`) dari pola `#,#,3,#` (simbol ke-4 `#` berfungsi sebagai pembatas sinkronisasi).
  * Dengan laju sampel 32 kHz dan panjang simbol 20 ms (640 sampel/simbol), terdapat pergeseran indeks sampel yang pasti antara waktu deteksi `enable` dengan awal payload kunci sesungguhnya.
  * Solusi yang diterapkan adalah menunda aktivasi blok analisis Goertzel (`goertzel_enable`) setelah `enable` naik. Penundaan dihitung dengan presisi menggunakan `align_counter` sebesar **`997`** (merepresentasikan delay 998 sampel audio) agar jendela integrasi Goertzel pertama tepat jatuh di awal sampel payload kunci pertama (Segmen 4).

### 3. Redundansi Deteksi Preamble (Dua Sistem Sinkronisasi Frame)
* **Masalah Awal**: Terjadi tumpang tindih logika pemrosesan preamble. Modul dekoder `top_dtmfencode.vhd` memiliki FSM internal `FRAME_COLLECTOR` yang bertugas mencari simbol `#` dan `3`, sementara di tingkat top-level (`AcakCakap_Top.vhd`) korelator IQ (`toplevel_iq.vhd`) juga mendeteksi preamble yang sama secara asinkron.
* **Analisis & Solusi**: FSM `FRAME_COLLECTOR` yang tidak efisien dihapus dari `top_dtmfencode.vhd`. Deteksi preamble diserahkan sepenuhnya secara terpusat pada korelator IQ (`toplevel_iq`). Setelah korelator memicu sinyal `enable`, blok analisis Goertzel diaktifkan tepat waktu, dan modul `shift_add` (sebagai `key_collector` di dalam dekoder) langsung mengumpulkan 8 simbol payload secara linear tanpa perlu melakukan pencarian pola preamble lagi.

### 4. Ketiadaan Mekanisme *Re-Arm* (Receiver Stuck)
* **Masalah Awal**: Penerima tidak memiliki mekanisme pengaktifan kembali (*re-arm*) otomatis setelah kunci didekode. Sekali kunci terisi di register output, status `out_valid` tidak terbersihkan dan receiver tidak bisa mendengarkan transmisi berikutnya, atau terkunci secara permanen jika terjadi *false trigger* akibat derau.
* **Analisis & Solusi**:
  * Ditambahkan jalur reset lokal penerima (`rx_rst`) yang aktif secara otomatis ketika proses dekode selesai (`out_valid = '1'`).
  * Ditambahkan **Watchdog Timer** dengan timeout **400 ms** (7.372.800 siklus clock `AUD_XCK`). Jika penerima mendeteksi preamble (`enable = '1'`) tetapi tidak berhasil mengumpulkan 8 simbol payload kunci dalam 400 ms (akibat transmisi terputus atau derau), watchdog akan otomatis mengaktifkan `rx_timeout_rst` untuk mereset seluruh modul penerima kembali ke state `IDLE` (*auto-rearm*).

### 5. Perbaikan Sinyal Reset Fisik (KEY0) & Masalah Lockup FSM
* **Masalah Akhir**: Tombol reset fisik (KEY0) tidak berfungsi mereset sistem core digital karena reset sebelumnya sinkron terhadap clock `AUD_XCK`. Padahal, menekan KEY0 mematikan clock tersebut dari PLL, sehingga register reset tidak pernah ter-update. Selain itu, FSM pada `shift_add`, `decision`, serta comparator tidak mereset register `state` mereka ke `IDLE`.
* **Analisis & Solusi**:
  * Mengubah modul sinkronisasi reset di `AcakCakap_Top.vhd` menjadi tipe **Asynchronous Assert, Synchronous Deassert**. Reset akan langsung aktif seketika tombol ditekan (meski clock mati), dan dilepas secara sinkron setelah clock stabil kembali.
  * Menambahkan penugasan reset `state <= IDLE;` secara asinkron di dalam berkas `shift_add.vhd`, `decision.vhd`, `lowcomparator.vhd`, dan `highcomparator.vhd`.

---

## File Legend (Panduan Berkas HDL)

Berikut adalah daftar berkas VHDL dalam direktori `hdl/` beserta fungsinya dalam sistem transceiver:

### 1. Berkas Tingkat Top-Level & Konfigurasi
* **`AcakCakap_Top.vhd`**  
  Modul teratas (*top-level*) FPGA. Mengelola pembagi clock, debouncing tombol, multiplexer visualisasi Seven-Segment, FSM kendali transmisi DTMF, generator reset sinkron, dan instansiasi seluruh subsistem.
* **`Audio_interface.vhd`**  
  Antarmuka audio codec Wolfson WM8731. Mengatur komunikasi I2C untuk konfigurasi register chip codec serta konversi data audio serial-ke-paralel (ADC) dan paralel-ke-serial (DAC).
* **`i2c.vhd`**  
  Pengontrol protokol I2C yang digunakan oleh `Audio_interface` untuk mengirim byte konfigurasi register awal ke chip codec WM8731.

### 2. Modul Deteksi Preamble (Frame Synchronization)
* **`receiver_hdl/toplevel_iq.vhd`**  
  Wrapper korelator IQ. Menghubungkan sliding correlator dengan detektor flag ambang batas daya korelasi.
* **`receiver_hdl/slidingv5.vhd`**  
  Modul korelasi geser (*sliding correlation*). Menghitung korelasi sampel audio masukan secara real-time terhadap pola koefisien referensi dari preamble `#,#,3,#`.
* **`receiver_hdl/flaggingv2.vhd`**  
  Detektor daya korelasi. Menghasilkan sinyal `enable` ketika nilai korelasi dari `slidingv5` melewati ambang batas tertentu.

### 3. Modul Dekoder DTMF (Payload Demodulator)
* **`dtmf_detect_hdl/top_dtmfencode.vhd`**  
  Wrapper utama dekoder penerima. Menginstansiasi filter Goertzel, komparator, dekoder keputusan, dan pengumpul kunci 32-bit.
* **`dtmf_detect_hdl/Goertzel_top.vhd`**  
  Wrapper bank filter Goertzel. Menginstansiasi 8 buah filter Goertzel secara paralel untuk mendeteksi 8 frekuensi standar DTMF.
* **`dtmf_detect_hdl/Goertzel.vhd`**  
  Implementasi algoritma Goertzel untuk mendeteksi magnitudo energi pada satu frekuensi bin spesifik menggunakan representasi fixed-point.
* **`dtmf_detect_hdl/lowcomparator.vhd`**  
  Membandingkan kekuatan energi grup frekuensi rendah DTMF (697 Hz, 770 Hz, 852 Hz, 941 Hz) untuk menentukan baris tombol yang ditekan.
* **`dtmf_detect_hdl/highcomparator.vhd`**  
  Membandingkan kekuatan energi grup frekuensi tinggi DTMF (1209 Hz, 1336 Hz, 1477 Hz, 1633 Hz) untuk menentukan kolom tombol yang ditekan.
* **`dtmf_detect_hdl/decision.vhd`**  
  Mengambil keputusan baris/kolom dari komparator dan mendekodenya menjadi nilai simbol DTMF 4-bit (0-9, A-F).
* **`dtmf_detect_hdl/shift_add.vhd`**  
  Mengumpulkan simbol 4-bit DTMF secara berurutan dan menggesernya ke register 32-bit. Menghasilkan sinyal `out_valid` setelah tepat 8 simbol payload diterima.

### 4. Modul Generator DTMF (Transmitter)
* **`sender_hdl/generate_dtmf_signed.vhd`**  
  Modul pembangkit dual-tone DTMF berdasarkan digit masukan yang diberikan oleh FSM transmisi.
* **`sender_hdl/sine_gen_signed.vhd`**  
  Generator gelombang sinus digital berbasis akumulator fasa dan tabel pencarian (*look-up table*).

### 5. Berkas Simulasi & Testbench (ModelSim)
* **`tb_receiver_isolated.vhd`**  
  Testbench terisolasi untuk memverifikasi alur dekode penerima secara mandiri dengan menyuntikkan sampel gelombang suara DTMF dari tiga kunci uji.
* **`run_tb_receiver_isolated.do`**  
  Skrip otomasi ModelSim untuk mengompilasi dan menjalankan simulasi testbench penerima terisolasi secara cepat.
* **`tb_alignment_multiframe.vhd`** & **`run_tb_alignment_multiframe.do`**  
  Testbench dan skrip simulasi untuk memverifikasi penyelarasan multi-frame.
* **`tb_dtmf_integration.vhd`** & **`run_tb_dtmf_integration.do`**  
  Testbench dan skrip simulasi untuk menguji integrasi utuh pemancar ke penerima secara loopback.
