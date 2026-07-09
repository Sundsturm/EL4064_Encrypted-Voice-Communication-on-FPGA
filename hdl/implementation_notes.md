# Catatan Implementasi & Analisis Sistem Komunikasi Suara Terenkripsi DTMF (FPGA)

Dokumen ini mendokumentasikan riwayat analisis masalah, evolusi arsitektur sistem sinkronisasi frame penerima, hingga perbaikan terbaru yang diterapkan pada modul transiver DTMF.

---

## Riwayat Analisis Masalah Awal & Solusi

### 1. Ketiadaan *Pre-Transmission Silence*
* **Masalah Awal**: Transmitter langsung mengirimkan simbol DTMF begitu tombol trigger ditekan tanpa memberikan jeda diam (*silence*). Hal ini menyebabkan receiver yang masih dalam proses pembersihan filter atau stabilisasi clock salah membaca derau awal sebagai simbol pertama.
* **Analisis & Solusi**: Ditambahkan state `PRE_SILENCE` pada FSM pengirim (`FSM_DTMF_TRANSMITTER` di `AcakCakap_Top.vhd`). Sebelum memancarkan 12 simbol DTMF (4 preamble + 8 payload), pengirim melakukan *silence* selama 50 ms (1600 sampel pada clock audio). Jeda ini memberi waktu bagi filter penerima untuk mengosongkan akumulator energi (*clearing memory*) sebelum mendeteksi preamble sesungguhnya.

### 2. Kegunaan dan Evolusi Batas Penyelarasan `align_counter`
* **Definisi & Kegunaan `align_counter`**:
  `align_counter` adalah register pencacah penunda yang digunakan untuk menyelaraskan waktu mulai (*boundary alignment*) dari modul filter Goertzel (`Goertzel_top`). Ketika korelator IQ mendeteksi preamble dan menaikkan sinyal `enable` ke `'1'`, modul Goertzel tidak boleh langsung diaktifkan. Jika langsung diaktifkan, Goertzel akan memproses sisa sinyal preamble, sehingga jendela integrasi 640 sampel (20 ms) berikutnya akan bergeser dan tumpang tindih (*overlap*) di antara dua simbol payload. Hal ini akan menyebabkan kesalahan deteksi frekuensi (*spectral leakage*). `align_counter` menjamin bahwa Goertzel baru mulai membaca tepat pada sampel pertama dari simbol payload pertama.
* **Evolusi Kronologis Nilai `align_counter`**:
  * **Tahap Awal (Sistem FSM Lama)**: Pada arsitektur awal, penyelarasan dilakukan secara dinamis oleh FSM `FRAME_COLLECTOR` di dalam `top_dtmfencode.vhd` dengan mendeteksi kemunculan simbol pembatas `#`. Namun, metode ini sangat rentan terhadap derau dan sering kali mengalami *stuck* karena batas deteksi simbol yang tidak sinkron secara presisi terhadap laju clock sampel audio.
  * **Tahap Transisi (Penghapusan FSM Redundan)**: Setelah FSM `FRAME_COLLECTOR` dihapus, deteksi preamble dikonsolidasikan pada korelator IQ tingkat atas (`AcakCakap_Top.vhd`). Penyelarasan jendela kini dihitung secara deterministik berbasis jumlah sampel audio (`Ldone`).
  * **Analisis Perhitungan Sampel**:
    * Preamble terdiri dari 4 simbol: `#` (Segmen 0), `#` (Segmen 1), `3` (Segmen 2), dan `#` (Segmen 3). Masing-masing berdurasi 640 sampel.
    * Korelator IQ mendeteksi kecocokan pola dan menaikkan sinyal `enable` ke `'1'` pada sampel ke-**3162** (sesaat setelah simbol `3` di Segmen 2 selesai diproses dan buffer korelator mendeteksi kecocokan).
    * Simbol payload kunci pertama (Segmen 4) baru benar-benar dimulai pada sampel ke-**4160**.
    * Selisih sampel antara terdeteksinya `enable` dan dimulainya payload pertama adalah:
      $$\text{Jeda Sampel} = 4160 - 3162 = 998 \text{ sampel}$$
  * **Tahap Akhir (Nilai `997`)**:
    Karena pencacah `align_counter` dimulai dari indeks `0` pada domain clock audio (`Ldone`), untuk menunda sebanyak 998 sampel audio secara akurat, batas pembanding harus diset ke $998 - 1 = 997$.
    Begitu counter mencapai nilai **`997`**, FSM `GOERTZEL_ALIGN_FSM` akan menaikkan sinyal `goertzel_enable <= '1'` tepat pada awal sampel ke-4160. Hal ini menjamin tingkat akurasi transiver yang sangat tinggi dan mencegah terjadinya pembacaan digit kunci ganda atau terlewat.

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
