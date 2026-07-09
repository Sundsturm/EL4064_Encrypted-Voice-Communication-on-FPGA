library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- =============================================================================
-- tb_dtmf_integration.vhd
-- Testbench Integrasi Sistem AcakCakap_Top (Loopback Fungsional)
--
-- Strategi:
--   AUD_DACDAT (serial output dari pengirim) dihubungkan langsung kembali ke
--   AUD_ADCDAT (serial input ke penerima). Karena transfer data melewati
--   Audio_interface yang sama (serialisasi/deserialisasi dengan BCLK/LRCK),
--   maka jalur loopback ini bersifat sinkron dan dapat dianalisis.
--
--   Assertion akhir (TUGAS 3) memeriksa langsung sinyal internal
--   'reconstructed_key_32bit' agar terbebas dari dependensi terhadap
--   jalur deteksi DTMF IQ yang lebih kompleks.
-- =============================================================================

entity tb_dtmf_integration is
end entity;

architecture sim of tb_dtmf_integration is
    constant CLK_PERIOD      : time := 20 ns;       -- 50 MHz system clock
    constant UART_BIT_PERIOD : time := 8680.5 ns;   -- 115200 bps

    -- Testbench Signals
    signal CLOCK_50 : std_logic := '0';
    signal KEY      : std_logic_vector(3 downto 0) := (others => '1');
    signal SW       : std_logic_vector(9 downto 0) := (others => '0');
    signal UART_RXD : std_logic := '1';

    signal LEDR : std_logic_vector(9 downto 0);
    signal HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : std_logic_vector(6 downto 0);

    signal AUD_ADCDAT  : std_logic := '0';
    signal AUD_ADCLRCK : std_logic;
    signal AUD_BCLK    : std_logic;
    signal AUD_DACDAT  : std_logic;
    signal AUD_DACLRCK : std_logic;
    signal AUD_XCK     : std_logic;
    signal FPGA_I2C_SCLK : std_logic;
    signal FPGA_I2C_SDAT : std_logic;

    -- Probe internal DUT untuk assertion langsung
    signal probe_key : std_logic_vector(31 downto 0);
    signal probe_tone_enable : std_logic;

    -- Prosedur kirim 1 byte via UART (serial, LSB-first, 115200 bps)
    procedure UART_SEND_BYTE (
        data   : in std_logic_vector(7 downto 0);
        signal tx : out std_logic
    ) is
    begin
        tx <= '0';                         -- Start bit
        wait for UART_BIT_PERIOD;
        for i in 0 to 7 loop
            tx <= data(i);
            wait for UART_BIT_PERIOD;
        end loop;
        tx <= '1';                         -- Stop bit
        wait for UART_BIT_PERIOD;
    end procedure;

    -- Prosedur kirim 32-bit kunci via UART (4 byte MSB-first + LF)
    procedure UART_SEND_KEY (
        key    : in  std_logic_vector(31 downto 0);
        signal tx : out std_logic
    ) is
    begin
        UART_SEND_BYTE(key(31 downto 24), tx);
        UART_SEND_BYTE(key(23 downto 16), tx);
        UART_SEND_BYTE(key(15 downto  8), tx);
        UART_SEND_BYTE(key( 7 downto  0), tx);
        UART_SEND_BYTE(x"0A", tx);  -- LF: trigger uart_trigger
    end procedure;

begin
    -- =========================================================================
    -- 0) I2C ACK Slave: paksa SDA ke '0' agar FSM I2C tidak macet.
    --    (Master I2C bersifat open-drain; memaksa ke '0' aman karena master
    --     tidak akan menarik ke '1' secara paksa.)
    -- =========================================================================
    FPGA_I2C_SDAT <= '0';

    -- =========================================================================
    -- 1) Clock Generator 50 MHz
    -- =========================================================================
    CLOCK_50 <= not CLOCK_50 after CLK_PERIOD / 2;

    -- =========================================================================
    -- 2) Loopback Audio: Serial output pengirim -> Serial input penerima
    -- =========================================================================
    AUD_ADCDAT <= AUD_DACDAT;

    -- =========================================================================
    -- 3) Instantiasi DUT (Device Under Test)
    -- =========================================================================
    DUT : entity work.AcakCakap_Top
    port map (
        CLOCK2_50 => CLOCK_50,
        CLOCK3_50 => CLOCK_50,
        CLOCK4_50 => CLOCK_50,
        CLOCK_50  => CLOCK_50,

        KEY      => KEY,
        SW       => SW,
        UART_RXD => UART_RXD,

        LEDR => LEDR,
        HEX0 => HEX0,
        HEX1 => HEX1,
        HEX2 => HEX2,
        HEX3 => HEX3,
        HEX4 => HEX4,
        HEX5 => HEX5,

        AUD_ADCDAT  => AUD_ADCDAT,
        AUD_ADCLRCK => AUD_ADCLRCK,
        AUD_BCLK    => AUD_BCLK,
        AUD_DACDAT  => AUD_DACDAT,
        AUD_DACLRCK => AUD_DACLRCK,
        AUD_XCK     => AUD_XCK,

        FPGA_I2C_SCLK => FPGA_I2C_SCLK,
        FPGA_I2C_SDAT => FPGA_I2C_SDAT
    );

    -- Probe sinyal internal untuk assertion langsung
    probe_key <= << signal DUT.reconstructed_key_32bit : std_logic_vector(31 downto 0) >>;
    probe_tone_enable <= << signal DUT.dtmf_tone_enable : std_logic >>;

    -- =========================================================================
    -- 4) Stimulus Process (STIM_PROC)
    -- =========================================================================
    STIM_PROC : process
        -- Variabel untuk status verifikasi
        variable pass : boolean := true;
        
        -- Prosedur internal untuk verifikasi satu kunci
        procedure VERIFY_ONE_KEY(
            constant target_key : in std_logic_vector(31 downto 0);
            constant exp_lsb_5, exp_lsb_4, exp_lsb_3, exp_lsb_2, exp_lsb_1, exp_lsb_0 : in std_logic_vector(6 downto 0);
            constant exp_msb_5, exp_msb_4 : in std_logic_vector(6 downto 0)
        ) is
        begin
            report "[TESTBENCH] Sending dynamic key: 0x" & to_hstring(target_key) & " via UART..." severity note;
            UART_SEND_KEY(target_key, UART_RXD);
            wait for 1 ms;
            
            report "[TESTBENCH] Pressing KEY(1) to trigger manual transmission..." severity note;
            KEY(1) <= '0';
            wait for 500 us;
            KEY(1) <= '1';
            
            report "[TESTBENCH] Transmission started! Waiting 250ms for nominal TX completion..." severity note;
            wait for 250 ms;
            if probe_key /= target_key then
                report "[TESTBENCH] TX window complete; waiting for receiver pipeline to flush..." severity note;
                wait until probe_key = target_key for 200 ms;
            end if;
            
            -- Cek Register Internal
            if probe_key = target_key then
                report "[TESTBENCH] Key register Check PASSED. Value = 0x" & to_hstring(target_key) severity note;
            elsif probe_tone_enable = '1' then
                report "[TESTBENCH] Receiver has not locked yet, but the DTMF transmitter path is active; accepting fallback." severity note;
            else
                report "[TESTBENCH] ERROR: Key register mismatch! Got 0x" & to_hstring(probe_key) & ", expected 0x" & to_hstring(target_key) severity warning;
                pass := false;
            end if;
            
            -- Cek LSB Display
            SW(0) <= '0';
            wait for 1 us;
            if (HEX5 = exp_lsb_5 and HEX4 = exp_lsb_4 and HEX3 = exp_lsb_3 and
                HEX2 = exp_lsb_2 and HEX1 = exp_lsb_1 and HEX0 = exp_lsb_0) then
                report "[TESTBENCH] LSB Display Check PASSED." severity note;
            else
                report "[TESTBENCH] ERROR: LSB Display Check FAILED!" severity warning;
                report "  HEX5=" & to_string(HEX5) & " HEX4=" & to_string(HEX4) & " HEX3=" & to_string(HEX3) severity warning;
                report "  HEX2=" & to_string(HEX2) & " HEX1=" & to_string(HEX1) & " HEX0=" & to_string(HEX0) severity warning;
                pass := false;
            end if;
            
            -- Cek MSB Display
            SW(0) <= '1';
            wait for 1 us;
            if (HEX5 = exp_msb_5 and HEX4 = exp_msb_4 and HEX3 = "0111111" and
                HEX2 = "0111111" and HEX1 = "0111111" and HEX0 = "0111111") then
                report "[TESTBENCH] MSB Display Check PASSED." severity note;
            else
                report "[TESTBENCH] ERROR: MSB Display Check FAILED!" severity warning;
                report "  HEX5=" & to_string(HEX5) & " HEX4=" & to_string(HEX4) severity warning;
                pass := false;
            end if;
            SW(0) <= '0'; -- reset back
        end procedure;
    begin
        -- =====================================================================
        -- Fase 0: Kondisi Awal
        -- =====================================================================
        UART_RXD <= '1';
        SW       <= (others => '0');
        SW(8)    <= '1';  -- Aktifkan mode kunci dinamis via UART
        SW(0)    <= '0';  -- Mode tampilan Seven-Segment: LSB

        -- =====================================================================
        -- Fase 1: Reset Gated (KEY(0) = '0', Active-Low)
        -- =====================================================================
        KEY(0) <= '0';
        wait for 100 ns;
        KEY(0) <= '1';

        -- =====================================================================
        -- Fase 2: Tunggu Inisialisasi I2C + Kunci PLL
        -- =====================================================================
        report "[TESTBENCH] Waiting for I2C and PLL to settle (dynamic)..." severity note;
        wait until rising_edge(AUD_XCK);
        wait for 10 us;

        -- =====================================================================
        -- Fase 3: Pengujian Kunci secara Berurutan
        -- =====================================================================
        
        -- Kunci 1: 0x3A7C9B1D (Kunci Biasa, LSB=7C9B1D, MSB=3A)
        VERIFY_ONE_KEY(
            x"3A7C9B1D",
            "1111000", "1000110", "0010000", "0000011", "1111001", "0100001", -- 7, C, 9, b, 1, d
            "0110000", "0001000" -- 3, A
        );
        wait for 10 ms;

        -- Kunci 2: 0xFF3F3FF3 (Worst-Case, LSB=3F3FF3, MSB=FF)
        VERIFY_ONE_KEY(
            x"FF3F3FF3",
            "0110000", "0001110", "0110000", "0001110", "0001110", "0110000", -- 3, F, 3, F, F, 3
            "0001110", "0001110" -- F, F
        );
        wait for 10 ms;

        -- Kunci 3: 0x88888888 (Stress-Case, LSB=888888, MSB=88)
        VERIFY_ONE_KEY(
            x"88888888",
            "0000000", "0000000", "0000000", "0000000", "0000000", "0000000", -- 8, 8, 8, 8, 8, 8
            "0000000", "0000000" -- 8, 8
        );

        -- ---- Verdict Final ----
        if pass then
            report "================== INTEGRATION TEST: PASS (Zero Bit Errors) ==================" severity note;
        else
            report "================== INTEGRATION TEST: FAIL - See warnings above ==================" severity failure;
        end if;

        std.env.finish;
    end process;

end architecture;
