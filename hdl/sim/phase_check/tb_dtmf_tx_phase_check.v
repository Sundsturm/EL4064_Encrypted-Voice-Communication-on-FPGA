`timescale 1ns / 1ps

module tb_dtmf_tx_phase_check;

    // Parameter Modul
    localparam DATA_BITS = 16;
    localparam ADDR_BITS = 9;

    // Sinyal Testbench
    reg clk;
    reg rst;
    reg command;
    reg [3:0] tone_digit;
    wire signed [DATA_BITS-1:0] dtmf_out;

    // File descriptor untuk ekspor data
    integer fd;

    // 1. Bangkitkan Clock Utama: 50 MHz (Periode = 20 ns)
    initial clk = 0;
    always #10 clk = ~clk;

    // 2. Bangkitkan Sampling Clock Strobe: fs = 32.000 Hz
    // Periode 32 kHz = 1 / 32.000 detik = 31250 ns.
    // Setengah periode = 15625 ns.
    reg sample_clk;
    initial sample_clk = 0;
    always #15625 sample_clk = ~sample_clk;

    // Deteksi rising edge (strobe pulse tunggal per siklus utama)
    reg sample_clk_d;
    wire sample_strobe;
    always @(posedge clk) begin
        sample_clk_d <= sample_clk;
    end
    assign sample_strobe = (sample_clk & ~sample_clk_d);

    // 3. Instansiasi DUT (Device Under Test)
    generate_dtmf_signed #(
        .addr_bits(ADDR_BITS),
        .data_bits(DATA_BITS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .command(command),
        .tone_digit(tone_digit),
        .dtmf_out(dtmf_out)
    );

    // Array memori untuk menyimpan 12 sekuens DTMF
    reg [3:0] sequence [0:11];
    integer i;

    initial begin
        // --- Inisialisasi Sekuens Transmisi ---
        // Preamble: #, #, 3, # -> (F, F, 3, F)
        sequence[0]  = 4'hF; 
        sequence[1]  = 4'hF; 
        sequence[2]  = 4'h3; 
        sequence[3]  = 4'hF; 
        // Payload Data 32-bit Acak -> 8 Simbol
        sequence[4]  = 4'hA;
        sequence[5]  = 4'h1;
        sequence[6]  = 4'hB;
        sequence[7]  = 4'h2;
        sequence[8]  = 4'hC;
        sequence[9]  = 4'h3;
        sequence[10] = 4'hD;
        sequence[11] = 4'h4;

        // Reset & inisiasi
        rst = 1;
        command = 0;
        tone_digit = 4'h0;

        // Buka file log keluaran
        fd = $fopen("tx_waveform_output.txt", "w");
        if (fd == 0) begin
            $display("ERROR: Gagal membuka atau membuat file tx_waveform_output.txt!");
            $finish;
        end

        // Proses de-assert reset
        #100;
        @(posedge clk);
        rst = 0;
        #100;

        $display("Memulai Transmisi Continuous Blast DTMF...");
        
        // Mulai pancarkan!
        command = 1;
        
        // Loop injeksi ke-12 simbol, tepat 20 ms per simbol
        for (i = 0; i < 12; i = i + 1) begin
            tone_digit = sequence[i];
            $display("Waktu: %0t ns | Mengirim Simbol HEX: %h", $time, tone_digit);
            
            // Tunda eksekusi persis selama 20 ms (20.000.000 ns)
            #20000000; 
        end
        command = 0;
        
        // Tunggu sebentar sebelum mengakhiri simulasi
        #100000;
        
        $fclose(fd);
        $display("Simulasi Selesai secara deterministik. Data tertulis ke tx_waveform_output.txt");
        $finish;
    end

    // 4. Pengambilan Sampel Audio (Sampling) pada laju 32 kHz
    always @(posedge clk) begin
        if (command && !rst && sample_strobe) begin
            // Rekam nilai amplitudo ke dalam teks dengan format desimal signed
            $fwrite(fd, "%d\n", $signed(dtmf_out));
        end
    end

endmodule
