`timescale 1ns / 1ps

module tb_top_trigger_corner;

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

    // --- Task: Mengirim Byte UART (115200 bps) ---
    localparam BIT_PERIOD = 8681; // 1.000.000.000 / 115200 ns
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            UART_RXD = 0; // Start bit
            #BIT_PERIOD;
            for (i = 0; i < 8; i = i + 1) begin
                UART_RXD = data[i];
                #BIT_PERIOD;
            end
            UART_RXD = 1; // Stop bit
            #BIT_PERIOD;
        end
    endtask

    // --- Skenario Corner-Case ---
    initial begin
        // Inisialisasi
        KEY = 4'b1111; // Active-low, 1 = tidak ditekan
        SW = 10'b0;
        UART_RXD = 1;  // Idle state UART adalah High
        AUD_ADCDAT = 0;

        // Tahan reset untuk stabilisasi
        #1000;
        KEY[0] = 0; // Tekan Reset
        #1000;
        KEY[0] = 1; // Lepas Reset
        #50_000;    // Tunggu PLL Audio / Sistem stabil
        
        $display("[%0t] ==== UJI QA: SKENARIO KEKOKOHAN TRIGGER DIMULAI ====", $time);

        // -------------------------------------------------------------
        // KASUS 1: TOMBOL TERTAHAN (STUCK BUTTON) - Dipercepat untuk Simulasi
        // -------------------------------------------------------------
        $display("[%0t] [SCENARIO 1] Tombol KEY(1) ditekan dan ditahan 500 us...", $time);
        KEY[1] = 0; 
        #500_000; // Tahan 500 us (Melebihi burst 417 us)
        $display("[%0t] [SCENARIO 1] Tombol KEY(1) dilepas.", $time);
        KEY[1] = 1; 
        
        // FSM di RTL men-trigger pada saat RELEASE (transisi 0 ke 1)
        // Kita tunggu 500 us untuk membiarkan FSM menyelesaikan burst 12-simbolnya (417 us).
        #500_000; 


        // -------------------------------------------------------------
        // KASUS 2: GLITCH MEKANIS (CONTACT BOUNCE) - Dipercepat untuk Simulasi
        // -------------------------------------------------------------
        $display("[%0t] [SCENARIO 2] Mengirimkan Noise/Glitch Mekanis pada KEY(1)...", $time);
        // Simulasi tangan menekan dengan gemetar (bouncing)
        KEY[1] = 0; #20000; 
        KEY[1] = 1; #15000; // Terlepas sebentar (menghasilkan 1 trigger palsu)
        KEY[1] = 0; #30000; 
        KEY[1] = 1; #10000; // Terlepas sebentar lagi (trigger palsu ke-2)
        KEY[1] = 0; #500_000; // Ditekan stabil 500 us (ditingkatkan dari ms untuk simulasi cepat)
        KEY[1] = 1; // Dilepas sungguhan
        // Bouncing saat pelepasan
        #10000; KEY[1] = 0;
        #15000; KEY[1] = 1;
        
        // Tunggu 500 us untuk membuktikan tidak ada double-transmission.
        #500_000;


        // -------------------------------------------------------------
        // KASUS 3: UART SPAM COMMAND - Dipercepat untuk Simulasi
        // -------------------------------------------------------------
        $display("[%0t] [SCENARIO 3] Injeksi Spam UART PC (Payload X\"53\" bertubi-tubi + Trigger 0x0A)...", $time);
        // User mengirimkan byte payload x"53" tanpa henti secara kasar
        send_uart_byte(8'h53);
        send_uart_byte(8'h53);
        send_uart_byte(8'h53);
        
        // Kirim Trigger (Line Feed 0x0A) untuk memulai burst
        $display("[%0t] [SCENARIO 3] Mengirimkan Byte Trigger 0x0A.", $time);
        send_uart_byte(8'h0A); 

        // Spam trigger 0x0A lagi dengan kecepatan tinggi SAAT TX SEDANG BERJALAN
        $display("[%0t] [SCENARIO 3] Spam Byte Trigger 0x0A saat sistem sedang sibuk (Busy/Transmit).", $time);
        #100_000; // Tunggu 100 us (di tengah-tengah transmisi burst)
        send_uart_byte(8'h0A); 
        send_uart_byte(8'h0A);
        send_uart_byte(8'h0A);

        // Tunggu hingga FSM selesai
        #500_000;

        $display("[%0t] ==== UJI QA SELESAI ====", $time);
        $stop;
    end

endmodule
