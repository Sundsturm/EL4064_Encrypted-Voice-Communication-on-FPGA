I will read the Work Breakdown Structure (`docs/wbs.md`) to see the planned tasks, their current completion status, and what remaining work needs to be performed next.

Viewed wbs.md:1-160

Berdasarkan **WBS (`docs/wbs.md`)** dan perkembangan proyek saat ini, Anda berada pada **Fase 4: Pengujian Hardware & Analisis Performa (6 Juni - 8 Juni)**. 

Karena proses kompilasi top-level (`AcakCakap_Top`) di Quartus telah **sukses total dengan 0 error**, langkah-langkah konkret yang harus Anda lakukan berikutnya di laboratorium/hardware adalah sebagai berikut:

---

### 1. Pemrograman Board FPGA
* **File Program:** Gunakan file SRAM Object File (`.sof`) hasil kompilasi yang terletak di folder `quartus/` (biasanya `AcakCakap_Top.sof`).
* **Tool:** Buka **Quartus Prime Programmer** dan upload `.sof` tersebut ke board **DE10-Standard**.

### 2. Pengondisian Audio Fisik (Wiring Jack)
* Hubungkan kabel audio Jack 3.5 mm dari port **Line-Out** board pengirim (TX) ke port **Line-In** board penerima (RX).
* Jika Anda menguji menggunakan mode loopback pada *satu board*, hubungkan langsung **Line-Out** ke **Line-In** pada board yang sama.

### 3. Skenario Pengujian 1: Injeksi Kunci Statis via Saklar (SW)
1. Atur saklar **SW(8) = '0'** untuk menggunakan mode Kunci Statis.
2. Set nilai kunci 8-bit pada saklar **SW(7 downto 0)** (misal: `0x55`). Kunci 32-bit yang dikirimkan secara otomatis akan diulang 4 kali menjadi `0x55555555`.
3. Tekan tombol **KEY(1)** (lalu lepas) untuk memicu transmisi (*trigger blast* kontinu).
4. Amati tampilan pada Seven Segment **HEX5 s.d HEX0**:
   * Posisikan **SW(0) = '0'** untuk melihat 24-bit LSB (menampilkan heksadesimal `555555`).
   * Posisikan **SW(0) = '1'** untuk melihat 8-bit MSB (menampilkan heksadesimal `55----`).
5. Pastikan kunci yang diterima pada sisi RX sama persis dengan kunci yang dikirim.

### 4. Skenario Pengujian 2: Injeksi Kunci Dinamis via Serial UART
1. Hubungkan port UART FPGA ke PC Anda.
2. Buka serial terminal di PC (seperti PuTTY atau Tera Term) dengan konfigurasi:
   * **Baud Rate:** 115200 bps
3. Atur saklar **SW(8) = '1'** untuk menggunakan mode Kunci Dinamis dari UART.
4. Kirimkan 4-byte kunci diikuti dengan karakter *Line Feed* (`\n` atau `0x0A`) sebagai trigger pengiriman (misal: mengirimkan bytes `0x3A, 0x7C, 0x9B, 0x1D, 0x0A`).
5. Uji visualisasi Seven-Segment kembali menggunakan saklar **SW(0)** untuk memverifikasi kunci `0x3A7C9B1D` yang direkonstruksi di sisi penerima.

### 5. Koleksi Data Performa (Kombinasi dengan Kean)
Lakukan analisis performa modem DTMF kontinu ini pada 3 kondisi kanal berikut (catat Bit Error Rate / BER):
1. **Direct Cable Loopback:** Menguji laju kesalahan bit murni di media kabel tanpa derau ambient.
2. **Kanal Akustik Udara (Wireless):** Putar nada DTMF melalui speaker eksternal di sisi TX, lalu tangkap suaranya lewat microphone sisi RX untuk menguji ketahanan terhadap *acoustic/ambient noise*.
3. **Kanal VoIP (WhatsApp/LINE):** Lewatkan sinyal suara DTMF kontinu melalui panggilan telepon VoIP untuk memverifikasi apakah kompresi audio kompresor merusak modulasi nada kontinu Anda.