`timescale 1ns / 1ps

module tb_bus_driver_sevseg_check;

    // --- Sinyal Input Top Level ---
    reg CLOCK2_50, CLOCK3_50, CLOCK4_50, CLOCK_50;
    reg [3:0] KEY;
    reg [9:0] SW;
    reg UART_RXD;
    reg AUD_ADCDAT;
    wire AUD_ADCLRCK;
    wire AUD_BCLK;
    wire AUD_DACLRCK;
    wire FPGA_I2C_SDAT;

    // --- Sinyal Output Top Level ---
    wire [9:0] LEDR;
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    wire AUD_DACDAT;
    wire AUD_XCK;
    wire FPGA_I2C_SCLK;

    // --- Instansiasi Top Level Wrapper ---
    AcakCakap_Top dut (
        .CLOCK2_50(CLOCK2_50),
        .CLOCK3_50(CLOCK3_50),
        .CLOCK4_50(CLOCK4_50),
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .SW(SW),
        .UART_RXD(UART_RXD),
        .LEDR(LEDR),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .AUD_ADCDAT(AUD_ADCDAT),
        .AUD_ADCLRCK(AUD_ADCLRCK),
        .AUD_BCLK(AUD_BCLK),
        .AUD_DACDAT(AUD_DACDAT),
        .AUD_DACLRCK(AUD_DACLRCK),
        .AUD_XCK(AUD_XCK),
        .FPGA_I2C_SCLK(FPGA_I2C_SCLK),
        .FPGA_I2C_SDAT(FPGA_I2C_SDAT)
    );

    // --- Generator Clock 50 MHz ---
    initial begin
        CLOCK_50 = 0; CLOCK2_50 = 0; CLOCK3_50 = 0; CLOCK4_50 = 0;
        forever #10 CLOCK_50 = ~CLOCK_50; // Periode 20ns
    end

    // Variabel untuk menghitung error
    integer error_count = 0;

    // --- Skenario Uji Bus / Multiplexer Visualisasi ---
    initial begin
        // Inisialisasi Input
        KEY = 4'b1111; 
        SW = 10'b0;
        UART_RXD = 1;  
        AUD_ADCDAT = 0;

        // Reset Sistem
        #1000;
        KEY[0] = 0;
        #1000;
        KEY[0] = 1;
        #1000;

        $display("===============================================================");
        $display("[%0t] MEMULAI UJI QA: MULTIPLEXER DISPLAY 7-SEGMENT (ENDIANNESS)", $time);
        $display("===============================================================");

        // 1. Memaksa (Force) register internal dengan kunci statis 0x3A7C9B1D
        $display("[%0t] INJEKSI: Memaksa sinyal internal 'reconstructed_key_32bit' menjadi 0x3A7C9B1D", $time);
        force dut.reconstructed_key_32bit = 32'h3A7C9B1D;
        #1000;

        // -------------------------------------------------------------
        // KASUS 1: LSB Mode (SW[0] = '0')
        // Harapan: HEX5..0 = 7, C, 9, B, 1, D
        // Encoding Active-Low: 
        // 7 = 0x78, C = 0x46, 9 = 0x10, B = 0x03, 1 = 0x79, D = 0x21
        // -------------------------------------------------------------
        $display("\n[%0t] [SCENARIO 1] Menguji LSB Mode (SW[0] = 0). Menunggu 10 us...", $time);
        SW[0] = 0;
        #10_000; // 10 us (dipercepat untuk simulasi cepat)

        $display("[%0t] [SCENARIO 1] Memeriksa Output Fisik HEX...", $time);
        if (HEX5 === 7'h78 && HEX4 === 7'h46 && HEX3 === 7'h10 && 
            HEX2 === 7'h03 && HEX1 === 7'h79 && HEX0 === 7'h21) begin
            $display(" -> [PASS] HEX5..HEX0 berhasil menampilkan '7C9B1D'");
        end else begin
            $error(" -> [FAIL] LSB Mode salah pemetaan!");
            $display("    Expected: HEX5=78, HEX4=46, HEX3=10, HEX2=03, HEX1=79, HEX0=21");
            $display("    Got     : HEX5=%h, HEX4=%h, HEX3=%h, HEX2=%h, HEX1=%h, HEX0=%h", 
                     HEX5, HEX4, HEX3, HEX2, HEX1, HEX0);
            error_count = error_count + 1;
        end

        // -------------------------------------------------------------
        // KASUS 2: MSB Mode (SW[0] = '1')
        // Harapan: HEX5..4 = 3, A. HEX3..0 = -, -, -, -
        // Encoding Active-Low: 
        // 3 = 0x30, A = 0x08, '-' = 0x3F
        // -------------------------------------------------------------
        $display("\n[%0t] [SCENARIO 2] Menguji MSB Mode (SW[0] = 1). Menunggu 10 us...", $time);
        SW[0] = 1;
        #10_000; // 10 us (dipercepat untuk simulasi cepat)

        $display("[%0t] [SCENARIO 2] Memeriksa Output Fisik HEX...", $time);
        if (HEX5 === 7'h30 && HEX4 === 7'h08 && HEX3 === 7'h3F && 
            HEX2 === 7'h3F && HEX1 === 7'h3F && HEX0 === 7'h3F) begin
            $display(" -> [PASS] HEX5..HEX0 berhasil menampilkan '3A----'");
        end else begin
            $error(" -> [FAIL] MSB Mode salah pemetaan!");
            $display("    Expected: HEX5=30, HEX4=08, HEX3=3F, HEX2=3F, HEX1=3F, HEX0=3F");
            $display("    Got     : HEX5=%h, HEX4=%h, HEX3=%h, HEX2=%h, HEX1=%h, HEX0=%h", 
                     HEX5, HEX4, HEX3, HEX2, HEX1, HEX0);
            error_count = error_count + 1;
        end

        // -------------------------------------------------------------
        // KESIMPULAN
        // -------------------------------------------------------------
        $display("\n===============================================================");
        if (error_count == 0) begin
            $display("[%0t] STATUS QA: LULUS (ALL PASSED) - Pemetaan bus data dan bit-slicing sudah sempurna dan selaras (endian-correct).", $time);
        end else begin
            $display("[%0t] STATUS QA: GAGAL (%0d Errors) - Silakan periksa kembali logika dekoder di AcakCakap_Top.vhd", $time, error_count);
        end
        $display("===============================================================\n");
        
        $stop;
    end

endmodule
