# BAB 5: IMPLEMENTASI REGISTER-TRANSFER LEVEL (RTL)

Bab ini mendeskripsikan perancangan arsitektur sirkuit digital pada tingkat *Register-Transfer Level* (RTL) yang ditulis menggunakan VHDL-2008. Setiap subsistem diimplementasikan ke dalam blok-blok fungsional tersinkronisasi detak untuk memproses sinyal audio digital secara langsung (*real-time*). Penjabaran berikut diurutkan berdasarkan subsistem pembentuk diikuti dengan integrasi top-level sistem.

---

## 5.1. Subsistem Antarmuka & Kendali

Subsistem Antarmuka & Kendali menangani sinkronisasi detak audio, konfigurasi eksternal IC codec audio, pengalihan clock domain, antarmuka pemicu tombol, serta penyeleksian halaman visualisasi tujuh segmen.

### 5.1.1. Audio PLL
Detak referensi dari papan FPGA sebesar $50\text{ MHz}$ (`CLOCK_50`) disalurkan ke IP-Core `audiopll` yang terintegrasi secara internal. IP-Core ini diinstansiasi sebagai PLL (*Phase-Locked Loop*) untuk menyintesis master clock audio sebesar $18,432\text{ MHz}$ (`AUD_XCK`). Master clock ini menjadi basis pewaktuan utama untuk seluruh subsistem pemrosesan audio digital dan logika transceiver di dalam chip codec.

```vhdl
-- Cuplikan instansiasi Audio PLL pada Audio_interface.vhd
Audio_PLL : entity audiopll.AudioPLL port map(
    refclk   => clk,
    rst      => done, -- reset hingga inisialisasi I2C selesai
    outclk_0 => AUD_XCK -- output master clock audio (~18.432MHz)
);
```

### 5.1.2. Pembagian Clock
Pembagian clock untuk menghasilkan bit clock (`AUD_BCLK`) dan word clock sampling sebesar $32\text{ kHz}$ dikendalikan secara sinkron oleh register pencacah internal pada berkas [Audio_interface.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/Audio_interface.vhd). Penentuan pembagian frekuensi detak tersebut didasarkan pada perhitungan matematis berikut:
$$\text{word\_count} = \frac{18432000\text{ Hz}}{2 \times 32000\text{ Hz}} = 288$$
$$\text{bit\_count} = \frac{288}{2 \times 16} = 9$$
Di mana nilai $\text{word\_count}$ menunjukkan bahwa LRCK berubah keadaan setiap 288 siklus clock, sedangkan $\text{bit\_count}$ menunjukkan bahwa `AUD_BCLK` berubah keadaan setiap 9 siklus clock.

```vhdl
-- Cuplikan pembagian detak pada Aud_Bclock di Audio_interface.vhd
if(bcount >= bit_range - 1) then
    bcount := 0;
    AUD_BCLK <= not AUD_BCLK;
else
    bcount := bcount + 1;
end if;
if(wcount >= word_range - 1) then
    wcount := 0;
    LRCK <= not LRCK;
else
    wcount := wcount + 1;
end if;
```

### 5.1.3. Konfigurasi Register Codec (I2C)
Modul [i2c.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/i2c.vhd) bertindak sebagai pengendali bus I2C master untuk mengonfigurasi chip audio codec WM8731 secara eksternal. Parameter konfigurasi ditransmisikan dalam format biner `0x101A` yang bersesuaian dengan format sampling $32\text{ kHz}$ codec tersebut. Pengiriman register ini memastikan codec siap beroperasi pada parameter frekuensi sampling dan lebar bit data yang ditentukan.

```vhdl
-- Cuplikan inisialisasi parameter konfigurasi I2C di Audio_interface.vhd
SAMPLE_CTRL <= x"100E" when SAMPLE_RATE = 8 else
               x"101A" when SAMPLE_RATE = 32 else
               x"101E" when SAMPLE_RATE = 96 else
               x"1002"; -- default 48KHz
```

### 5.1.4. Transceiver I2S Serial-to-Paralel
Proses pengiriman dan penerimaan bit audio secara serial diatur oleh FSM 12-status (terdiri atas status `wait1`, `wait2`, `left1` s.d. `left5`, dan `right1` s.d. `right5`) pada modul [Audio_interface.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/Audio_interface.vhd). FSM ini bertugas mengoversi serial data ADC `AUD_ADCDAT` menjadi format paralel signed 16-bit `Lin`/`Rin`, sekaligus mengonversi sinyal paralel `Lout`/`Rout` menjadi sinyal serial DAC `AUD_DACDAT`. Pada setiap akhir konversi audio saluran kiri, pulsa jabat tangan `Ldone` diaktifkan selama satu siklus detak.

```vhdl
-- Cuplikan FSM I2S pada Audio_interface.vhd
case RCV is
    when wait1 =>	
        if(LRCK='0') then RCV <= wait2; end if;
    when left1 =>
        if(AUD_BCLK='0') then RCV <= left2; end if;
        AUD_DACDAT <= Lout(15-k);
    when left2 =>
        if(AUD_BCLK='1') then 
            RCV <= left3;	
            Lin(15-k) <= AUD_ADCDAT;
        end if;
    -- status lainnya...
```

### 5.1.5. Penanganan Clock-Domain Crossing (CDC)
Penerimaan data serial UART berjalan pada domain clock papan $50\text{ MHz}$ (`CLOCK_50`), sementara pengolahan dan decoding berjalan pada clock audio $18,432\text{ MHz}$ (`AUD_XCK`). Untuk menjamin keamanan transfer data antar domain detak ini, sirkuit sinkronisasi 2-FF digunakan untuk menyeberangkan sinyal validasi data serial `uart_rx_valid` secara aman dari domain $50\text{ MHz}$ ke domain $18,432\text{ MHz}$. Hal ini meniadakan risiko metastabilitas pada saat penangkapan data masukan.

```vhdl
-- Sirkuit 2-FF Synchronizer pada domain AUD_XCK
CDC_UART_VALID : process(AUD_XCK)
begin
    if rising_edge(AUD_XCK) then
        uart_valid_meta   <= uart_rx_valid;
        uart_valid_sync   <= uart_valid_meta;
        uart_valid_synced <= uart_valid_sync;
    end if;
end process;
```

### 5.1.6. Modul Penerima UART
Byte data paralel `uart_rx_data` di-latch ke register `uart_data_latch` pada domain $50\text{ MHz}$ saat valid terdeteksi. Selanjutnya, UART Protocol FSM yang berjalan pada clock `AUD_XCK` memantau tepi naik sinyal tersinkronisasi `uart_valid_synced`, menggeser byte data ke register kunci 32-bit `uart_key_reg`, dan memberikan pulsa pemicu `uart_trigger <= '1'` saat mendeteksi karakter akhir Line Feed (`0x0A`).

```vhdl
-- Cuplikan pergeseran byte UART pada domain AUD_XCK di AcakCakap_Top.vhd
if uart_valid_synced = '1' and prev_valid = '0' then
    if uart_data_latch = x"0A" then -- 0x0A = Line Feed (\n) = trigger
        uart_trigger <= '1';
    else
        uart_key_reg <= uart_key_reg(23 downto 0) & uart_data_latch;
    end if;
end if;
```

### 5.1.7. Logika Pemicu Transmisi & FSM Tombol
Masukan dari tombol fisik `KEY(1)` dikelola oleh FSM `FSM_COMMAND` pada tepi jatuh (*falling-edge*) melalui transisi status `WAIT_FOR_PRESS`, `WAIT_FOR_RELEASE`, dan `RELEASE_STATE` untuk menghasilkan pulsa kendali `command` yang memicu dimulainya proses transmisi paket DTMF.

```vhdl
-- Cuplikan FSM Command pada AcakCakap_Top.vhd
case button_state is 
    when WAIT_FOR_PRESS =>
        command <= '0';
        if(KEY(1)='0') then 
            button_state <= WAIT_FOR_RELEASE;
        end if;
    when WAIT_FOR_RELEASE =>
        if(KEY(1)='1') then 
            button_state <= RELEASE_STATE;
        end if;
    when RELEASE_STATE => 
        command <= '1';
        button_state <= WAIT_FOR_PRESS;
end case;
```

### 5.1.8. Multiplexing Tampilan Seven-Segment
Untuk kebutuhan visualisasi, sakelar geser `SW(0)` digunakan untuk mengontrol multiplexing tampilan display 7-segmen. Pada mode LSB (`SW(0) = '0'`), sistem memetakan bit 23 s.d. 0 dari kunci hasil pemulihan ke display `HEX5` s.d. `HEX0`. Sedangkan pada mode MSB (`SW(0) = '1'`), sistem memetakan bit 31 s.d. 24 pada `HEX5` dan `HEX4`, dan memaksa display `HEX3` s.d. `HEX0` untuk menampilkan karakter strip aktif-rendah.

```vhdl
-- Cuplikan multiplexing visualisasi pada AcakCakap_Top.vhd
VISUALIZATION_MUX : process(SW(0), reconstructed_key_32bit)
begin
    if SW(0) = '0' then
        HEX0 <= hex_to_sevseg(reconstructed_key_32bit(3 downto 0));
        HEX1 <= hex_to_sevseg(reconstructed_key_32bit(7 downto 4));
        -- pemetaan HEX2 s.d. HEX5...
    else
        HEX0 <= "0111111"; -- tampilan strip '-'
        HEX1 <= "0111111";
        HEX4 <= hex_to_sevseg(reconstructed_key_32bit(27 downto 24));
        HEX5 <= hex_to_sevseg(reconstructed_key_32bit(31 downto 28));
    end if;
end process;
```

---

## 5.2. Subsistem Pengirim (TX)

Subsistem Pengirim membangkitkan sinyal biner representasi DTMF berdasarkan masukan kunci 32-bit. Implementasi RTL ditulis pada berkas [generate_dtmf_signed.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/sender_hdl/generate_dtmf_signed.vhd) and [sine_gen_signed.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/sender_hdl/sine_gen_signed.vhd).

#### 5.2.1. Inisialisasi ROM Lookup Table (LUT)
Tabel lookup (ROM) diinisialisasi secara statis pada berkas [sine_gen_signed.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/sender_hdl/sine_gen_signed.vhd). Guna menghemat memori FPGA, tabel ini hanya menyimpan data gelombang sinus untuk kuadran pertama ($0$ s.d. $\pi/2$). Nilai ROM dihitung menggunakan fungsi internal VHDL pada fase sintesis dengan penskalaan amplitudo ke setengah rentang positif agar aman saat dilakukan negasi tanda.

```vhdl
-- Cuplikan fungsi inisialisasi ROM di sine_gen_signed.vhd
function init_rom return rom_type is
  variable rom_v : rom_type;
  variable angle : real;
  variable sin_scaled : real;
begin
  for i in rom_addr_range loop
    angle := real(i) * ((MATH_PI/2.0) / real(rom_depth));
    sin_scaled := sin(angle) * (2.0**(rom_width-1) - 1.0);
    rom_v(i) := to_unsigned(integer(round(sin_scaled)), rom_width);
  end loop;
  return rom_v;
end init_rom;
```

### 5.2.2. Akumulator Fase NCO
Sistem pelacakan sudut fase menggunakan akumulator fasa 32-bit (`phase_acc`) yang berjalan pada detak clock master `AUD_XCK`. Pada setiap siklus clock, akumulator ini ditambahkan dengan increment fase (`phase_incr`) yang dikirimkan oleh decoder digit. Untuk mereproduksi perilaku aritmetika titik tetap perangkat keras secara presisi, akumulator ini dibiarkan meluap secara natural (*wraparound*) pada batas nilai maksimal 32-bit.

```vhdl
-- Cuplikan akumulator fase di sine_gen_signed.vhd
ACC_PROC : process(clk)
  variable acc : unsigned(phase_acc'range);
begin
  if rising_edge(clk) then
    if rst = '1' then
      phase_acc <= "01000000000000000000000000000000"; -- Reset ke 90 derajat
    else
      acc := phase_acc + phase_incr;
      if acc(phase_acc_addr_range) = rom_depth - 1 then
        acc := acc + base_phase_acc_incr;
      end if;
      phase_acc <= acc;
    end if;
  end if;
end process;
```

### 5.2.3. Pemetaan Kuadran & Rekonstruksi Sinus
Sudut fasa 32-bit dipecah untuk menentukan alamat baca ROM dan tanda amplitudo. Dua bit teratas akumulator fasa mengidentifikasi kuadran fasa saat ini ($00$, $01$, $10$, atau $11$). Logika pemetaan alamat ROM mencerminkan indeks alamat pada kuadran genap, sedangkan logika rekonstruksi amplitudo mengalihkan tanda bit signed output 16-bit menjadi negatif ketika fasa berada di kuadran ke-3 dan ke-4.

```vhdl
-- Cuplikan pencerminan alamat dan penentuan tanda amplitudo di sine_gen_signed.vhd
ROM_ADDR_PROC : process(quadrant, phase_acc)
begin
  case quadrant is
    when "01" | "11" =>
      rom_addr <= phase_acc(phase_acc_addr_range);
    when others => -- "00" OR "10"
      rom_addr <= (rom_depth - 1 - phase_acc(phase_acc_addr_range));
  end case;
end process;
```

### 5.2.4. Mesin Sandi Simbol (Digit Decoder)
Modul [generate_dtmf_signed.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/sender_hdl/generate_dtmf_signed.vhd) memuat proses kombinasional `DIGIT_DECODER`. Proses ini bertugas memetakan simbol DTMF 4-bit (`tone_digit`) menjadi nilai kenaikan fasa 32-bit (`phase_incr_low` dan `phase_incr_high`) yang dibutuhkan oleh modul generator sinus untuk menghasilkan frekuensi nada rendah dan tinggi yang tepat.

```vhdl
-- Cuplikan pemetaan frekuensi DTMF pada generate_dtmf_signed.vhd
case tone_digit is
    when x"0" => -- Digit 0 (941 Hz, 1336 Hz)
        phase_incr_low  <= to_unsigned(219224, phase_incr_low'length);
        phase_incr_high <= to_unsigned(311220, phase_incr_high'length);
    when x"1" => -- Digit 1 (697 Hz, 1209 Hz)
        phase_incr_low  <= to_unsigned(162388, phase_incr_low'length);
        phase_incr_high <= to_unsigned(281644, phase_incr_high'length);
    -- pemetaan digit lainnya...
```

### 5.2.5. FSM Pengendali Transmisi (Symbol Timing FSM)
Penjadwalan durasi pengiriman diatur oleh FSM `FSM_DTMF_TRANSMITTER` yang bertempat di dalam [AcakCakap_Top.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/AcakCakap_Top.vhd). Saat terpicu, FSM berpindah dari status `IDLE` ke status `TRANSMIT`. Di dalam status ini, pencacah sampel `sample_counter` menghitung pulsa tanda selesai `Ldone` dari modul codec audio hingga mencapai 640 sampel (ekivalen dengan 20 ms). Setelah itu, FSM memicu segmen berikutnya secara instan guna mempertahankan kontinuitas fasa sinyal.

```vhdl
-- Cuplikan FSM pewaktuan simbol di AcakCakap_Top.vhd
when TRANSMIT =>
    dtmf_tone_enable <= '1';
    if Ldone = '1' then
        if sample_counter = SAMPLES_20MS - 1 then
            sample_counter <= 0;
            if segment_counter < to_unsigned(11, segment_counter'length) then
                segment_counter <= segment_counter + 1;
            else
                current_state <= IDLE;
            end if;
        else
            sample_counter <= sample_counter + 1;
        end if;
    end if;
```

### 5.2.6. Pembingkaian Paket Simbol (Frame Multiplexing)
Sinyal pengiriman disusun secara kombinasional menjadi satu paket bingkai transmisi yang terdiri atas 12 segmen simbol. Pencacah segmen `segment_counter` mengendalikan data simbol biner 4-bit (`tone_digit`) yang akan dikirimkan ke generator nada. Segmen ke-0, 1, dan 3 memancarkan preamble `#` (`x"F"`), segmen ke-2 memancarkan preamble `3` (`x"3"`), dan segmen ke-4 hingga 11 memetakan byte-byte kunci biner 32-bit secara kombinasional dari MSB ke LSB.

```vhdl
-- Cuplikan pembingkaian simbol di AcakCakap_Top.vhd
case to_integer(segment_counter) is
    when 0 | 1 | 3 =>
        dtmf_digit_to_send <= x"F"; -- Preamble '#'
    when 2 =>
        dtmf_digit_to_send <= x"3"; -- Preamble '3'
    when others =>
        dtmf_digit_to_send <= current_4bit_segment; -- Payload Kunci
end case;
```

### 5.2.7. Penjumlah Sinyal Grup Rendah-Tinggi (Mixer)
Sinyal amplitudo dari generator sinus grup frekuensi rendah (`data_low`) dan tinggi (`data_high`) masing-masing direpresentasikan dalam bentuk format data signed 16-bit. Penjumlahan langsung kedua grup nada tersebut berpotensi menyebabkan overflow yang akan memotong sinyal. Untuk itu, kedua sinyal diperlebar menjadi format signed 17-bit menggunakan fungsi `resize` sebelum dilakukan operasi penjumlahan aritmatika.

```vhdl
-- Cuplikan penjumlahan mixer di generate_dtmf_signed.vhd
sum <= resize(data_low, 17) + resize(data_high, 17);
```

### 5.2.8. Penyekalaan Amplitudo (Scaling & Muting)
Sinyal penjumlahan signed 17-bit dipotong kembali menjadi format signed 16-bit (`dtmf_out`) dengan cara membuang bit LSB terbawah (setara dengan membagi amplitudo dengan dua secara aritmatika). Penskalaan ini memastikan level tegangan output tidak melebihi batas dinamis codec audio. Selain itu, logika penskalaan ini dikendalikan oleh sinyal pemicu `command` yang akan memaksa keluaran bernilai nol (mute) saat pengiriman sedang tidak aktif.

```vhdl
-- Cuplikan penskalaan amplitudo di generate_dtmf_signed.vhd
dtmf_out <= sum(16) & sum(15 downto 1) when command = '1' else (others => '0');
```

---

## 5.3. Subsistem Penerima (RX)

Subsistem Penerima mendemodulasi sinyal DTMF yang diterima dan merakit kembali kunci enkripsi 32-bit.

### 5.3.1. Pipeline Korelator Preamble I/Q
Modul korelasi kuadratik [toplevel_iq.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/receiver_hdl/toplevel_iq.vhd) memproses sinyal melalui tahapan pipa paralel bertingkat fixed-point. Blok `lutsin_block` dan `lutcos_block` menyimpan representasi tabel referensi lokal format Q2.14 yang dikalikan dengan data masukan ADC `Lin` (format Q3.13) menggunakan multiplier `multv6` menghasilkan produk Q3.13. Hasil produk ini diakumulasikan sepanjang bingkai 40 sampel pada akumulator `Framingv2` menghasilkan Q8.8, kemudian dikalkulasi dayanya ($I^2 + Q^2$) oleh modul `powercalcv1` menjadi format Q12.4. Penjumlahan jendela geser 16-bingkai dilakukan oleh modul `slidingv5` menghasilkan luaran Q15.1 yang diumpankan ke modul `flaggingv2` dan `markingv1` untuk mendeteksi preamble `#` dan `3`, sebelum akhirnya pengendali `dec_control` mengaktifkan pulsa sinkronisasi bingkai.

```vhdl
-- Cuplikan instansiasi pipa korelator I/Q pada toplevel_iq.vhd
mul_sin_697 : entity work.multv6 port map(
    clk => clk, reset => reset, in_valid => in_valid,
    out_ready => r2r1, in_ready => in_ready, out_valid => v2v1,
    dataA => dataA, dataB => sine_697, dataOut => multout_sin697
);
```

### 5.3.2. DSP Goertzel Fixed-Point paralel
Demodulasi nada payload real-time dilakukan secara paralel menggunakan delapan filter independen pada modul [Goertzel.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/dtmf_detect_hdl/Goertzel.vhd) yang dikoordinasikan oleh [Goertzel_top.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/dtmf_detect_hdl/Goertzel_top.vhd). Konstanta koefisien filter $2\cos(2\pi f / F_s)$ dideklarasikan menggunakan format fixed-point Q2.14 (`sfixed(1 downto -14)`), sedangkan register internal $Q_0, Q_1, Q_2$ menggunakan format Q13.3 (`sfixed(12 downto -3)`) guna menghemat area FPGA tanpa memicu terjadinya *arithmetic overflow*. Penggunaan FSM sekuensial 12-status pada setiap sampel berhasil menghemat sumber daya perkalian perangkat keras sehingga setiap kanal filter hanya membutuhkan satu multiplier fisik yang di-share, dan hasil perhitungan dayanya dikonversi ke format Q14.2 melalui pemotongan bit LSB menggunakan fungsi `resize`.

```vhdl
-- Cuplikan FSM Goertzel COMPUTE_FILTER pada Goertzel.vhd
WHEN COMPUTE_FILTER_1 =>
    state <= COMPUTE_FILTER_2;
    mult_a <= coeff_sfixed;
    mult_b <= Q1_reg;
    sub_a <= DTMF_sampled;  
    sub_b <= Q2_reg;
```

### 5.3.3. Penentuan Indeks Tengah Simbol & Shift-Add Register
Deteksi frekuensi dominan dibatasi tepat pada sampel di tengah durasi simbol 20 ms guna meminimalkan efek interferensi antarsimbol (ISI). Waktu sampling ini disinkronkan oleh pemicu `enable` dari korelator preamble dengan formula indeks sampling sebagai berikut:
$$\text{index} = \text{sync\_lock\_index} + 320 + (N \times 640)$$
Di mana $N = 0, 1, 2, \dots, 7$ menyatakan urutan simbol payload yang dibaca. Modul pembanding [top_dtmfencode.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/dtmf_detect_hdl/top_dtmfencode.vhd) membandingkan level daya kedelapan kanal untuk mengidentifikasi simbol biner 4-bit yang dikirimkan. Setelah itu, simbol-simbol tersebut dimasukkan secara sekuensial ke dalam register geser [shift_add.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/dtmf_detect_hdl/shift_add.vhd) untuk merakit kembali kunci 32-bit yang utuh pada register `reconstructed_key_32bit`.

```vhdl
-- Cuplikan logika perakitan FSM preamble & payload di top_dtmfencode.vhd
when GOT_HASH_THREE =>
    if code_dtmf = x"F" then
        payload_shift <= (others => '0');
        payload_count <= 0;
        frame_state <= COLLECT_PAYLOAD;
    else
        frame_state <= WAIT_HASH;
    end if;
when COLLECT_PAYLOAD =>
    next_payload := payload_shift(27 downto 0) & code_dtmf;
    payload_shift <= next_payload;
```

---

## 5.4. Integrasi Top-Level (AcakCakap_Top)

Seluruh komponen subsistem dihubungkan secara struktural di dalam modul pembungkus utama [AcakCakap_Top.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/AcakCakap_Top.vhd). Modul ini menyalurkan domain detak $50\text{ MHz}$ dan clock audio $18,432\text{ MHz}$ ke seluruh sistem, serta menyearahkan sinyal reset fisik `KEY(0)` ke domain audio melalui register geser untuk meniadakan gangguan asinkron. Jalur pemicu pengiriman menggabungkan masukan tombol fisik `KEY(1)` dan perintah dari register UART melalui logika OR:
$$\text{start\_transmission} = \text{command} \lor \text{uart\_trigger}$$
Selama pemancaran nada DTMF aktif, input audio dari ADC di-mute dan DAC langsung diarahkan untuk memancarkan sinyal DTMF. Sebaliknya, ketika sistem berada dalam mode idle, saluran bypass audio diaktifkan sehingga sinyal dari mikrofon dikirimkan langsung ke speaker untuk percakapan normal. Port integrasi juga menghubungkan jabat tangan `Ldone` dan sinyal `enable` preamble ke modul demodulator Goertzel, serta mendistribusikan selektor `SW(0)` ke multiplexer display 7-segmen.

```vhdl
-- Perutean audio DAC dan muting ADC pada AcakCakap_Top.vhd
AUD_DAC_MUX : process(dtmf_tone_enable, dtmf_lout, Lin)
begin
    if dtmf_tone_enable = '1' then
        Lout <= dtmf_lout;
        Rout <= dtmf_lout;
    else
        Lout <= Lin;
        Rout <= Lin;
    end if;
end process;
```

---

## 5.5. Simulasi Testbench Top-Level

Verifikasi fungsionalitas keseluruhan sistem secara terintegrasi dilakukan melalui simulasi tingkat atas menggunakan program testbench [tb_dtmf_integration.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/tb_dtmf_integration.vhd) yang dikompilasi dan dijalankan dengan bantuan skrip ModelSim/QuestaSim [run_tb_dtmf_integration.do](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/run_tb_dtmf_integration.do). Testbench ini menggunakan strategi *loopback* terintegrasi di mana keluaran data serial audio digital dari pemancar (`AUD_DACDAT`) dihubungkan kembali secara langsung ke masukan data serial penerima (`AUD_ADCDAT`) pada entitas utama [AcakCakap_Top.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/AcakCakap_Top.vhd). Karena kedua sinyal tersebut dikonversi secara sinkron menggunakan antarmuka codec audio yang sama, strategi ini memungkinkan pengujian fungsionalitas modul pengirim (TX), sinkronisasi awal paket, deteksi spektral Goertzel, perakitan kunci penerima (RX), hingga visualisasi display tujuh segmen dilakukan secara *end-to-end* dalam satu domain simulasi terpadu.

```vhdl
-- Cuplikan interkoneksi loopback dan stimulus UART pada tb_dtmf_integration.vhd
AUD_ADCDAT <= AUD_DACDAT;

-- Pengiriman kunci uji dinamis via UART pada proses STIM_PROC
report "[TESTBENCH] Sending dynamic key: 0x3A7C9B1D via UART...";
UART_SEND_BYTE(x"3A", UART_RXD);
UART_SEND_BYTE(x"7C", UART_RXD);
UART_SEND_BYTE(x"9B", UART_RXD);
UART_SEND_BYTE(x"1D", UART_RXD);
UART_SEND_BYTE(x"0A", UART_RXD); -- Karakter LF (0x0A) sebagai pemicu
```

Prosedur pengujian dimulai dengan mengatur FSM kontrol agar siap menerima injeksi kunci enkripsi dinamis secara serial melalui masukan UART dengan menetapkan sakelar `SW(8) <= '1'`. Reset aktif-rendah kemudian diterapkan melalui sinyal `KEY(0)` selama beberapa siklus detak. Untuk merepresentasikan kondisi nyata, sistem simulasi ditangguhkan selama 20 ms guna membiarkan inisialisasi modul I2C wm8731 selesai dan Audio PLL mengunci detak master $18,432\text{ MHz}$. Setelah domain detak stabil, testbench menyimulasikan transmisi kunci dinamis 32-bit `0x3A7C9B1D` melalui UART pada laju bit 115200 bps, diikuti oleh byte *Line Feed* (`0x0A`) sebagai karakter pemicu otomatis. FSM internal top-level mendeteksi pulsa pemicu tersebut lalu secara instan memulai siklus pemancaran 12 simbol DTMF (sekuens preamble `"##3#"` diikuti payload) dengan durasi pengiriman 20 ms per simbol (total nominal 240 ms).

Berdasarkan riwayat pengujian, sistem sempat mengalami kegagalan akibat pergeseran nilai register kunci penerima yang tidak diinginkan setelah fase transmisi selesai. Modul keputusan detektor spektral Goertzel secara berkala memancarkan nilai nol (`0x0`) saat mendeteksi ketiadaan nada (jeda sunyi setelah pengiriman berakhir). Karena modul akumulator bergeser awal menerima setiap pulsa deteksi valid tanpa memedulikan status keaktifan nada, jeda sunyi tersebut diinterpretasikan sebagai digit DTMF `'0'` yang sah. Hal ini menyebabkan kunci 32-bit yang semula berhasil direkonstruksi tergeser keluar dan digantikan oleh nilai nol, sehingga kunci rekonstruksi bernilai salah sebesar `0x9B1D0000`. Permasalahan ini berhasil diatasi dengan merancang ulang pengendali perakitan kunci pada modul [top_dtmfencode.vhd](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl/dtmf_detect_hdl/top_dtmfencode.vhd) menjadi bersifat *frame-aware*. Pengendali baru hanya mengaktifkan pergeseran register saat mendeteksi pola preamble `"##3#"` (atau toleransi `"#3#"`) yang dipadukan dengan sinyal pengawal `tone_valid`, mengumpulkan tepat 8 simbol data payload kunci, lalu mengunci data rekonstruksi secara permanen hingga bingkai paket baru terdeteksi kembali.

Setelah perbaikan tersebut diterapkan, simulasi terintegrasi berhasil lolos verifikasi secara penuh dengan tingkat kesalahan bit sebesar 0% (*Zero Bit Errors*). Pada akhir simulasi (sekitar $271,9\text{ ms}$), register internal `reconstructed_key_32bit` terbukti bernilai tepat `0x3A7C9B1D`. Selain itu, testbench juga memverifikasi kesesuaian output visualisasi display tujuh segmen saat diubah melalui sakelar pemilih `SW(0)`. Ketika `SW(0) = '0'` (mode LSB), display `HEX5` s.d. `HEX0` berhasil memvisualisasikan karakter `7C9B1D`. Sebaliknya, saat `SW(0) = '1'` (mode MSB), display memvisualisasikan karakter `3A` pada `HEX5` s.d. `HEX4` dan karakter strip pada display lainnya. Keberhasilan pengujian terpadu ini terdokumentasi dengan jelas melalui visualisasi diagram gelombang ModelSim/QuestaSim yang dilampirkan pada Gambar 5.1.

![Diagram Gelombang Hasil Simulasi Integrasi Top-Level QuestaSim](file:///d:/Users/Rafi%20Ananta%20Alden/Documents/Kuliah/Semester%208/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/docs/walkthrough/waveform.png)
```
