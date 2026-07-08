# Implementasi
## General Overview System
Jadi, sistem ini adalah voice-modem DTMF 32-bit satu arah yang menggunakan 2 FPGA, yaitu salah satunya receiver dan salah satu lainnnya transmitter. Berdasarkan hal tersebut, ada dua jenis pihak:
- Receiver
- Transmitter/Sender
### Pihak Receiver
Receiver ini terdiri atas DTMF detect (./dtmf_detect_hdl) dan kode receiver (./receiver_hdl) yang terdiri atas Frame Synchronization dan DTMF Decode. Fungsi masing-masing blok dapat dijelaskan sebagai berikut:
- DTMF Detect: Mendeteksi simbol DTMF yang dikirim oleh transmitter dengan membandingkan frekuensi output Goertzel dengan frekuensi DTMF.
- Frame Synchronization: Memastikan frame yang dibaca oleh pihak receiver sudah sesuai dengan frame yang dikirim oleh pihak transmitter dengan IQ Phase Demodulator untuk DTMF pada urutan simbol preamble/sync point/start-frame sequence "#, #, 3, #"
- DTMF Decode: Mengubah hasil bacaan dari blok DTMF Detect menjadi urutan biner 4-bit per simbol DTMF yang telah terdeteksi dan umumnya menghasilkan data 32-bit (8 x simbol DTMF yang terdeteksi)
### Pihak Transmitter
Transmitter terdiri atas DTMF Generator saja yang berfungsi untuk menghasilkan sinyal sinusoidal yang merepresentasikan urutan simbol DTMF tertentu berdasarkan input pihak sender dalam bentuk simbol DTMF. Umumnya, transmitter ini menghasilkan urutan simbil start-frame sequence sebanyak 4 simbol DTMF lalu dilanjutkan dengan 8 simbol DTMF payload yang akan dikirimkan ke pihak receiver sehingga 12 simbol yang dikirimkan.
### Hubungan Pihak Receiver dengan Pihak Transmitter
Hubungan antara kedua pihak ada pada frame synchronization. Start-frame sequence dan payload akan terbaca oleh pihak receiver pada blok DTMF Detect dan Frame Synchronization. Namun, DTMF Detect baru berjalan setelah Frame Synchronization mengirimkan sinyal enable ke DTMF Detect. Sinyal enable ini berasal dari hasil pendeteksian start-frame sequence. Harapannya adalah DTMF detect baru berjalan setelah simbol "3" dari start-frame sequence terdeteksi sehingga pembacaan oleh DTMF Detect baru mulai di simbol pertama payload.
### Audio Interface
Ada pengaturan audio interface di `Audio_interface.vhd` yang mengurus antarmuka antara pihak (Receiver dan/atau Transmitter) dengan sistem ini.
### Implementasi Sekarang
Sudah bisa dideploy di FPGA dengan kode `AcakCakap_Top.vhd` sebagai top-level file yang dikirim ke masing-masing FPGA.
## Masalah Implementasi
### 1: Seringnya pembacaan DTMF oleh pihak receiver yang stuck pada sequence sebelumnya
Hasil pengujian top-level dari `Implementasi Sekarang` ini dapat dilihat di fail `hasil_pengujian_fpga.png`. Dapat terlihat bahwa kunci yang terkirim dan kunci yang terbaca tidak sama dan ada mismatch (0x41E8883E berulang 3 kali). Hal ini terjadi secara berulang selama 3 kali sebelum ke pembacaan selanjutnya (0xE088FCO8). Mismatch ini berulang sehingga fenomena ini dapat disebut sebagai stuck pada sequence sebelumnya. Untuk sementara, abaikan, mismatch hasil sampai level simbol (Perbedaan kunci terkirim dan kunci terbaca pada 1-2 simbol saja) karena hal tersebut mungkin diakibatkan oleh ketidakkonsistenan dari blok DTMF Detect.

Bagaimana cara memperbaiki hal ini, khususnya pada tingkatan implementasi FPGA sesuai implementasi sekarang? Apa yang menjadi penyebab dari masalah ini?
