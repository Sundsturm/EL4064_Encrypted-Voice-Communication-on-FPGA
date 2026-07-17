# BAB 4: PEMODELAN MATLAB

Bab ini membahas pemodelan simulasi matematis dari algoritma pemrosesan sinyal pada sistem enkripsi suara berbasis DTMF menggunakan MATLAB. Pemodelan ini dilakukan untuk memvalidasi algoritma, merancang parameter filter, serta menyimulasikan efek kuantisasi aritmetika titik tetap (*fixed-point*) sebelum diimplementasikan ke dalam arsitektur perangkat keras digital RTL (VHDL). Berdasarkan rancangan, bab ini mengulas pemodelan tiga subsistem utama pemroses sinyal: Subsistem Pengirim (TX), Subsistem Penerima (RX), dan Subsistem Top-Level. Subsistem Antarmuka & Kendali dilewati pada bab ini karena tidak melibatkan pemrosesan sinyal digital khusus yang dimodelkan di MATLAB.

---

## 4.1. Subsistem Pengirim (TX)

Pemodelan pengiriman DTMF pada sisi pengirim bertujuan untuk membangkitkan sinyal analog audio digital yang mewakili 12 segmen simbol pengiriman (4 simbol preamble `"##3#"` diikuti oleh 8 simbol payload kunci 32-bit). Kode pemodelan diimplementasikan pada berkas [generate_dtmf.m](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/DTMF-Sender-TX/generate_dtmf.m) dan [sine_gen.m](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/DTMF-Sender-TX/sine_gen.m).

### 4.1.1. Pembangkitan Gelombang Berbasis NCO
Pembangkitan gelombang sinus murni dikembangkan dengan memodelkan konsep *Numerically Controlled Oscillator* (NCO) pada berkas [sine_gen.m](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/DTMF-Sender-TX/sine_gen.m). Pada model ini, sebuah akumulator fase 32-bit melacak sudut fase gelombang secara dinamis dengan menambahkan increment fase (`phase_incr`) pada setiap sampel. Increment fase ditentukan oleh persamaan $\text{phase\_incr} = \text{round} \left( \frac{f \times 2^{32}}{F_s} \right)$, di mana $f$ adalah frekuensi target DTMF (grup rendah atau tinggi) dan $Fs = 32000\text{ Hz}$ adalah laju sampling audio codec.

Untuk menghemat penggunaan memori ROM, sistem hanya menyimpan data gelombang sinus pada kuadran pertama ($0$ s.d. $\pi/2$) dengan ukuran tabel lookup 1024 alamat (`addr_bits => 10`). Untuk merekonstruksi gelombang penuh $2\pi$, logika pemetaan NCO memeriksa bit kuadran pada akumulator fase. Pada kuadran 1 dan 3, alamat ROM dibaca searah dari indeks 0 s.d. 1023. Sebaliknya, pada kuadran 2 dan 4, indeks alamat dicerminkan menggunakan persamaan $\text{addr} = 1023 - \text{index\_fase}$. Selain itu, tanda amplitudo gelombang bernilai positif pada kuadran 1 dan 2, sedangkan nilainya dinegasikan (negatif) saat fasa berada pada kuadran 3 dan 4.

```matlab
% Cuplikan implementasi NCO pada sine_gen.m
acc = uint32(mod(double(phase_acc) + double(phase_incr), 2^32));
rom_index = bitand(bitshift(phase_acc, -shift_amt), rom_mask);

if quadrant == 1 || quadrant == 3
    rom_addr = rom_index;
else
    rom_addr = uint32(rom_depth - 1) - rom_index;
end
```

### 4.1.2. Transmisi Kontinu (Continuous Phase DTMF)
Sekuens transmisi dirancang agar berjalan kontinu tanpa ada jeda sunyi (*silence gap*) antarsimbol 20 ms (640 sampel). Skrip [generate_dtmf.m](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/DTMF-Sender-TX/generate_dtmf.m) melacak keadaan internal (*NCO state*) dari satu simbol ke simbol berikutnya. Dengan mempertahankan nilai akhir akumulator fase dari simbol sebelumnya saat berpindah nada, kontinuitas fase pada batas transisi simbol tetap terjaga. Hal ini sangat penting untuk mencegah timbulnya lonjakan amplitudo tajam yang dapat menghasilkan harmonisa frekuensi tinggi liar di luar pita suara.

```matlab
% Cuplikan penerusan state NCO antar simbol pada generate_dtmf.m
[data_low,  state_low]  = sine_gen(phase_incr_low,  samples_per_symbol, addr_bits, data_bits, state_low,  rst);
[data_high, state_high] = sine_gen(phase_incr_high, samples_per_symbol, addr_bits, data_bits, state_high, rst);
sum_val = data_low + data_high;
```

### 4.1.3. Simulasi Pembangkitan Sinyal DTMF
Pengujian simulasi pada subsistem pengirim berbasis direktori [MATLAB/DTMF-Sender-TX](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/DTMF-Sender-TX) dilakukan untuk memvalidasi fungsionalitas pembangkitan nada dual-tone terkuantisasi secara mandiri. Hasil pengujian disimulasikan dan divisualisasikan menggunakan plot domain waktu dan frekuensi untuk membuktikan bahwa pergantian simbol pada batas waktu 20 ms berjalan secara kontinu tanpa ada jeda mati (*silence gap*), serta memastikan level amplitudo dual-tone Q3.13 tidak mengalami pemotongan (*clipping*).

---

## 4.2. Subsistem Penerima (RX)

Pemodelan sisi penerima bertugas mensimulasikan deteksi sinyal yang masuk, sinkronisasi batas awal bingkai, demodulasi spektral Goertzel, serta rekonstruksi kunci biner.

### 4.2.1. Sinkronisasi Preamble Korelator I/Q
Preamble `"##3#"` dideteksi dengan menghitung korelasi kuadratik sefase (*in-phase*) dan fase kuadratatur (*quadrature*) pada berkas [frame_sync.m](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/Frame-Synchronization/frame_sync.m). Sinyal masukan dikalikan secara paralel dengan tabel gelombang sinus ($\sin$) dan kosinus ($\cos$) referensi lokal untuk frekuensi nada preamble ($697\text{ Hz}$, $941\text{ Hz}$, dan $1477\text{ Hz}$) berformat fixed-point Q2.14. Hasil perkalian ini kemudian diakumulasikan sepanjang bingkai berukuran 40 sampel (1.25 ms). Total daya diperoleh dari penjumlahan kuadrat komponen I dan Q untuk menolak kesalahan fase sinyal, berdasarkan persamaan $P_{\text{frame}} = I^2 + Q^2 = \left( \sum_{n=0}^{39} x[n]\sin[n] \right)^2 + \left( \sum_{n=0}^{39} x[n]\cos[n] \right)^2$. Selanjutnya, daya total bingkai dijumlahkan menggunakan jendela geser sepanjang 16 bingkai (640 sampel atau setara dengan 20 ms) untuk mewakili daya rata-rata satu simbol penuh.

```matlab
% Cuplikan korelasi I/Q dan perhitungan daya pada frame_sync.m
mult_sinsignal = sin_mult(inputsignal, refsins);
mult_cossignal = cosines_mult(inputsignal, refcosines);

[acc_sinsignal, acc_cossignal] = accu(mult_sinsignal, mult_cossignal, frame_size);
total_power = total_calc(acc_sinsignal, acc_cossignal);
batch_sums = sliding(total_power, batch_size);
```

### 4.2.3. Filter Goertzel & Dekoder Keputusan
Algoritma Goertzel untuk demodulasi nada DTMF dimodelkan secara komprehensif pada berkas [goertzel_detector.m](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/DTMF-Receiver-RX/goertzel_detector.m). Setiap sampel masukan diproses secara rekursif melalui persamaan diferensial orde-2: $s[n] = x[n] + 2\cos\left(\frac{2\pi f_i}{F_s}\right)s[n-1] - s[n-2]$. Setelah blok 640 sampel selesai diproses, daya spektral akhir dihitung menggunakan persamaan non-rekursif dan dinormalisasi dengan faktor $N^2$ untuk memberikan representasi daya yang proporsional terhadap amplitudo sinyal asli, menggunakan persamaan $P_{\text{Goertzel}} = \frac{s^2[N-1] + s^2[N-2] - 2\cos\left(\frac{2\pi f_i}{F_s}\right)s[N-1]s[N-2]}{N^2}$. 

Tahap akhir sistem diakhiri dengan dekoder keputusan dan perakitan kunci. Modul pengambil keputusan membandingkan magnitudo daya ke-8 kanal Goertzel untuk secara akurat memilih frekuensi terkuat dari masing-masing grup frekuensi rendah dan tinggi. Simbol DTMF dominan yang berhasil terdeteksi selanjutnya diterjemahkan menjadi representasi biner 4-bit, lalu dimasukkan ke dalam mekanisme register geser (*shift-add register*) secara kumulatif untuk direkonstruksi menjadi sebuah kata kunci 32-bit yang utuh dan valid.

```matlab
% Cuplikan filter Goertzel pada goertzel_detector.m
for n = 1:N
    q0 = samples(n) + coeff * q1 - q2;
    q2 = q1;
    q1 = q0;
end
raw_power = abs(q1 * q1 + q2 * q2 - coeff * q1 * q2);
power_val = raw_power / (N * N);
```

### 4.2.4. Simulasi Sinkronisasi dan Demodulasi (RX)
Pengujian simulasi pada subsistem penerima di bawah direktori [MATLAB/Frame-Synchronization](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/Frame-Synchronization) dan [MATLAB/DTMF-Receiver-RX](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/DTMF-Receiver-RX) memvalidasi keandalan deteksi awal bingkai dan demodulasi nada. Sinyal audio preamble `[#, #, 3, #]` yang bercampur dengan Gaussian noise diproses oleh [frame_sync.m](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/Frame-Synchronization/frame_sync.m) bersama dengan [flagging.m](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/Frame-Synchronization/flagging.m) dan [marking.m](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/Frame-Synchronization/marking.m) untuk menentukan waktu sinkronisasi fasa awal $T=0$. Setelah pemicu sinkronisasi didapatkan, filter bank Goertzel pada [goertzel_detector.m](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/DTMF-Receiver-RX/goertzel_detector.m) mengalkulasi daya frekuensi dominan untuk merekonstruksi kode DTMF 4-bit biner dan merakitnya ke dalam register kunci 32-bit.

---

## 4.3. Subsistem Top-Level

Subsistem Top-Level di MATLAB berfungsi sebagai pengintegrasi seluruh rantai pemrosesan sinyal dari pengirim ke penerima, sekaligus memodelkan media transmisi suara fisik.

### 4.3.1. Pemodelan Transceiver Integratif
Pemodelan integratif tingkat atas ditulis pada direktori utama [MATLAB](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB). Pemodelan ini mensimulasikan modulasi biner 32-bit di pengirim, pembentukan paket 12 simbol kontinu (4 preamble dan 8 payload), perambatan sinyal melalui saluran analog berderau, ekstraksi sinyal sinkronisasi fasa di korelator I/Q penerima, demodulasi 8 kanal Goertzel fixed-point, hingga perakitan kembali kunci biner 32-bit.

### 4.3.2. Simulasi Top-Level Sistem
Pengujian simulasi top-level dilakukan dengan menjalankan skenario transmisi data kunci utuh. Saluran transmisi dimodelkan dengan penambahan derau Gaussian untuk menguji batas ketahanan desibel deteksi. Hasil pengujian menunjukkan bahwa keseluruhan sistem pemrosesan sinyal terintegrasi di MATLAB berhasil memulihkan data kunci 32-bit secara akurat dengan tingkat kesalahan bit sebesar 0% (*Zero Bit Errors*), membuktikan validitas matematis algoritma sebelum diimplementasikan ke hardware.

```matlab
% Cuplikan skenario uji wajib simulasi top-level di generate_dtmf.m
test_sequence = ['#', '#', '3', '#', '3', 'A', '7', 'C', '9', 'B', '1', 'D'];
[sig, t] = generate_dtmf(test_sequence);
```

### 4.3.3. Analisis Hasil dan Log Simulasi
Simulasi dilakukan dengan menguji sekuens kunci masukan `'3A7C9B1D'` yang digabungkan dengan preamble `'##3#'` menjadi satu bingkai transmisi lengkap sebanyak 12 simbol. Berdasarkan log eksekusi simulasi, sistem berhasil menyelesaikan seluruh rantai proses dari pembangkitan hingga rekonstruksi akhir dengan rincian analisis sebagai berikut:

Sebelum sinyal dianalisis pada penerima, keberhasilan fungsionalitas pemancar DTMF di bawah berkas [generate_dtmf.m](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/MATLAB/DTMF-Sender-TX/generate_dtmf.m) diverifikasi terlebih dahulu melalui pengamatan diagram gelombang (*waveform*) hasil pembangkitan yang dilampirkan pada Gambar 4.1. Visualisasi gelombang tersebut menunjukkan bahwa sekuens nada kontinu sebanyak 12 simbol berhasil terbentuk sempurna dengan durasi masing-masing nada tepat sebesar 20 ms (640 sampel). Amplitudo sinyal gabungan dual-tone berformat Q3.13 terjaga secara kontinu pada batas transisi antar-simbol tanpa menunjukkan adanya jeda mati (*silence gap*), yang membuktikan keberhasilan transfer *state* fase internal NCO secara kontinu untuk menekan timbulnya komponen frekuensi tinggi liar di luar spektrum transmisi.


1.  **Kepatuhan Format dan Ketiadaan Saturasi Aritmetika:**
    Pada tahap korelasi I/Q dan kalkulasi daya sinkronisasi preamble, seluruh modul fixed-point diverifikasi terhadap rentang nilai teoretis dan aktualnya. Berdasarkan hasil log:
    *   Multiplication (`MULT SIN`/`MULT COS`): format Q3.13 memiliki rentang aktual sekitar $[-1.99, 1.99]$ dari rentang teoretis $[-4.0, 3.99]$ dengan tingkat saturasi $0.000\%$.
    *   Accumulation (`ACC SIN`/`ACC COS`): format Q8.8 memiliki rentang aktual $[-39.2, 33.9]$ dari rentang teoretis $[-128.0, 127.9]$ dengan tingkat saturasi $0.000\%$.
    *   Total Power (`TOTAL POWER`): format Q12.4 memiliki rentang aktual $[0.87, 1541.6]$ dari rentang teoretis $[-2048.0, 2047.9]$ dengan tingkat saturasi $0.000\%$.
    *   Sliding Window (`BATCH SUM`): format Q15.1 memiliki rentang aktual $[475.5, 10757.5]$ dari rentang teoretis $[-16384.0, 16383.5]$ dengan tingkat saturasi $0.000\%$.
    
    Hasil persentase saturasi sebesar $0.000\%$ pada seluruh blok ini membuktikan bahwa pemodelan komparasi bit fixed-point yang dirancang bebas dari bahaya *overflow clipping* yang dapat merusak kualitas sinyal. Berikut adalah cuplikan log komparasi format fixed-point untuk modul korelasi I/Q:
    ```text
    [MULT SIN]
      Format        : Q3.13 (WL=16)
      Range actual  : [-1.99597, 1.99646]
      Range theory  : [-4.00000, 3.99988]
      Saturation    : High=0 (0.000%), Low=0 (0.000%)

    [BATCH SUM]
      Format        : Q15.1 (WL=16)
      Range actual  : [475.50000, 10757.50000]
      Range theory  : [-16384.00000, 16383.50000]
      Saturation    : High=0 (0.000%), Low=0 (0.000%)
    ```

2.  **Ketepatan Deteksi Preamble FSM:**
    Log menunjukkan FSM sinkronisasi bekerja secara deterministik. Tahap *Flagging* mendeteksi awal kemunculan nada ganda `#` pada batch ke-33 (daya nada $941\text{ Hz} = 7829.50$ dan $1477\text{ Hz} = 6953.00$). Setelah kunci flag terkunci, tahap *Marking* secara akurat mengidentifikasi nada pembatas `3` pada batch ke-61 dengan kemiringan naik daya $697\text{ Hz} = 5797.00$ (meningkat dari nilai sebelumnya $5644.00$) serta berada di atas level daya nada pengawal $941\text{ Hz} = 5742.00$. Hal ini berhasil membangkitkan pemicu `goertzel_enable` untuk menyelaraskan awal pembacaan payload. Berikut adalah cuplikan log deteksi pada FSM sinkronisasi:
    ```text
    Sinyal Flag ("#") dimulai pada batch ke-33
      941 Hz  = 7829.50
      1477 Hz = 6953.00
    Mark "3" terdeteksi pada batch ke-61
      697 Hz  = 5797.000 (naik dari 5644.000)
      941 Hz  = 5742.000
      1477 Hz = 7065.000
    Detection complete: mark_valid = 1, goertzel_enable = 1.
    ```

3.  **Verifikasi Demodulasi Goertzel dan Perakitan Kunci:**
    Setelah sinyal sinkronisasi aktif, modul penerima memotong 8 simbol payload secara presisi pada rentang sampel 2561 s.d. 7680 (5120 sampel total). Setiap simbol 640 sampel didemodulasi menggunakan 8 filter Goertzel paralel. Log deteksi merekam daya energi rata-rata yang sangat kuat pada frekuensi dominan yang aktif (orde magnitudo daya sekitar $1.6 \times 10^7$ s.d. $1.7 \times 10^7$). Simbol yang terdeteksi kemudian dikonversi menjadi biner 4-bit dan digeser ke dalam register secara bertahap:
    *   Simbol 1: `'3'` (Code `0x3`) $\implies$ `[bit31-28]`
    *   Simbol 2: `'A'` (Code `0xA`) $\implies$ `[bit27-24]`
    *   Simbol 3: `'7'` (Code `0x7`) $\implies$ `[bit23-20]`
    *   Simbol 4: `'C'` (Code `0xC`) $\implies$ `[bit19-16]`
    *   Simbol 5: `'9'` (Code `0x9`) $\implies$ `[bit15-12]`
    *   Simbol 6: `'B'` (Code `0xB`) $\implies$ `[bit11-8]`
    *   Simbol 7: `'1'` (Code `0x1`) $\implies$ `[bit7-4]`
    *   Simbol 8: `'D'` (Code `0xD`) $\implies$ `[bit3-0]`
    
    Proses perakitan ini berhasil memulihkan kunci 32-bit utuh bernilai `0x3A7C9B1D` yang identik 100% dengan kunci expected awal, menghasilkan status kelulusan **`[PASS] Dekode sesuai ekspektasi!`** dengan tingkat kesalahan bit sebesar 0% (*Zero Bit Errors*). Berikut adalah cuplikan log demodulasi dan ringkasan hasil:
    ```text
    Simbol 1/8 -> Karakter: 3 | Code: 0x3 | Bits: 0011 | Low: 697Hz (E=1.75e+07) | High: 1477Hz (E=1.75e+07)
    Simbol 2/8 -> Karakter: A | Code: 0xA | Bits: 1010 | Low: 697Hz (E=1.62e+07) | High: 1633Hz (E=1.64e+07)
    ...
    Dekode Selesai. Reconstructed Key = 0x3A7C9B1D
    ------------------------------------------------------------------
    ==================================================================
      RINGKASAN HASIL
    ------------------------------------------------------------------
      Payload          : 3A7C9B1D
      Expected Key     : 0x3A7C9B1D
      Reconstructed Key: 0x3A7C9B1D
      Status           : [PASS] Dekode sesuai ekspektasi!
    ==================================================================
    ```
