library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_dtmf_integration is
end entity;

architecture sim of tb_dtmf_integration is
    constant CLK_PERIOD : time := 20 ns; -- 50 MHz
    constant UART_BIT_PERIOD : time := 8680.5 ns; -- 115200 bps

    signal CLOCK_50 : std_logic := '0';
    signal KEY : std_logic_vector(3 downto 0) := (others => '1');
    signal SW : std_logic_vector(9 downto 0) := (others => '0');
    signal UART_RXD : std_logic := '1';
    
    signal LEDR : std_logic_vector(9 downto 0);
    signal HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : std_logic_vector(6 downto 0);
    
    signal AUD_ADCDAT : std_logic := '0';
    signal AUD_ADCLRCK : std_logic;
    signal AUD_BCLK : std_logic;
    signal AUD_DACDAT : std_logic;
    signal AUD_DACLRCK : std_logic;
    signal AUD_XCK : std_logic;
    signal FPGA_I2C_SCLK : std_logic;
    signal FPGA_I2C_SDAT : std_logic := 'H'; -- Pull-up

    procedure UART_SEND_BYTE (
        data : in std_logic_vector(7 downto 0);
        signal tx : out std_logic
    ) is
    begin
        -- Start bit
        tx <= '0';
        wait for UART_BIT_PERIOD;
        -- Data bits (LSB first)
        for i in 0 to 7 loop
            tx <= data(i);
            wait for UART_BIT_PERIOD;
        end loop;
        -- Stop bit
        tx <= '1';
        wait for UART_BIT_PERIOD;
    end procedure;

begin
    -- 0) Dummy I2C Slave to generate ACK
    -- Karena modul master I2C bersifat open-drain (hanya menarik ke '0' atau lepas ke 'Z'),
    -- dan ia hanya peduli membaca bit ACK (harus '0'), kita dapat secara aman
    -- memaksa sinyal SDA ke '0' di testbench agar selalu terdeteksi sebagai ACK ("000").
    -- Hal ini mencegah state-machine I2C macet dalam infinite loop.
    FPGA_I2C_SDAT <= '0';

    -- 1) Clock generator
    CLOCK_50 <= not CLOCK_50 after CLK_PERIOD / 2;

    -- 2) Audio loopback: sender output -> receiver input
    AUD_ADCDAT <= AUD_DACDAT;

    -- 3) Instantiate Top-Level Design
    DUT : entity work.AcakCakap_Top
    port map (
        CLOCK2_50 => CLOCK_50,
        CLOCK3_50 => CLOCK_50,
        CLOCK4_50 => CLOCK_50,
        CLOCK_50  => CLOCK_50,
        
        KEY => KEY,
        SW  => SW,
        UART_RXD => UART_RXD,
        
        LEDR => LEDR,
        HEX0 => HEX0,
        HEX1 => HEX1,
        HEX2 => HEX2,
        HEX3 => HEX3,
        HEX4 => HEX4,
        HEX5 => HEX5,
        
        AUD_ADCDAT => AUD_ADCDAT,
        AUD_ADCLRCK => AUD_ADCLRCK,
        AUD_BCLK => AUD_BCLK,
        AUD_DACDAT => AUD_DACDAT,
        AUD_DACLRCK => AUD_DACLRCK,
        AUD_XCK => AUD_XCK,
        
        FPGA_I2C_SCLK => FPGA_I2C_SCLK,
        FPGA_I2C_SDAT => FPGA_I2C_SDAT
    );

    -- 4) Stimulus Process
    STIM_PROC : process
    begin
        -- Initial State
        UART_RXD <= '1';
        SW <= (others => '0');
        SW(8) <= '1'; -- Aktifkan injeksi kunci dinamis (UART)
        SW(0) <= '0'; -- Mode tampilan Seven-Segment (24-bit LSB)
        
        -- Reset Aktif Low (Tahan selama 100 ns)
        KEY(0) <= '0';
        wait for 100 ns;
        KEY(0) <= '1';
        
        -- Berikan waktu tunggu sekitar 20 milidetik untuk memastikan:
        -- 1. I2C selesai melakukan inisialisasi Codec
        -- 2. PLL mengunci dan AUD_XCK mulai stabil
        report "[TESTBENCH] Waiting for I2C and PLL to settle (20ms)..." severity note;
        wait for 20 ms;
        
        -- Kirim 4 Byte Key (0x3A, 0x7C, 0x9B, 0x1D) secara berurutan
        report "[TESTBENCH] Sending dynamic key: 0x3A7C9B1D via UART..." severity note;
        UART_SEND_BYTE(x"3A", UART_RXD);
        UART_SEND_BYTE(x"7C", UART_RXD);
        UART_SEND_BYTE(x"9B", UART_RXD);
        UART_SEND_BYTE(x"1D", UART_RXD);
        -- Kirim karakter Line Feed (0x0A) untuk memberikan trigger via UART
        -- sekaligus sebagai newline protocol.
        -- Catatan: UART_TRIGGER akan secara otomatis men-trigger FSM TRANSMIT.
        UART_SEND_BYTE(x"0A", UART_RXD);
        
        -- Tunggu sekitar 1 ms setelah UART selesai
        wait for 1 ms;
        
        -- Pemicu Manual menggunakan KEY(1) (Opsional, karena 0x0A sudah memicu)
        -- Jika FSM transmitter didesain untuk merespon trigger ganda, mari kita uji KEY(1).
        -- FSM transmisi butuh pulse '0' pada KEY(1)
        report "[TESTBENCH] Pressing KEY(1) to trigger manual transmission..." severity note;
        KEY(1) <= '0';
        wait for 500 us;
        KEY(1) <= '1';
        
        report "[TESTBENCH] Transmission started! Waiting 250ms for completion..." severity note;
        
        -- Tunggu seluruh durasi 12 simbol DTMF
        -- 12 simbol x 20 ms tone + (mungkin) silence. (Sekitar 240 ms total).
        wait for 250 ms;
        
        -- =========================================================
        -- TUGAS 3: Macro Assertion Penutup
        -- =========================================================
        report "[TESTBENCH] Checking visualization for LSB (SW(0) = '0')..." severity note;
        SW(0) <= '0';
        wait for 1 us; -- Tunggu propagasi kombinatorial MUX
        
        if (HEX5 = "1111000" and -- 7
            HEX4 = "1000110" and -- C
            HEX3 = "0010000" and -- 9
            HEX2 = "0000011" and -- B
            HEX1 = "1111001" and -- 1
            HEX0 = "0100001") then -- D
            report "[TESTBENCH] LSB Check PASSED." severity note;
        else
            report "FAIL: LSB visualization mismatch!" severity failure;
            std.env.finish;
        end if;
        
        report "[TESTBENCH] Checking visualization for MSB (SW(0) = '1')..." severity note;
        SW(0) <= '1';
        wait for 1 us; -- Tunggu propagasi kombinatorial MUX
        
        if (HEX5 = "0110000" and -- 3
            HEX4 = "0001000" and -- A
            HEX3 = "0111111" and -- -
            HEX2 = "0111111" and -- -
            HEX1 = "0111111" and -- -
            HEX0 = "0111111") then -- -
            report "[TESTBENCH] MSB Check PASSED." severity note;
        else
            report "FAIL: MSB visualization mismatch!" severity failure;
            std.env.finish;
        end if;
        
        report "================== INTEGRATION TEST: PASS (Zero Bit Errors) ==================" severity note;
        
        std.env.finish;
    end process;

end architecture;
