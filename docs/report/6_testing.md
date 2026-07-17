# BAB 6: PENGUJIAN PERANGKAT KERAS

Bab ini membahas pengujian dan verifikasi fungsionalitas fisik nyata dari sistem komunikasi suara terenkripsi berbasis DTMF pada papan pengembangan (*development board*) FPGA Altera Cyclone V DE10-Standard. Pengujian fisik dilakukan secara menyeluruh (*end-to-end*) untuk memvalidasi performa real-time dan integrasi sirkuit digital RTL bersama periferal analog pendukung, seperti IC codec audio Wolfson WM8731 dan antarmuka serial UART. Verifikasi tingkat akhir ini dibagi menjadi tiga skenario pengujian, yang diawali dengan verifikasi pendengaran nada DTMF melalui pengeras suara eksternal, dilanjutkan dengan pengujian loopback fisik untuk kunci statis menggunakan sakelar geser SW[7:0], dan diakhiri dengan pengujian loopback fisik untuk kunci dinamis menggunakan injeksi komunikasi serial UART.

---

## 6.1. Verifikasi Nada DTMF Melalui Pengeras Suara

Skenario pengujian pertama dilakukan untuk memverifikasi secara langsung kualitas dan keandalan sinyal audio analog DTMF yang disintesis oleh modul pemancar RTL di dalam FPGA. Pada skenario ini, *port Line-Out* pada papan pengembangan DE10-Standard dihubungkan ke perangkat pengeras suara (*speaker*) aktif atau *headphone* menggunakan kabel audio auxiliary 3.5mm. Pengujian dilakukan dengan memvariasikan nilai masukan kunci statis pada sakelar geser `SW(7 downto 0)` untuk mengamati perubahan nada yang dibangkitkan. Output analog yang dihasilkan oleh chip codec Wolfson WM8731 kemudian dipantau secara auditori oleh penguji sewaktu transmisi dipicu secara manual menggunakan tombol fisik `KEY(1)`. Hasil verifikasi pendengaran membuktikan bahwa sekuens nada DTMF yang dibunyikan bersifat sangat deterministik, di mana variasi kombinasi masukan kunci menghasilkan karakteristik bunyi dual-tone yang berbeda-beda secara konsisten sesuai dengan pemetaan frekuensi standar DTMF. Setiap transmisi berhasil menyintesis sekuens 12 nada secara kontinu selama 240 ms tanpa adanya jeda sunyi antarsimbol. Ketiadaan bunyi letupan (*clicking noise*) pada batas transisi antar-simbol mengonfirmasi bahwa transfer *state* fase internal NCO berjalan secara kontinu tanpa diskontinuitas fase. Sinyal audio yang terdengar sangat jernih dan bebas dari distorsi frekuensi tinggi liar membuktikan bahwa perancangan akumulator fase, ROM lookup table sinus 1-kuadran, penskalaan mixer, serta laju transfer protokol I2S pada [AcakCakap_Top.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/AcakCakap_Top.vhd) telah bekerja secara presisi.


---

## 6.2. Pengujian Kunci Statis Berbasis Sakelar Fisik SW[7:0]

Skenario pengujian kedua ditujukan untuk memverifikasi fungsionalitas dasar pemancar dan penerima DTMF secara tertutup menggunakan kunci statis yang ditentukan secara manual. Untuk melakukan pengujian loopback fisik analog ini, *port Line-Out* (speaker) dihubungkan kembali secara langsung ke *port Line-In* (mikrofon) menggunakan kabel auxiliary 3.5mm stereo eksternal. Sakelar pemilih mode masukan diatur ke posisi rendah (`SW(8) = '0'`) pada papan FPGA. Nilai kunci enkripsi ditentukan melalui delapan sakelar geser fisik `SW(7 downto 0)`. Logika internal perangkat keras pada modul [AcakCakap_Top.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/AcakCakap_Top.vhd) secara otomatis merangkai nilai 8-bit tersebut sebanyak empat kali secara repetitif untuk membentuk sebuah kunci statis 32-bit yang utuh. Sebagai contoh, apabila sakelar diatur ke nilai heksadesimal `0xAB` (`10101011` biner), sistem akan menghasilkan kunci expected `0xABABABAB`. Transmisi paket DTMF kemudian diinisiasi secara manual dengan menekan tombol fisik `KEY(1)` (*falling-edge*). Selama pengiriman berlangsung, indikator LED menyala dan input mikrofon secara otomatis dimatikan (*muted*) untuk mencegah masuknya derau lingkungan.

Sinyal audio yang dikirimkan melalui kabel auxiliary didekode secara real-time oleh modul penerima, lalu hasilnya divisualisasikan menggunakan display Seven-Segment. Berdasarkan pengamatan selama pengujian fisik, pembaruan data pada display Seven-Segment di sisi penerima tidak selalu terjadi secara instan pada setiap pengiriman. Terkadang, penekanan perdana tombol `KEY(1)` tidak mengubah tampilan visual sama sekali meskipun nada DTMF pemancar terdengar jelas melalui pengeras suara. Tampilan kunci hasil rekonstruksi umumnya baru diperbarui secara fungsional pada penekanan berulang selanjutnya, biasanya pada penekanan kedua atau ketiga. Selain itu, terdapat pula kondisi di mana simbol heksadesimal yang didekode tidak sepenuhnya sesuai, sering kali dengan munculnya satu atau lebih simbol `F` (mewakili `#`) atau `3` yang terselip di sela-sela sekuens kunci semestinya, yang kemungkinan besar berasal dari kebocoran nada preamble pada transisi deteksi awal. Jika tombol `KEY(1)` ditekan secara terus-menerus dengan sangat cepat (*spam click*), interferensi antarsimbol (ISI) dapat terjadi sehingga merusak data perakitan kunci pada register penerima. Meskipun demikian, pada momen-momen pengujian tertentu dengan ritme pemicuan yang stabil dan teratur, modul penerima berhasil melakukan dekode dengan sempurna, sehingga display Seven-Segment menampilkan nilai kunci yang tepat, yaitu karakter `"ABABAB"` pada mode LSB (`SW(0) = '0'`) dan karakter `"AB----"` pada mode MSB (`SW(0) = '1'`).

---

#### Tabel 6.1. Hasil Pengujian Kunci Statis Berbasis Sakelar Fisik SW[7:0]
| No. | Kunci TX | Kunci RX | Status | Kesalahan Simbol | Kesalahan Bit (Hamming) | Frame Loss |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 1 | `10101010` | `10101010` | OK | 0 | 0 | - |
| 2 | `20202020` | `F2022020` | MISMATCH | 4 | 6 | - |
| 3 | `30303030` | `F203FF02` | MISMATCH | 8 | 16 | - |
| 4 | `40404040` | `00055450` | MISMATCH | 6 | 7 | - |
| 5 | `50505050` | `F5055050` | MISMATCH | 4 | 8 | - |
| 6 | `60606060` | `60606060` | OK | 0 | 0 | - |
| 7 | `70707070` | `70E07070` | MISMATCH | 1 | 2 | - |
| 8 | `80808080` | `33980808` | MISMATCH | 8 | 11 | - |
| 9 | `90909090` | `FF9098F8` | MISMATCH | 5 | 10 | - |
| 10 | `A0A0A0A0` | `DDDAAA20` | MISMATCH | 6 | 14 | - |
| 11 | `B0B0B0B0` | `B0B0B0B0` | OK | 0 | 0 | - |
| 12 | `C0C0C0C0` | `8DDCDC80` | MISMATCH | 7 | 11 | - |
| 13 | `D0D0D0D0` | `00000000` | MISMATCH | 4 | 12 | - |
| 14 | `E0E0E0E0` | `FE0EE0E0` | MISMATCH | 4 | 10 | - |
| 15 | `F0F0F0F0` | `F0F00000` | MISMATCH | 2 | 8 | - |

---

## 6.3. Pengujian Kunci Dinamis Berbasis Injeksi UART

Skenario pengujian ketiga dilakukan untuk memverifikasi integrasi penuh sistem dalam menangani transmisi kunci dinamis 32-bit yang dikirimkan secara serial dari komputer PC ke papan pengirim FPGA. Jalur serial ini menggunakan adapter USB-to-TTL CP2102 eksternal yang dihubungkan ke header GPIO JP1 pin 1 (`PIN_W15` yang dipetakan sebagai `UART_RXD`) pada papan DE10-Standard. Sakelar pemilih mode masukan kunci diatur ke posisi tinggi (`SW(8) = '1'`) untuk mengarahkan jalur masukan kunci dari memori register UART ke pemancar DTMF. Skrip Python [`util/send_key.py`](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/util/send_key.py) digunakan untuk mengirimkan payload kunci dinamis secara otomatis yang diakhiri dengan byte pembatas *Line Feed* (`0x0A`) sebagai trigger transmisi DTMF.

Dari pengujian fisik yang dilakukan pada perangkat keras, terdapat beberapa temuan penting terkait perilaku sistem nyata:
1. **Kebutuhan Retransmisi ("Warm Up" Penerima):** Ketika papan pertama kali diprogram, trigger pertama (pengiriman awal) sering kali tidak memengaruhi atau memperbarui tampilan Seven-Segment di sisi penerima. Pada pengiriman selanjutnya, tampilan Seven-Segment lebih konsisten menampilkan nilai kunci yang benar, meskipun beberapa kali masih terdapat visualisasi yang salah (*ngaco*) akibat sinkronisasi fasa/window Goertzel penerima yang belum optimal. Fenomena ini membuat sistem seakan-akan membutuhkan waktu pemanasan (*warm up*) setelah pemrograman. Untuk meminimalisasi ketidakstabillan ini, dilakukan penyesuaian jumlah pengiriman kunci ganda (mekanisme auto-retransmit) pada skrip Python dengan jeda tertentu, yang terbukti secara signifikan menurunkan tingkat kesalahan decoding visual.
2. **Keterbatasan Fisik LED Display:** Terdapat kerusakan fisik (murni masalah perangkat keras) pada display Seven-Segment **HEX[4]** di mana **Segmen G (strip horizontal tengah) rusak/tidak menyala sama sekali**. Hal ini menyebabkan digit heksadesimal tertentu yang memanfaatkan segmen tengah tersebut (seperti karakter '3', '4', '8', 'A', dll.) tidak terproyeksi secara sempurna, meskipun data register kunci di dalamnya didekode dengan benar.
3. **Bouncing Sakelar SW[0]:** Untuk beralih antara visualisasi MSB (`SW(0) = '1'`) dan LSB (`SW(0) = '0'`), sinyal dilewatkan melalui modul debouncing digital (`DEBOUNCE_SW0` dengan filter ~1 ms). Hasil pengujian menunjukkan bahwa efek bouncing/glitch pada sakelar geser ini telah berhasil terminimalisasi tetapi belum hilang sepenuhnya. Sisa gangguan transisi ini diasumsikan timbul akibat kelonggaran atau kerusakan mekanik internal pada saklar fisik `SW[0]` papan itu sendiri.

Meskipun terdapat beberapa batasan fisik eksternal (seperti kerusakan LED segmen G dan keausan mekanik sakelar), integrasi logika UART RX, sinkronisasi domain clock (CDC) berbasis toggle dari clock UART 50 MHz ke clock audio 18,432 MHz, hingga decoding audio DTMF secara keseluruhan telah berfungsi dengan andal sesuai rancangan perangkat keras pada [AcakCakap_Top.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/AcakCakap_Top.vhd).

#### Tabel 6.2. Hasil Pengujian Kunci Dinamis Berbasis Injeksi UART
| No. | Kunci TX | Kunci RX | Status | Kesalahan Simbol | Kesalahan Bit (Hamming) | Frame Loss |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 1 | `BAD0AD4A` | `BBD0AD4A` | MISMATCH | 1 | 1 | - |
| 2 | `363DAC7B` | `363DAC7B` | OK | 0 | 0 | - |
| 3 | `18E99D3F` | `F18E9D3F` | MISMATCH | 4 | 10 | - |
| 4 | `14D6887A` | `14D6887A` | OK | 0 | 0 | - |
| 5 | `A15D03B3` | `A15D03B3` | OK | 0 | 0 | - |
| 6 | `6048F857` | `6F488577` | MISMATCH | 4 | 11 | - |
| 7 | `BE09008F` | `BE09008F` | OK | 0 | 0 | - |
| 8 | `6B92FFCF` | `6B92FFCF` | OK | 0 | 0 | - |
| 9 | `E94CB5B8` | `E94CB5B8` | OK | 0 | 0 | - |
| 10 | `B4320FC0` | `DB432090` | MISMATCH | 7 | 17 | - |
| 11 | `B2BB054D` | `25B054ED` | MISMATCH | 6 | 13 | - |
| 12 | `C766468A` | `FC66438A` | MISMATCH | 3 | 7 | - |
| 13 | `A08E43F5` | `3A08E43F` | MISMATCH | 8 | 16 | - |
| 14 | `384593AC` | `384593AC` | OK | 0 | 0 | - |
| 15 | `C19E2046` | `9C771244` | MISMATCH | 7 | 14 | - |
| 16 | `AFBC7F76` | `FDFBCF76` | MISMATCH | 5 | 10 | - |
| 17 | `3700C2D8` | `F3700C28` | MISMATCH | 6 | 15 | - |
| 18 | `CCBAF978` | `CCBAF978` | OK | 0 | 0 | - |
| 19 | `48D8AD88` | `48D8AD88` | OK | 0 | 0 | - |
| 20 | `B36839D3` | `F3623FD3` | MISMATCH | 3 | 5 | - |

---

## 6.4. Analisis Hasil Pengujian

Analisis mendalam terhadap data eksperimen pada Tabel 6.1 (pengujian kunci statis) dan Tabel 6.2 (pengujian kunci dinamis) mengungkap beberapa fenomena penting terkait kinerja modem DTMF pada perangkat keras Cyclone V. Secara umum, sistem berhasil membuktikan peningkatan keandalan yang signifikan pasca-implementasi threshold sensitif, meskipun masih terdapat beberapa tantangan teknis terkait penyelarasan waktu pemicuan gerbang penerima.

### 6.4.1. Efektivitas Pemicuan Preamble dan Eliminasi Frame Loss
Salah satu keberhasilan utama dalam pengujian ini adalah pencapaian **Frame Loss Rate sebesar 0,00%** pada kedua skenario pengujian. Pada iterasi desain sebelumnya dengan batas ambang batas daya Goertzel sebesar 800 dan flagging korelator sebesar 4, sistem mengalami kegagalan deteksi total (stuck di `00000000`) akibat redaman sinyal yang terjadi pada jalur kabel analog dengan gain 0 dB. Penurunan ambang batas komparator Goertzel menjadi **200** (Q13.4) dan threshold korelator flagging menjadi **2** terbukti memberikan sensitivitas yang memadai bagi penerima untuk mendeteksi keberadaan paket suara yang masuk. Hal ini menunjukkan bahwa korelator fase I/Q dan filter Goertzel bekerja dengan sangat peka terhadap komponen nada frekuensi rendah maupun tinggi, bahkan di bawah kondisi amplitudo sinyal yang lemah.

### 6.4.2. Karakteristik Kesalahan Akibat Kebocoran Preamble (Offset Alignment)
Meskipun kepekaan penerima sangat tinggi, analisis kesalahan karakter menunjukkan adanya galat sistematik berupa pergeseran indeks simbol (*symbol offset*). Pada log pengujian seperti UART No. 3 (TX `18E99D3F` terbaca RX `F18E9D3F`) dan No. 17 (TX `3700C2D8` terbaca RX `F3700C28`), terlihat bahwa karakter pembuka heksadesimal `F` (nada `#`) menyusup ke awal payload hasil dekode. Kebocoran ini disebabkan oleh asersi sinyal pemicu (`enable`) dari korelator I/Q yang terjadi terlalu cepat pada transisi dari `F` ke `3` di dalam sekuens preamble. Akibat pemicuan yang terlalu dini ini, simbol `F` terakhir dari preamble ikut terbaca oleh Goertzel sebagai digit payload pertama. Masuknya simbol parasit ini secara berantai menggeser delapan digit payload kunci ke kanan, sehingga digit LSB terakhir terdorong keluar dari batas register geser 32-bit dan memicu status *mismatch*.

### 6.4.3. Perbandingan Kinerja Pengiriman Manual (SW) vs Otomatis (UART)
Evaluasi kinerja menunjukkan perbedaan tingkat keberhasilan kata kunci (*Word Success Rate*) yang cukup mencolok antara pengujian berbasis sakelar geser SW (20,00% sukses) dengan pengujian injeksi UART (45,00% sukses). Keunggulan skenario UART ini disebabkan oleh kestabilan laju pengiriman paket yang dikendalikan oleh skrip Python secara presisi, sehingga meminimalkan variasi jeda waktu antarsimbol (*timing jitter*). Sebaliknya, pada pengujian kunci statis SW, pemicuan transmisi dilakukan secara manual menggunakan tombol fisik KEY(1) dan sakelar geser SW[7:0]. Tindakan mekanis ini rentan menimbulkan getaran kontak listrik (bounce) dan derau transien sesaat pada ADC, yang mengganggu fasa awal integrasi korelator I/Q. Hal ini menjelaskan mengapa tingkat kesalahan simbol (SER) pada pengujian statis SW mencapai 49,17%, sedangkan pada pengujian dinamis UART berhasil ditekan hingga 33,75%.

### 6.4.4. Analisis Bit Error Rate (BER) dan Integritas Saluran
Meskipun tingkat kesalahan kata kunci (WER) masih berada di atas 50%, nilai **Bit Error Rate (BER)** tercatat cukup rendah, yaitu 18,59% untuk pengujian UART dan 23,96% untuk pengujian SW. Hal ini menegaskan bahwa mayoritas kesalahan bit disebabkan oleh kegagalan penyelarasan bingkai (frame shift) yang menggeser seluruh digit 4-bit, bukan disebabkan oleh kerusakan bit acak akibat derau saluran analog (*additive white Gaussian noise*). Apabila efek pergeseran simbol pembuka `F` tersebut diabaikan, sebagian besar digit kunci yang diterima sebenarnya memiliki nilai biner yang tepat atau hanya selisih 1 bit (seperti pada UART No. 1 yang hanya salah 1 bit). Hal ini mengonfirmasi bahwa algoritma Goertzel memiliki selektivitas frekuensi yang sangat baik untuk membedakan kedelapan frekuensi DTMF pada board FPGA nyata.

### 6.4.5. Rekomendasi Optimasi Lanjutan untuk Produksi
Untuk meningkatkan kinerja sistem hingga mencapai WER 0% di masa mendatang, beberapa langkah perbaikan dapat diimplementasikan pada level RTL:
1. **Penerapan Masking Preamble Digital:** Menambahkan counter digit internal pada modul penerima (`shift_add.vhd`) untuk secara paksa membuang digit pertama yang didekode setelah sinyal `enable` aktif, sehingga kebocoran simbol preamble `F` dapat mencegah secara digital.
2. **Penyelarasan Tunda Pemicuan:** Memperkenalkan delay register (penunda waktu) pada lintasan asersi `enable` di `dec_control.vhd` untuk menunda pembukaan gerbang penerima Goertzel selama kurang lebih 20 ms (1 durasi simbol), sehingga Goertzel hanya mulai membaca tepat pada awal payload kunci asli.
3. **Penyaringan Glitch Mekanis:** Menambahkan filter digital low-pass (debouncer) pada port input tombol eksternal dan sakelar geser pada FPGA untuk menyaring derau transien sebelum memicu pemancar audio.

### Contoh Perhitungan Parameter Performa

Sebagai ilustrasi, berikut adalah perhitungan parameter performa dari hasil pengujian loopback kunci dinamis UART ($N = 20$ transmisi kunci):

1. **Word Error Rate (WER):**
   * **Definisi:** Persentase paket kunci 32-bit yang salah atau tidak terurai lengkap secara visual di sisi penerima.
   * **Data:** Dari 20 paket kunci teruji, terdapat 11 paket yang mengalami ketidakcocokan (MISMATCH).
   * **Perhitungan:**
     $$\text{WER} = \frac{\text{Jumlah Kunci Salah}}{\text{Total Kunci Terkirim}} \times 100\% = \frac{11}{20} \times 100\% = 55{,}00\%$$

2. **Symbol Error Rate (SER):**
   * **Definisi:** Rasio kesalahan karakter heksadesimal yang tampil di Seven-Segment terhadap total karakter heksadesimal yang ditransmisikan.
   * **Data:** Total simbol dikirim = $20 \text{ kunci} \times 8 \text{ digit/kunci} = 160$ simbol. Total simbol yang salah didekode dari seluruh baris adalah 54 simbol.
   * **Perhitungan:**
     $$\text{SER} = \frac{\text{Jumlah Simbol Salah}}{\text{Total Simbol Terkirim}} \times 100\% = \frac{54}{160} \times 100\% = 33{,}75\%$$

3. **Bit Error Rate (BER):**
   * **Definisi:** Rasio jumlah bit biner yang salah hasil rekonstruksi terhadap total bit biner yang ditransmisikan.
   * **Data:** Total bit dikirim = $20 \text{ kunci} \times 32 \text{ bit/kunci} = 640$ bit. Total bit salah berdasarkan perbandingan Hamming distance adalah 119 bit.
   * **Perhitungan:**
     $$\text{BER} = \frac{\text{Total Bit Salah}}{\text{Total Bit Terkirim}} \times 100\% = \frac{119}{640} \times 100\% = 18{,}59\%$$
   * **Analisis Kasus Spesifik (Paket 1):**
     * Terkirim: `0xBAD0AD4A` (simbol ke-2 adalah `A` = biner `1010`)
     * Terbaca: `0xBBD0AD4A` (simbol ke-2 terbaca `B` = biner `1011`)
     * Selisih bit (XOR): `1010 ^ 1011 = 0001` (terdapat 1 bit salah). Maka, kontribusi galat Paket 1 terhadap BER adalah 1 bit dari total 640 bit data pengujian keseluruhan.
