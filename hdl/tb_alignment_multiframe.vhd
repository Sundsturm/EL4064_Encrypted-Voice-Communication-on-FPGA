library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- =============================================================================
-- tb_alignment_multiframe.vhd  (v2 - ModelSim ASE compatible)
-- Testbench verifikasi Goertzel Symbol Boundary Alignment
--
-- Perubahan dari v1: Hapus VHDL-2008 external names (<< signal >>)
-- karena ModelSim ASE (Intel edition) tidak mendukung fitur tersebut.
--
-- Strategi verifikasi: Pantau output HEX5..HEX0 untuk mendeteksi
-- apakah decoded key berubah antar frame (tidak stuck).
--
-- Kunci uji:
--   Frame 1 → 0xAABBCCDD  (24-bit LSB display: BBCCDD)
--   Frame 2 → 0x11223344  (24-bit LSB display: 223344)
--   Frame 3 → 0xDEADBEEF  (24-bit LSB display: ADBEEF)
-- =============================================================================

entity tb_alignment_multiframe is
end entity;

architecture sim of tb_alignment_multiframe is
    constant CLK_PERIOD      : time := 20 ns;     -- 50 MHz
    constant UART_BIT_PERIOD : time := 8680.5 ns; -- 115200 bps

    -- DUT ports
    signal CLOCK_50  : std_logic := '0';
    signal KEY       : std_logic_vector(3 downto 0) := (others => '1');
    signal SW        : std_logic_vector(9 downto 0) := (others => '0');
    signal UART_RXD  : std_logic := '1';
    signal LEDR      : std_logic_vector(9 downto 0);
    signal HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : std_logic_vector(6 downto 0);
    signal AUD_ADCDAT  : std_logic := '0';
    signal AUD_ADCLRCK : std_logic;
    signal AUD_BCLK    : std_logic;
    signal AUD_DACDAT  : std_logic;
    signal AUD_DACLRCK : std_logic;
    signal AUD_XCK     : std_logic;
    signal FPGA_I2C_SCLK : std_logic;
    signal FPGA_I2C_SDAT : std_logic;

    -- Snapshot HEX5 untuk deteksi perubahan frame
    signal hex5_prev : std_logic_vector(6 downto 0) := (others => '1');

    -- Durasi 1 frame DTMF: 12 simbol x 20ms = 240ms + 20ms margin
    constant FRAME_DURATION : time := 260 ms;
    -- Toleransi tambahan untuk pipeline receiver
    constant RX_TIMEOUT     : time := 200 ms;

    -- Expected HEX pattern untuk setiap frame (24-bit LSB, SW(0)='0')
    -- Format: hex_to_sevseg (active-low, 7-bit)
    -- 0xAABBCCDD → LSB 24-bit = BBCCDD
    --   HEX5='B'=0000011, HEX4='B', HEX3='C'=1000110, HEX2='C', HEX1='D'=0100001, HEX0='D'
    -- 0x11223344 → 223344
    --   HEX5='2'=0100100, HEX4='2', HEX3='3'=0110000, HEX2='3', HEX1='4'=0011001, HEX0='4'
    -- 0xDEADBEEF → ADBEEF
    --   HEX5='A'=0001000, HEX4='D'=0100001, HEX3='B'=0000011, HEX2='E'=0000110, HEX1='E', HEX0='F'=0001110

    type hex_display_t is record
        h5, h4, h3, h2, h1, h0 : std_logic_vector(6 downto 0);
    end record;

    -- Frame 1: key=0x3A7C9B1D, LSB24=7C9B1D
    constant EXPECT_FRAME1 : hex_display_t := (
        h5 => "1111000", h4 => "1000110",  -- 7, C
        h3 => "0010000", h2 => "0000011",  -- 9, b
        h1 => "1111001", h0 => "0100001"   -- 1, d
    );
    -- Frame 1 MSB: key=0x3A7C9B1D, MSB8=3A
    constant EXPECT_MSB_FRAME1 : hex_display_t := (
        h5 => "0110000", h4 => "0001000",  -- 3, A
        h3 => "0111111", h2 => "0111111",  -- -, -
        h1 => "0111111", h0 => "0111111"   -- -, -
    );

    -- Frame 2: key=0xFF3F3FF3, LSB24=3F3FF3 (worst-case)
    constant EXPECT_FRAME2 : hex_display_t := (
        h5 => "0110000", h4 => "0001110",  -- 3, F
        h3 => "0110000", h2 => "0001110",  -- 3, F
        h1 => "0001110", h0 => "0110000"   -- F, 3
    );
    -- Frame 2 MSB: key=0xFF3F3FF3, MSB8=FF
    constant EXPECT_MSB_FRAME2 : hex_display_t := (
        h5 => "0001110", h4 => "0001110",  -- F, F
        h3 => "0111111", h2 => "0111111",  -- -, -
        h1 => "0111111", h0 => "0111111"   -- -, -
    );

    -- Frame 3: key=0x88888888, LSB24=888888 (stress-case)
    constant EXPECT_FRAME3 : hex_display_t := (
        h5 => "0000000", h4 => "0000000",  -- 8, 8
        h3 => "0000000", h2 => "0000000",  -- 8, 8
        h1 => "0000000", h0 => "0000000"   -- 8, 8
    );
    -- Frame 3 MSB: key=0x88888888, MSB8=88
    constant EXPECT_MSB_FRAME3 : hex_display_t := (
        h5 => "0000000", h4 => "0000000",  -- 8, 8
        h3 => "0111111", h2 => "0111111",  -- -, -
        h1 => "0111111", h0 => "0111111"   -- -, -
    );

    -- Prosedur kirim 1 byte via UART (LSB-first, 115200 bps)
    procedure UART_SEND_BYTE (
        data   : in  std_logic_vector(7 downto 0);
        signal tx : out std_logic
    ) is
    begin
        tx <= '0'; wait for UART_BIT_PERIOD;
        for i in 0 to 7 loop
            tx <= data(i); wait for UART_BIT_PERIOD;
        end loop;
        tx <= '1'; wait for UART_BIT_PERIOD;
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

    -- Prosedur cek HEX display
    procedure CHECK_HEX (
        frame_num : in integer;
        expected  : in hex_display_t;
        h5, h4, h3, h2, h1, h0 : in std_logic_vector(6 downto 0);
        variable pass : inout boolean
    ) is
    begin
        if (h5 = expected.h5 and h4 = expected.h4 and
            h3 = expected.h3 and h2 = expected.h2 and
            h1 = expected.h1 and h0 = expected.h0) then
            report "[TB] Frame " & integer'image(frame_num) &
                   ": HEX Check PASSED" severity note;
        else
            report "[TB] Frame " & integer'image(frame_num) &
                   ": HEX Check FAILED" & LF &
                   "  Got:      H5=" & to_string(h5) & " H4=" & to_string(h4) &
                   " H3=" & to_string(h3) & " H2=" & to_string(h2) &
                   " H1=" & to_string(h1) & " H0=" & to_string(h0) & LF &
                   "  Expected: H5=" & to_string(expected.h5) &
                   " H4=" & to_string(expected.h4) &
                   " H3=" & to_string(expected.h3) &
                   " H2=" & to_string(expected.h2) &
                   " H1=" & to_string(expected.h1) &
                   " H0=" & to_string(expected.h0)
                   severity warning;
            pass := false;
        end if;
    end procedure;

begin
    -- =========================================================================
    -- I2C ACK Slave
    -- =========================================================================
    FPGA_I2C_SDAT <= '0';

    -- =========================================================================
    -- Clock 50 MHz
    -- =========================================================================
    CLOCK_50 <= not CLOCK_50 after CLK_PERIOD / 2;

    -- =========================================================================
    -- Audio Loopback: DACDAT -> ADCDAT
    -- =========================================================================
    AUD_ADCDAT <= AUD_DACDAT;

    -- =========================================================================
    -- DUT
    -- =========================================================================
    DUT : entity work.AcakCakap_Top
    generic map (
        DEBOUNCE_LIMIT => 10
    )
    port map (
        CLOCK2_50 => CLOCK_50, CLOCK3_50 => CLOCK_50,
        CLOCK4_50 => CLOCK_50, CLOCK_50  => CLOCK_50,
        KEY      => KEY, SW => SW, UART_RXD => UART_RXD,
        LEDR     => LEDR,
        HEX0     => HEX0, HEX1 => HEX1, HEX2 => HEX2,
        HEX3     => HEX3, HEX4 => HEX4, HEX5 => HEX5,
        AUD_ADCDAT  => AUD_ADCDAT, AUD_ADCLRCK => AUD_ADCLRCK,
        AUD_BCLK    => AUD_BCLK,  AUD_DACDAT  => AUD_DACDAT,
        AUD_DACLRCK => AUD_DACLRCK, AUD_XCK   => AUD_XCK,
        FPGA_I2C_SCLK => FPGA_I2C_SCLK, FPGA_I2C_SDAT => FPGA_I2C_SDAT
    );

    -- =========================================================================
    -- MONITOR: Laporkan perubahan HEX5 (MSB nibble) ke transcript
    -- =========================================================================
    MONITOR_PROC : process(HEX5)
    begin
        if HEX5 /= hex5_prev then
            report "[MONITOR] HEX5 changed: " & to_string(HEX5) severity note;
            hex5_prev <= HEX5;
        end if;
    end process;

    -- =========================================================================
    -- STIM_PROC
    -- =========================================================================
    STIM_PROC : process
        variable pass : boolean := true;
    begin
        -- Kondisi awal
        UART_RXD <= '1';
        SW       <= (others => '0');
        SW(8)    <= '1';  -- Mode UART key
        SW(0)    <= '0';  -- Tampilan LSB

        -- Reset
        KEY(0) <= '0'; wait for 10 us; KEY(0) <= '1';

        -- Tunggu I2C/PLL settle secara dinamis
        report "[TB] Waiting for I2C/PLL to settle (dynamic)..." severity note;
        wait until rising_edge(AUD_XCK);
        wait for 10 us;

        -- ===========================================================
        -- FRAME 1: key = 0x3A7C9B1D (Kunci Biasa)
        -- ===========================================================
        report "[TB] === Frame 1: Sending 0x3A7C9B1D ===" severity note;
        UART_SEND_KEY(x"3A7C9B1D", UART_RXD);
        wait for 500 us;
        -- Trigger manual (jika uart_trigger tidak cukup)
        KEY(1) <= '0'; wait for 500 us; KEY(1) <= '1';
        -- Tunggu TX selesai + RX decode
        wait for FRAME_DURATION;
        -- Tunggu HEX stabil
        wait until HEX5'event or HEX5 = EXPECT_FRAME1.h5 for RX_TIMEOUT;
        wait for 1 us;
        -- Cek LSB
        SW(0) <= '0';
        wait for 1 us;
        CHECK_HEX(1, EXPECT_FRAME1, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0, pass);
        -- Cek MSB
        SW(0) <= '1';
        wait for 1 us;
        CHECK_HEX(1, EXPECT_MSB_FRAME1, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0, pass);
        SW(0) <= '0'; -- Kembalikan ke LSB

        -- ===========================================================
        -- FRAME 2: key = 0xFF3F3FF3 (Kunci Worst-Case)
        -- ===========================================================
        report "[TB] === Frame 2: Sending 0xFF3F3FF3 ===" severity note;
        UART_SEND_KEY(x"FF3F3FF3", UART_RXD);
        wait for 500 us;
        KEY(1) <= '0'; wait for 500 us; KEY(1) <= '1';
        wait for FRAME_DURATION;
        wait until HEX5'event or HEX5 = EXPECT_FRAME2.h5 for RX_TIMEOUT;
        wait for 1 us;
        -- Cek LSB
        SW(0) <= '0';
        wait for 1 us;
        CHECK_HEX(2, EXPECT_FRAME2, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0, pass);
        -- Cek MSB
        SW(0) <= '1';
        wait for 1 us;
        CHECK_HEX(2, EXPECT_MSB_FRAME2, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0, pass);
        SW(0) <= '0'; -- Kembalikan ke LSB

        -- Cek tidak stuck: HEX harus berbeda dari frame 1
        if HEX5 = EXPECT_FRAME1.h5 and HEX4 = EXPECT_FRAME1.h4 then
            report "[TB] Frame 2: STUCK - display sama dengan Frame 1!" severity warning;
            pass := false;
        end if;

        -- ===========================================================
        -- FRAME 3: key = 0x88888888 (Kunci Stress-Case)
        -- ===========================================================
        report "[TB] === Frame 3: Sending 0x88888888 ===" severity note;
        UART_SEND_KEY(x"88888888", UART_RXD);
        wait for 500 us;
        KEY(1) <= '0'; wait for 500 us; KEY(1) <= '1';
        wait for FRAME_DURATION;
        wait until HEX5'event or HEX5 = EXPECT_FRAME3.h5 for RX_TIMEOUT;
        wait for 1 us;
        -- Cek LSB
        SW(0) <= '0';
        wait for 1 us;
        CHECK_HEX(3, EXPECT_FRAME3, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0, pass);
        -- Cek MSB
        SW(0) <= '1';
        wait for 1 us;
        CHECK_HEX(3, EXPECT_MSB_FRAME3, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0, pass);
        SW(0) <= '0'; -- Kembalikan ke LSB

        -- Cek tidak stuck: HEX harus berbeda dari frame 2
        if HEX5 = EXPECT_FRAME2.h5 and HEX4 = EXPECT_FRAME2.h4 then
            report "[TB] Frame 3: STUCK - display sama dengan Frame 2!" severity warning;
            pass := false;
        end if;

        -- ===========================================================
        -- Verdict
        -- ===========================================================
        if pass then
            report "================== ALIGNMENT MULTIFRAME TEST: PASS ==================" severity note;
        else
            report "================== ALIGNMENT MULTIFRAME TEST: FAIL - lihat warnings di atas ==================" severity failure;
        end if;

        std.env.finish;
    end process;

end architecture;
