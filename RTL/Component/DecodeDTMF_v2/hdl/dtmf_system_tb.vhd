-- =============================================================================
-- dtmf_system_tb.vhd
-- Structural test for dtmf_system (full pipeline: Goertzel + encode).
-- Sends blocks of constant samples to verify pipeline doesn't deadlock
-- and encode_out changes after 8 symbols.
-- NOTE: Compile Goertzel.vhd and Goertzel_top.vhd with "vcom -2008".
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dtmf_system_tb is
end dtmf_system_tb;

architecture behavior of dtmf_system_tb is

    component dtmf_system is
        generic (
            DATA_WIDTH : integer := 16;
            BLOCK_SIZE : integer := 640
        );
        port (
            clk        : in  std_logic;
            rst        : in  std_logic;
            in_valid   : in  std_logic;
            in_ready   : out std_logic;
            dtmf_input : in  std_logic_vector(15 downto 0);
            out_ready  : in  std_logic;
            out_valid  : out std_logic;
            sevseg     : out std_logic_vector(6 downto 0);
            anode      : out std_logic;
            encode_out : out std_logic_vector(31 downto 0)
        );
    end component;

    constant CLK_PERIOD : time := 54 ns; -- ~18.432 MHz

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal in_valid   : std_logic := '0';
    signal in_ready   : std_logic;
    signal dtmf_input : std_logic_vector(15 downto 0) := (others => '0');
    signal out_ready  : std_logic := '1';
    signal out_valid  : std_logic;
    signal sevseg     : std_logic_vector(6 downto 0);
    signal anode      : std_logic;
    signal encode_out : std_logic_vector(31 downto 0);

begin

    clk <= not clk after CLK_PERIOD / 2;

    DUT : dtmf_system
        generic map (DATA_WIDTH => 16, BLOCK_SIZE => 640)
        port map (
            clk        => clk,
            rst        => rst,
            in_valid   => in_valid,
            in_ready   => in_ready,
            dtmf_input => dtmf_input,
            out_ready  => out_ready,
            out_valid  => out_valid,
            sevseg     => sevseg,
            anode      => anode,
            encode_out => encode_out
        );

    stim_proc : process
        variable sample_count : integer := 0;
    begin
        rst      <= '1';
        in_valid <= '0';
        wait for CLK_PERIOD * 5;
        rst <= '0';
        wait for CLK_PERIOD * 2;

        -- Send 8 blocks of 640 constant samples (structural/connectivity check)
        for sym in 1 to 8 loop
            report "[TB] Sending block " & integer'image(sym) & " of 8";
            for i in 0 to 639 loop
                wait until rising_edge(clk);
                while in_ready = '0' loop
                    wait until rising_edge(clk);
                end loop;
                dtmf_input <= std_logic_vector(to_signed(8192, 16));
                in_valid   <= '1';
                wait until rising_edge(clk);
                in_valid   <= '0';
            end loop;
            wait for CLK_PERIOD * 20;
        end loop;

        wait for CLK_PERIOD * 200;
        report "[TB] encode_out (dec) = " & integer'image(to_integer(unsigned(encode_out)));
        report "[TB] Structural simulation done. Check waveform for encode_out changes.";
        wait;
    end process;

end behavior;
