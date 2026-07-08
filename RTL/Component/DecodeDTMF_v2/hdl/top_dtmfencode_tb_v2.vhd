-- =============================================================================
-- top_dtmfencode_tb_v2.vhd
-- Unit test for top_dtmfencode (comparators + decision + shift_add).
-- Directly injects power values — no Goertzel needed.
-- Tests all 16 DTMF symbols including 1633 Hz (A, B, C, D).
--
-- Test Sequence  : 1  2  3  4  5  A  B  C
-- Expected output: encode_out = x"12345ABC"
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_dtmfencode_tb_v2 is
end top_dtmfencode_tb_v2;

architecture behavior of top_dtmfencode_tb_v2 is

    component top_dtmfencode is
        Port (
            clk, rst    : in  STD_LOGIC;
            in_valid    : in  STD_LOGIC;
            in_ready    : out STD_LOGIC;
            corr_697    : in  STD_LOGIC_VECTOR(16 downto 0);
            corr_770    : in  STD_LOGIC_VECTOR(16 downto 0);
            corr_852    : in  STD_LOGIC_VECTOR(16 downto 0);
            corr_941    : in  STD_LOGIC_VECTOR(16 downto 0);
            corr_1209   : in  STD_LOGIC_VECTOR(16 downto 0);
            corr_1336   : in  STD_LOGIC_VECTOR(16 downto 0);
            corr_1477   : in  STD_LOGIC_VECTOR(16 downto 0);
            corr_1633   : in  STD_LOGIC_VECTOR(16 downto 0);
            out_ready   : in  STD_LOGIC;
            out_valid   : out STD_LOGIC;
            sevseg      : out STD_LOGIC_VECTOR(6 downto 0);
            anode       : out STD_LOGIC;
            encode_out  : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;

    constant CLK_PERIOD  : time := 10 ns;

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal in_valid   : std_logic := '0';
    signal in_ready   : std_logic;
    signal out_ready  : std_logic := '1';
    signal out_valid  : std_logic;
    signal sevseg     : std_logic_vector(6 downto 0);
    signal anode      : std_logic;
    signal encode_out : std_logic_vector(31 downto 0);
    signal corr_697   : std_logic_vector(16 downto 0) := (others => '0');
    signal corr_770   : std_logic_vector(16 downto 0) := (others => '0');
    signal corr_852   : std_logic_vector(16 downto 0) := (others => '0');
    signal corr_941   : std_logic_vector(16 downto 0) := (others => '0');
    signal corr_1209  : std_logic_vector(16 downto 0) := (others => '0');
    signal corr_1336  : std_logic_vector(16 downto 0) := (others => '0');
    signal corr_1477  : std_logic_vector(16 downto 0) := (others => '0');
    signal corr_1633  : std_logic_vector(16 downto 0) := (others => '0');

    -- Power levels
    constant DOM : std_logic_vector(16 downto 0) := "00000000000011111"; -- dominant
    constant BKG : std_logic_vector(16 downto 0) := "00000000000000001"; -- background

    constant EXPECTED_KEY : std_logic_vector(31 downto 0) := x"12345ABC";

    -- -----------------------------------------------------------------------
    -- Procedure at architecture level (required for signal parameters)
    -- dominant_low:  1=697Hz, 2=770Hz, 3=852Hz, 4=941Hz
    -- dominant_high: 1=1209Hz, 2=1336Hz, 3=1477Hz, 4=1633Hz
    -- -----------------------------------------------------------------------
    procedure inject_symbol (
        d_low  : in integer range 1 to 4;
        d_high : in integer range 1 to 4;
        signal c697   : out std_logic_vector(16 downto 0);
        signal c770   : out std_logic_vector(16 downto 0);
        signal c852   : out std_logic_vector(16 downto 0);
        signal c941   : out std_logic_vector(16 downto 0);
        signal c1209  : out std_logic_vector(16 downto 0);
        signal c1336  : out std_logic_vector(16 downto 0);
        signal c1477  : out std_logic_vector(16 downto 0);
        signal c1633  : out std_logic_vector(16 downto 0);
        signal iv     : out std_logic;
        signal i_ready: in  std_logic;
        signal clk_s  : in  std_logic
    ) is
    begin
        -- Set all to background
        c697 <= BKG; c770 <= BKG; c852 <= BKG; c941 <= BKG;
        c1209 <= BKG; c1336 <= BKG; c1477 <= BKG; c1633 <= BKG;
        -- Set dominant low frequency
        case d_low is
            when 1 => c697 <= DOM;
            when 2 => c770 <= DOM;
            when 3 => c852 <= DOM;
            when 4 => c941 <= DOM;
        end case;
        -- Set dominant high frequency
        case d_high is
            when 1 => c1209 <= DOM;
            when 2 => c1336 <= DOM;
            when 3 => c1477 <= DOM;
            when 4 => c1633 <= DOM;
        end case;
        -- Wait for DUT ready, then pulse in_valid
        wait until rising_edge(clk_s);
        while i_ready = '0' loop
            wait until rising_edge(clk_s);
        end loop;
        iv <= '1';
        wait until rising_edge(clk_s);
        iv <= '0';
        -- Allow pipeline to complete (comparators + decision + shift_add)
        wait for CLK_PERIOD * 30;
    end procedure;

begin

    clk <= not clk after CLK_PERIOD / 2;

    UUT : top_dtmfencode
        port map (
            clk        => clk,
            rst        => rst,
            in_valid   => in_valid,
            in_ready   => in_ready,
            corr_697   => corr_697,
            corr_770   => corr_770,
            corr_852   => corr_852,
            corr_941   => corr_941,
            corr_1209  => corr_1209,
            corr_1336  => corr_1336,
            corr_1477  => corr_1477,
            corr_1633  => corr_1633,
            out_ready  => out_ready,
            out_valid  => out_valid,
            sevseg     => sevseg,
            anode      => anode,
            encode_out => encode_out
        );

    stim : process
    begin
        -- Reset
        rst <= '1';
        wait for CLK_PERIOD * 5;
        rst <= '0';
        wait for CLK_PERIOD * 3;

        -- Test: 1 2 3 4 5 A B C  =>  expected 0x12345ABC
        -- '1' : 697Hz(1) + 1209Hz(1) -> 0x1
        inject_symbol(1, 1, corr_697, corr_770, corr_852, corr_941,
                      corr_1209, corr_1336, corr_1477, corr_1633,
                      in_valid, in_ready, clk);
        -- '2' : 697Hz(1) + 1336Hz(2) -> 0x2
        inject_symbol(1, 2, corr_697, corr_770, corr_852, corr_941,
                      corr_1209, corr_1336, corr_1477, corr_1633,
                      in_valid, in_ready, clk);
        -- '3' : 697Hz(1) + 1477Hz(3) -> 0x3
        inject_symbol(1, 3, corr_697, corr_770, corr_852, corr_941,
                      corr_1209, corr_1336, corr_1477, corr_1633,
                      in_valid, in_ready, clk);
        -- '4' : 770Hz(2) + 1209Hz(1) -> 0x4
        inject_symbol(2, 1, corr_697, corr_770, corr_852, corr_941,
                      corr_1209, corr_1336, corr_1477, corr_1633,
                      in_valid, in_ready, clk);
        -- '5' : 770Hz(2) + 1336Hz(2) -> 0x5
        inject_symbol(2, 2, corr_697, corr_770, corr_852, corr_941,
                      corr_1209, corr_1336, corr_1477, corr_1633,
                      in_valid, in_ready, clk);
        -- 'A' : 697Hz(1) + 1633Hz(4) -> 0xA  [tests 1633 Hz path]
        inject_symbol(1, 4, corr_697, corr_770, corr_852, corr_941,
                      corr_1209, corr_1336, corr_1477, corr_1633,
                      in_valid, in_ready, clk);
        -- 'B' : 770Hz(2) + 1633Hz(4) -> 0xB  [tests 1633 Hz path]
        inject_symbol(2, 4, corr_697, corr_770, corr_852, corr_941,
                      corr_1209, corr_1336, corr_1477, corr_1633,
                      in_valid, in_ready, clk);
        -- 'C' : 852Hz(3) + 1633Hz(4) -> 0xC  [tests 1633 Hz path]
        inject_symbol(3, 4, corr_697, corr_770, corr_852, corr_941,
                      corr_1209, corr_1336, corr_1477, corr_1633,
                      in_valid, in_ready, clk);

        -- Wait for shift_add to output
        wait for CLK_PERIOD * 100;

        -- Verify
        report "=========================================";
        if encode_out = EXPECTED_KEY then
            report "PASS: encode_out = 12345ABC (correct)" severity note;
        else
            report "FAIL: encode_out does not match 12345ABC" severity error;
        end if;
        report "encode_out (decimal) = " & integer'image(to_integer(unsigned(encode_out)));
        report "=========================================";

        wait;
    end process;

end behavior;
