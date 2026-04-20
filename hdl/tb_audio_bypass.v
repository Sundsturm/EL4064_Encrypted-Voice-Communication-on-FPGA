///////////////////////////////////////////////////////////////////////////////
// tb_audio_bypass.v
//
// Testbench: Golden Test Vector — Audio_interface Receive Path
//
// Tujuan  : Isolasi korupsi data pada jalur Audio_interface.
//           File audio_test.txt (hex 16-bit, satu nilai per baris) dimuat ke
//           audio_memory, lalu di-serialize sebagai sinyal I2S pada port
//           AUD_ADCDAT. Output Lin/Rin direkam ke audio_output.txt untuk
//           dibandingkan secara off-line.
//
// Compile order (ModelSim):
//   1. vlib work
//   2. vmap work work
//   3. vcom -93 -work audiopll ../quartus/AudioPLL_sim/AudioPLL.vho
//   4. vcom -93 -work work    hdl/i2c.vhd
//   5. vcom -93 -work work    hdl/Audio_interface.vhd
//   6. vlog -work work        hdl/tb_audio_bypass.v
//   7. vsim -t 1ns work.tb_audio_bypass
//
// Catatan:
//   - I2C_SDAT diberi weak pull-down agar slave (simulasi) selalu ACK.
//     Ini cukup untuk melewati inisialisasi WM8731 tanpa stub terpisah.
//   - Inisialisasi I2C membutuhkan ~800 ribu siklus sistem (±16 ms sim).
//     Watchdog diset 60 ms; naikkan jika perlu.
//   - audio_memory diasumsikan interleaved: [0]=L[0], [1]=R[0], [2]=L[1], ...
//     Sesuaikan jika format berbeda.
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module tb_audio_bypass;

    // -------------------------------------------------------------------------
    // Parameter
    // -------------------------------------------------------------------------
    parameter CLK_PERIOD  = 20;      // 50 MHz (ns)
    parameter MEM_DEPTH   = 400;     // Kapasitas audio_memory (sample) — kecilkan untuk simulasi
    parameter SAMPLE_RATE = 32;      // Harus sama dengan generic Audio_interface

    // -------------------------------------------------------------------------
    // Memori uji
    // -------------------------------------------------------------------------
    reg [15:0] audio_memory [0:MEM_DEPTH-1];
    integer    num_samples;           // Jumlah sample valid yang dimuat

    // -------------------------------------------------------------------------
    // Sinyal DUT
    // -------------------------------------------------------------------------
    reg        clk;
    reg        rst;

    // Audio clocks (dihasilkan oleh DUT ← AudioPLL)
    wire       AUD_XCK;
    wire       AUD_BCLK;
    wire       AUD_DACLRCK;
    wire       AUD_ADCLRCK;

    // I2C
    wire       I2C_SCLK;
    // I2C_SDAT: open-drain bus modelled with wand + explicit '0' driver.
    // wand (wired-AND) resolves using logic (not strength), so it works reliably
    // across the VHDL/Verilog language boundary in Questa:
    //   - Testbench drives '0' always  → wand resolved = 0
    //   - DUT VHDL drives '0' (transmit bit) → wand 0 AND 0 = 0  ✓
    //   - DUT VHDL drives 'Z' (Hi-Z, await ACK) → only testbench '0' active → 0 ✓
    wand       I2C_SDAT;
    assign     I2C_SDAT = 1'b0;   // Slave WM8731 stub: always ACK

    // Audio serial I/O
    reg        AUD_ADCDAT;   // Testbench → DUT  (serial ADC data)
    wire       AUD_DACDAT;   // DUT → Testbench  (serial DAC data, tidak diuji)

    // Parallel audio data
    wire signed [15:0] Lin, Rin;    // Output DUT (sample terdeserialize)
    reg  signed [15:0] Lout, Rout;  // Input DUT  (bypass: set = 0 untuk Rx test)
    wire               Ldone, Rdone;

    // Flag untuk sinkronisasi antar blok initial
    reg stimulus_done;

    // -------------------------------------------------------------------------
    // Instansiasi DUT  (VHDL entity, dikompilasi ke library 'work')
    // -------------------------------------------------------------------------
    Audio_interface #(
        .SAMPLE_RATE (SAMPLE_RATE)
    ) dut (
        .clk         (clk),
        .rst         (rst),
        .AUD_XCK     (AUD_XCK),
        .I2C_SCLK    (I2C_SCLK),
        .I2C_SDAT    (I2C_SDAT),
        .AUD_BCLK    (AUD_BCLK),
        .AUD_DACLRCK (AUD_DACLRCK),
        .AUD_ADCLRCK (AUD_ADCLRCK),
        .AUD_ADCDAT  (AUD_ADCDAT),
        .AUD_DACDAT  (AUD_DACDAT),
        .Lin         (Lin),
        .Rin         (Rin),
        .Lout        (Lout),
        .Rout        (Rout),
        .Ldone       (Ldone),
        .Rdone       (Rdone)
    );

    // -------------------------------------------------------------------------
    // Clock 50 MHz
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always  #(CLK_PERIOD / 2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Reset dan inisialisasi nilai awal
    // -------------------------------------------------------------------------
    initial begin
        rst           = 1'b1;
        AUD_ADCDAT    = 1'b0;
        Lout          = 16'sd0;
        Rout          = 16'sd0;
        stimulus_done = 1'b0;
        repeat (10) @(posedge clk);
        rst = 1'b0;
        $display("[%0t ns] Reset dilepas.", $time);
    end

    // -------------------------------------------------------------------------
    // Muat test vector dari file
    // -------------------------------------------------------------------------
    initial begin : load_mem
        integer i;
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            audio_memory[i] = 16'h0000;

        $readmemh("audio_test.txt", audio_memory);

        // Hitung jumlah sample: anggap semua MEM_DEPTH terisi penuh.
        // Ganti dengan nilai tetap jika ukuran file diketahui, mis. 2048.
        num_samples = MEM_DEPTH;

        $display("[%0t ns] %0d sample dimuat dari audio_test.txt.", $time, num_samples);
    end

    // -------------------------------------------------------------------------
    // Blok stimulus I2S
    //
    // Protokol:
    //   • Data diubah pada negedge AUD_BCLK (falling edge)
    //   • DUT men-sample pada posedge AUD_BCLK (rising edge)
    //   • LRCK = '1' → kanal Kiri  (16 bit, MSB pertama)
    //   • LRCK = '0' → kanal Kanan (16 bit, MSB pertama)
    //   • Satu siklus LRCK = 32 siklus BCLK
    // -------------------------------------------------------------------------
    integer stim_idx;
    integer bit_idx;

    initial begin : stimulus
        integer timeout_cnt;
        integer b;

        stim_idx = 0;
        bit_idx  = 15;
        AUD_ADCDAT = 1'b0;

        // -- Tunggu BCLK mulai (I2C init + PLL lock) --
        // AUD_BCLK dimulai dari '0' (bukan X/Z), jadi tunggu posedge pertama
        // sebagai tanda PLL sudah aktif dan BCLK sudah benar-benar toggle.
        timeout_cnt = 0;
        while (AUD_BCLK !== 1'b1) begin
            @(posedge clk);
            timeout_cnt = timeout_cnt + 1;
            if (timeout_cnt > 3_000_000) begin
                $display("[%0t ns] TIMEOUT: BCLK tidak pernah aktif. Periksa I2C/PLL.", $time);
                $finish;
            end
        end

        // Sinkronisasi ke awal kanal Kiri: tunggu rising edge ADCLRCK (LRCK='1')
        @(posedge AUD_ADCLRCK);

        $display("[%0t ns] BCLK aktif, stimulus I2S dimulai.", $time);

        // -- Loop utama: kirim pasangan L/R per siklus LRCK --
        while (stim_idx < num_samples - 1) begin

            // === Kanal Kiri: 16 bit ===
            for (b = 15; b >= 0; b = b - 1) begin
                @(negedge AUD_BCLK);
                AUD_ADCDAT = audio_memory[stim_idx][b];
            end
            stim_idx = stim_idx + 1;

            // === Kanal Kanan: 16 bit ===
            for (b = 15; b >= 0; b = b - 1) begin
                @(negedge AUD_BCLK);
                AUD_ADCDAT = audio_memory[stim_idx][b];
            end
            stim_idx = stim_idx + 1;
        end

        // Bersihkan jalur setelah selesai
        @(negedge AUD_BCLK);
        AUD_ADCDAT    = 1'b0;
        stimulus_done = 1'b1;
        $display("[%0t ns] Stimulus selesai: %0d sample dikirim.", $time, stim_idx);
    end

    // -------------------------------------------------------------------------
    // Blok capture output
    //
    // Menunggu setiap pulsa Ldone/Rdone, merekam Lin/Rin ke file dan
    // membandingkan dengan nilai yang dikirim (pengujian bypass).
    //
    // PERHATIAN LATENSI: Ada latensi ±1 siklus LRCK (32 bit) antara bit
    // yang dikirim dan sample yang muncul di Lin/Rin. Offset CAP_LATENCY
    // dikompensasikan di bawah; sesuaikan jika hasil tidak pas.
    // -------------------------------------------------------------------------
    parameter CAP_LATENCY = 1;  // Kompensasi latensi dalam satuan pasangan L/R

    integer out_fp;
    integer mismatch_l, mismatch_r;
    integer cap_pair;
    integer cmp_idx;

    initial begin : capture
        mismatch_l = 0;
        mismatch_r = 0;
        cap_pair   = 0;

        // Buka file output
        out_fp = $fopen("audio_output.txt", "w");
        if (out_fp == 0) begin
            $display("[%0t ns] ERROR: Tidak bisa membuka audio_output.txt.", $time);
            $finish;
        end
        $fdisplay(out_fp, "// Audio_interface output — format: satu nilai hex 16-bit per baris");
        $fdisplay(out_fp, "// Urutan: L[0], R[0], L[1], R[1], ...");

        // Tunggu stimulus mulai bekerja
        @(posedge Ldone);

        // Loop tangkap seumur simulasi
        forever begin
            // --- Kanal Kiri ---
            @(posedge Ldone);
            $fdisplay(out_fp, "%04h", Lin);

            cmp_idx = (cap_pair + CAP_LATENCY) * 2;
            if (cmp_idx < num_samples) begin
                if (Lin !== $signed(audio_memory[cmp_idx])) begin
                    $display("[%0t ns] MISMATCH L[%0d]: kirim=%04h terima=%04h",
                             $time, cap_pair, audio_memory[cmp_idx], Lin);
                    mismatch_l = mismatch_l + 1;
                end
            end

            // --- Kanal Kanan ---
            @(posedge Rdone);
            $fdisplay(out_fp, "%04h", Rin);

            cmp_idx = (cap_pair + CAP_LATENCY) * 2 + 1;
            if (cmp_idx < num_samples) begin
                if (Rin !== $signed(audio_memory[cmp_idx])) begin
                    $display("[%0t ns] MISMATCH R[%0d]: kirim=%04h terima=%04h",
                             $time, cap_pair, audio_memory[cmp_idx], Rin);
                    mismatch_r = mismatch_r + 1;
                end
            end

            cap_pair = cap_pair + 1;

            // Selesai jika sudah melampaui jumlah pasangan yang dikirim
            if (cap_pair >= (num_samples / 2) - CAP_LATENCY) begin
                $fclose(out_fp);
                $display("==================================================");
                $display("[%0t ns] Capture selesai.", $time);
                $display("  Pasangan L/R yang direkam : %0d", cap_pair);
                $display("  Mismatch kanal Kiri        : %0d", mismatch_l);
                $display("  Mismatch kanal Kanan       : %0d", mismatch_r);
                if (mismatch_l == 0 && mismatch_r == 0)
                    $display("  HASIL: PASS — tidak ada korupsi data di Audio_interface.");
                else
                    $display("  HASIL: FAIL — terdeteksi korupsi data!");
                $display("==================================================");
                $finish;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Watchdog (40 ms sim time)  — cukup untuk I2C init ~16ms + 200 sample pair ~6ms
    // -------------------------------------------------------------------------
    initial begin : watchdog
        #(40_000_000);
        $display("[%0t ns] WATCHDOG: Simulasi melebihi batas waktu 60 ms.", $time);
        if (out_fp != 0) $fclose(out_fp);
        $finish;
    end

endmodule
