# Catatan Evaluasi

```
=== SKENARIO UJI VISUALISASI RX RECEIVER ===
Sekuens yang dibangkitkan: ##3#3A7C9B1D

--------------------------------------------------------------
  DTMF Generator Summary
  Fs = 32000 Hz | Duration = 20 ms/symbol | Total = 240 ms
--------------------------------------------------------------
  Seg   Time (ms)     Symbol    Low (Hz)    High (Hz) 
--------------------------------------------------------------
  1        0 -   20 ms   #         941         1477      
  2       20 -   40 ms   #         941         1477      
  3       40 -   60 ms   3         697         1477      
  4       60 -   80 ms   #         941         1477      
  5       80 -  100 ms   3         697         1477      
  6      100 -  120 ms   A         697         1633      
  7      120 -  140 ms   7         852         1209      
  8      140 -  160 ms   C         852         1633      
  9      160 -  180 ms   9         852         1477      
  10     180 -  200 ms   B         770         1633      
  11     200 -  220 ms   1         697         1209      
  12     220 -  240 ms   D         941         1633      
--------------------------------------------------------------


--- TAHAP 1: DETEKSI PREAMBLE & SINKRONISASI BINGKAI ---
=== HASIL DEMODULASI IQ & SINKRONISASI ===
Puncak Simbol '3' (697 Hz) ditemukan pada batch 97.
Puncak Simbol '#' ke-4 (941 Hz) divalidasi pada batch 129.
-> SYNC LOCK INDEX ditetapkan di sampel ke-5160 (Titik T=0 Payload)
Error using dtmf_receiver_top (line 26)
Panjang sinyal input setelah preamble tidak mencukupi untuk Payload (8 Simbol).

Error in run_receiver_test (line 32)
[reconstructed_key, sync_lock_index, batch_sums] = dtmf_receiver_top(sinyal_masuk);
                                                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

```

Dari simulasi uji *end-to-end* yang dilakukan di MATLAB, ditemukan **anomali pelebaran energi (Crosstalk / Leakage)** yang sangat masif (~70% bocor ke frekuensi lain) pada arsitektur Demodulator IQ (`exp 1.7 fixed point v4`). 

Anomali ini bukan diakibatkan oleh eror *coding*, melainkan akar matematis dari desain pemrosesan sinyalnya. Berikut adalah temuan dan usulan perbaikan arsitektural yang dapat diterapkan pada RTL maupun skrip MATLAB eksisting.

## 1. Jendela Accumulator (I&D) Terlalu Sempit
Pada `accu.m` (dan modul VHDLnya), ditetapkan `frame_size = 40` sampel (durasi 1.25 ms).
- **Akar Masalah**: Filter Integrate & Dump (I&D) bertindak sebagai Sinc-Filter di domain frekuensi. Dengan jendela 1.25 ms, filter ini hanya menekan frekuensi di kelipatan $1/0.00125 = 800$ Hz.
- Padahal, saat demodulasi IQ, sinyal masukan `#` (941 Hz + 1477 Hz) yang dikalikan dengan pembawa lokal 697 Hz akan menghasilkan **frekuensi campuran (difference frequency)** sebesar $|941 - 697| = 244$ Hz. 
- Gelombang 244 Hz memiliki periode ~4.1 ms. Karena jendela Anda hanya 1.25 ms, gelombang ini gagal dirata-rata menjadi nol (0) dan justru menghasilkan akumulasi nilai yang besar. Inilah sumber *crosstalk* raksasa tersebut.

## 2. Kesalahan Urutan: Power Kalkulasi vs Sliding Window
Pada alur yang ada: **IQ Mix → Accu (1.25 ms) → Power ($I^2 + Q^2$) → Sliding Window (16 batch)**
- **Akar Masalah**: Mengkuadratkan sinyal ($I^2 + Q^2$) *sebelum* membuang *crosstalk* 244 Hz sepenuhnya. Pengkuadratan membuat seluruh *crosstalk* menjadi nilai **positif**.
- Akibatnya, `sliding.m` (Moving Average) tidak lagi merata-rata *crosstalk* menjadi nol, melainkan **menjumlahkan energi positif** dari *crosstalk* tersebut hingga menggunung! Inilah yang membuat garis hijau (697 Hz) ikut naik drastis saat simbol `#` dikirimkan.

## Usulan Perbaikan (Pilih Salah Satu)

### Opsi A (Paling Matematis & Hemat Resource): Pindahkan Posisi Sliding
Ubah urutan kalkulasi menjadi: **IQ Mix → Accu (1.25 ms) → Sliding Window (I dan Q) → Power ($I^2 + Q^2$)**
Jika Anda meletakkan Moving Average (Sliding) di komponen *I* dan *Q* sebelum dikuadratkan, Sliding Window ini akan berfungsi layaknya kaskade LPF (Low-Pass Filter) tambahan berdurasi 20 ms. Filter 20 ms ini akan sempurna membunuh *crosstalk* 244 Hz hingga ke akar-akarnya. Setelah bersih, barulah Anda mengkuadratkannya.

### Opsi B (Paling Sederhana): Perlebar Jendela Accumulator Utama
Abaikan pembagian *batch/frame*. Buatlah ukuran Accumulator (I&D) Anda langsung berukuran penuh 1 simbol, yaitu `frame_size = 640` sampel (20 ms). Jendela 20 ms akan memberikan daya tekan Sinc-Filter yang luar biasa kuat (kelipatan 50 Hz), sehingga *crosstalk* 244 Hz otomatis mati, lalu Anda tinggal menghitung powernya sekali saja per 20 ms.

## 3. Evaluasi Skema Pendeteksian Periodik (Data Valid) Payload
Berdasarkan identifikasi pada `Goertzel.vhd`, sistem Anda sejatinya **sudah memiliki mekanisme pendeteksian periodik implisit**. Terdapat *counter* yang menghitung persis 640 sampel (1 Simbol), yang mana saat penuh, ia akan memicu kalkulasi *power* akhir dan mengirimkan sinyal `out_valid = '1'` ke blok-blok hilir secara otomatis.

**Kelemahan & Syarat Sinkronisasi:**
Mekanisme 640-sampel ini berdetak secara statik sejak modul dihidupkan (*out of reset*). Jika ia tidak diselaraskan, jendela sampling Goertzel akan bergeser (*misaligned*) dari rentang waktu simbol Payload yang sebenarnya, dan justru membelah dua simbol yang bersebelahan.
Oleh karena itu, modul Preamble Detector (Frame Sync) wajib:
1. Menahan sinyal `rst` (Reset) pada Goertzel (serta blok turunan lainnya) selama fase pencarian *Preamble*.
2. Baru merilis `rst` menjadi `'0'` **tepat pada detik T=0 Payload** (sebagaimana parameter `sync_lock_index` yang dikalkulasi pada simulasi MATLAB).
Dengan demikian, *counter* 640-sampel tersebut akan mereset hitungannya dan mulai berjalan selaras 100% dengan batas-batas pergantian simbol Payload.
