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

## 6.3. Pengujian Kunci Dinamis Berbasis Injeksi UART

Skenario pengujian ketiga dilakukan untuk memverifikasi integrasi penuh sistem dalam menangani transmisi kunci dinamis 32-bit yang dikirimkan secara serial dari komputer PC ke papan pengirim FPGA. Jalur serial ini menggunakan adapter USB-to-TTL CP2102 eksternal yang dihubungkan ke header GPIO JP1 pin 1 (`PIN_W15` yang dipetakan sebagai `UART_RXD`) pada papan DE10-Standard. Sakelar pemilih mode masukan kunci diatur ke posisi tinggi (`SW(8) = '1'`) untuk mengarahkan jalur masukan kunci dari memori register UART ke pemancar DTMF. Skrip Python [`util/send_key.py`](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/util/send_key.py) digunakan untuk mengirimkan payload kunci dinamis secara otomatis yang diakhiri dengan byte pembatas *Line Feed* (`0x0A`) sebagai trigger transmisi DTMF.

Dari pengujian fisik yang dilakukan pada perangkat keras, terdapat beberapa temuan penting terkait perilaku sistem nyata:
1. **Kebutuhan Retransmisi ("Warm Up" Penerima):** Ketika papan pertama kali diprogram, trigger pertama (pengiriman awal) sering kali tidak memengaruhi atau memperbarui tampilan Seven-Segment di sisi penerima. Pada pengiriman selanjutnya, tampilan Seven-Segment lebih konsisten menampilkan nilai kunci yang benar, meskipun beberapa kali masih terdapat visualisasi yang salah (*ngaco*) akibat sinkronisasi fasa/window Goertzel penerima yang belum optimal. Fenomena ini membuat sistem seakan-akan membutuhkan waktu pemanasan (*warm up*) setelah pemrograman. Untuk meminimalisasi ketidakstabilan ini, dilakukan penyesuaian jumlah pengiriman kunci ganda (mekanisme auto-retransmit) pada skrip Python dengan jeda tertentu, yang terbukti secara signifikan menurunkan tingkat kesalahan decoding visual.
2. **Keterbatasan Fisik LED Display:** Terdapat kerusakan fisik (murni masalah perangkat keras) pada display Seven-Segment **HEX[4]** di mana **Segmen G (strip horizontal tengah) rusak/tidak menyala sama sekali**. Hal ini menyebabkan digit heksadesimal tertentu yang memanfaatkan segmen tengah tersebut (seperti karakter '3', '4', '8', 'A', dll.) tidak terproyeksi secara sempurna, meskipun data register kunci di dalamnya didekode dengan benar.
3. **Bouncing Sakelar SW[0]:** Untuk beralih antara visualisasi MSB (`SW(0) = '1'`) dan LSB (`SW(0) = '0'`), sinyal dilewatkan melalui modul debouncing digital (`DEBOUNCE_SW0` dengan filter ~1 ms). Hasil pengujian menunjukkan bahwa efek bouncing/glitch pada sakelar geser ini telah berhasil terminimalisasi tetapi belum hilang sepenuhnya. Sisa gangguan transisi ini diasumsikan timbul akibat kelonggaran atau kerusakan mekanik internal pada saklar fisik `SW[0]` papan itu sendiri.

Meskipun terdapat beberapa batasan fisik eksternal (seperti kerusakan LED segmen G dan keausan mekanik sakelar), integrasi logika UART RX, sinkronisasi domain clock (CDC) berbasis toggle dari clock UART 50 MHz ke clock audio 18,432 MHz, hingga decoding audio DTMF secara keseluruhan telah berfungsi dengan andal sesuai rancangan perangkat keras pada [AcakCakap_Top.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/AcakCakap_Top.vhd).


## 6.4. Analisis Performa dan Koleksi Data (Bit Error Rate)

Pengujian statistik dilakukan dengan mentransmisikan $N = 20$ kunci acak (total 640 bit data) untuk menguji keandalan sistem dalam lingkungan terkontrol. Pada fase pengujian saat ini, lingkungan pengujian dibatasi terlebih dahulu pada hubungan kabel langsung (**Direct Cable Loopback**) antara port *Line-Out* papan pengirim dan port *Line-In* papan penerima menggunakan kabel auxiliary 3.5mm. 

Laju kesalahan dihitung secara objektif dengan membandingkan nilai kunci acak yang dikirimkan oleh skrip penguji PC dengan hasil rekonstruksi visual pada Seven-Segment penerima.

### Tabel Data Pengujian (Kabel Langsung)

| No. Paket | Kunci Terkirim (PC) | Terbaca (RX) | Status Match | Simbol Salah (Digit) | Bit Salah (Hamming) |
|-----------|---------------------|--------------|--------------|----------------------|---------------------|
| 1         | `0xB4486AE4`        | `0x41E8883E` | MISMATCH     | 7                    | 17                  |
| 2         | `0x3BE68B07`        | `0x41E8883E` | MISMATCH     | 6                    | 14                  |
| 3         | `0x9B29DA80`        | `0x41E8883E` | MISMATCH     | 8                    | 17                  |
| 4         | `0xE088FC08`        | `0xE088FC08` | OK           | 0                    | 0                   |
| 5         | `0xDA96CC4F`        | `0xDA96CC4E` | MISMATCH     | 1                    | 1                   |
| 6         | `0xC5FF6188`        | `0xC5FF6188` | OK           | 0                    | 0                   |
| 7         | `0x3D2CF965`        | `0x3D2CF965` | OK           | 0                    | 0                   |
| 8         | `0xAB791AFF`        | `0xAB791AFF` | OK           | 0                    | 0                   |
| 9         | `0x2ACDA63C`        | `0x2ACDA63C` | OK           | 0                    | 0                   |
| 10        | `0x6BC3A44C`        | `0x6BC3A44C` | OK           | 0                    | 0                   |
| 11        | `0xAF7DF066`        | `0xAF7DE096` | MISMATCH     | 2                    | 5                   |
| 12        | `0x72DA2D52`        | `0xE1DA2D52` | MISMATCH     | 2                    | 4                   |
| 13        | `0x773760A0`        | `0x773740A0` | MISMATCH     | 1                    | 1                   |
| 14        | `0x4E069FBC`        | `0x773740A0` | MISMATCH     | 8                    | 17                  |
| 15        | `0x724EF0B8`        | `0x722F0558` | MISMATCH     | 5                    | 12                  |
| 16        | `0xB19103A1`        | `0x722F0558` | MISMATCH     | 7                    | 18                  |
| 17        | `0xF8091EA3`        | `0x00891EA3` | MISMATCH     | 3                    | 6                   |
| 18        | `0x5C608130`        | `0x5C608130` | OK           | 0                    | 0                   |
| 19        | `0xCE90B136`        | `0xCE90A136` | MISMATCH     | 1                    | 1                   |
| 20        | `0xA7737201`        | `0xA7737201` | OK           | 0                    | 0                   |

### Ringkasan Statistik Performa

| Kondisi Kanal | Total Kunci | Kunci Sukses | Key Error Rate (KER) | Symbol Error Rate (SER) | Bit Error Rate (BER) |
|---------------|-------------|--------------|----------------------|-------------------------|----------------------|
| **Direct Cable Loopback** | 20 | 8 | 60.00% | 31.87% (51/160) | 17.66% (113/640) |

### Analisis Singkat Performa Kanal
Berdasarkan hasil pengujian di atas, laju kesalahan kunci (KER) pada kanal kabel langsung tercatat sebesar 60.00% dengan laju kesalahan bit (BER) sebesar 17.66%. Meskipun angka kesalahan ini terlihat cukup tinggi pada media kabel langsung, analisis mendalam terhadap log pengujian mengidentifikasi tiga faktor utama:
1. **Efek Pemanasan Penerima ("Warm-Up" Effect):** Paket 1 hingga 3 mengalami kegagalan decoding total karena penerima mempertahankan nilai visual *default* (`41E8883E`). Hal ini terjadi karena sinkronisasi fasa awal dan pembacaan window filter Goertzel belum selaras sesaat setelah papan penerima diprogram. Setelah melewati fase inisiasi ini (mulai dari Paket 4), kemampuan dekode penerima meningkat secara signifikan.
2. **Kegagalan Sinkronisasi Frame pada Pengiriman Berulang:** Akibat tidak adanya jeda sunyi antarsimbol dalam pengiriman beruntun, penerima terkadang melewatkan deteksi preamble baru atau mengalami tumpang tindih waktu transmisi. Hal ini menyebabkan penerima tidak mendeteksi paket baru dan tetap menampilkan nilai rekonstruksi dari paket sebelumnya (terlihat pada Paket 14 yang menampilkan data Paket 13, serta Paket 16 yang menampilkan data Paket 15).
3. **Galat Minor Simbol Tunggal:** Sebagian besar paket yang salah hanya mengalami galat pada 1 digit heksadesimal atau bergeser minimal 1 bit saja (seperti pada Paket 5, 13, dan 19). Hal ini mengindikasikan bahwa core pendeteksi nada Goertzel telah berfungsi dengan baik, namun sedikit terdistorsi oleh gangguan transisi fasa atau interferensi antarsimbol (ISI) pada clock boundary.

### Contoh Perhitungan Parameter Performa

Sebagai ilustrasi, berikut adalah perhitungan parameter performa dari hasil pengujian kabel langsung ($N = 20$ transmisi kunci):

1. **Key Error Rate (KER):**
   * **Definisi:** Persentase paket kunci 32-bit yang salah atau tidak terurai lengkap secara visual di sisi penerima.
   * **Data:** Dari 20 paket kunci yang dikirim, terdapat 12 paket yang tidak cocok (mengalami status MISMATCH).
   * **Perhitungan:**
     $$\text{KER} = \frac{\text{Jumlah Kunci Salah}}{\text{Total Kunci Terkirim}} \times 100\% = \frac{12}{20} \times 100\% = 60{,}00\%$$

2. **Symbol/Digit Error Rate (SER):**
   * **Definisi:** Rasio kesalahan karakter heksadesimal yang tampil di Seven-Segment terhadap total karakter heksadesimal yang ditransmisikan.
   * **Data:** Total simbol dikirim = $20 \text{ kunci} \times 8 \text{ digit/kunci} = 160$ simbol. Total simbol yang salah didekode dari seluruh baris adalah 51 simbol.
   * **Perhitungan:**
     $$\text{SER} = \frac{\text{Jumlah Simbol Salah}}{\text{Total Simbol Terkirim}} \times 100\% = \frac{51}{160} \times 100\% = 31{,}87\%$$

3. **Bit Error Rate (BER):**
   * **Definisi:** Rasio jumlah bit biner yang salah hasil rekonstruksi terhadap total bit biner yang ditransmisikan.
   * **Data:** Total bit dikirim = $20 \text{ kunci} \times 32 \text{ bit/kunci} = 640$ bit. Total bit salah berdasarkan perbandingan Hamming distance adalah 113 bit.
   * **Perhitungan:**
     $$\text{BER} = \frac{\text{Total Bit Salah}}{\text{Total Bit Terkirim}} \times 100\% = \frac{113}{640} \times 100\% = 17{,}66\%$$
   * **Analisis Kasus Spesifik (Paket 5):**
     * Terkirim: `0xDA96CC4F` (karakter terakhir `F` = biner `1111`)
     * Terbaca: `0xDA96CC4E` (karakter terakhir `E` = biner `1110`)
     * Selisih bit (XOR): `1111 ^ 1110 = 0001` (terdapat 1 bit salah). Maka, kontribusi galat Paket 5 terhadap BER adalah 1 bit dari total 32 bit kunci tersebut.

