library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library ieee_proposed;
use ieee_proposed.fixed_pkg.all;
use std.textio.all;

entity toplevel_tb1 is
-- Testbench entities do not have ports.
end toplevel_tb1;

architecture tb of toplevel_tb1 is

    constant clk_hz : integer := 50e6;
    constant clk_period : time := 1 sec / clk_hz; -- Clock of 20 ns period

    constant sample_clk_hz : integer := 32e3;
    constant sample_clk_period : time := 1 sec / sample_clk_hz; -- Sample Clock

    -- Instance of the design under test
    component toplevelv1
        generic(
            dataA_INT_BITS:     natural := 3;
            dataA_FRAC_BITS:    natural := 13;
            mult_INT_BITS:      natural := 3;
            mult_FRAC_BITS:     natural := 13;
            acc_INT_BITS:       natural := 8;
            acc_FRAC_BITS:      natural := 8;
            power_INT_BITS:     natural := 12;
            power_FRAC_BITS:    natural := 4;
            batch_INT_BITS:     natural := 15;
            batch_FRAC_BITS:    natural := 1
        );
        Port ( 
            clk, reset  : in STD_LOGIC;
            in_valid    : in STD_LOGIC;
            out_ready   : in STD_LOGIC;
            in_ready    : out STD_LOGIC;
            out_valid   : out STD_LOGIC;
            -- Bus Data
            dataA       : in SFIXED((dataA_INT_BITS-1) downto -dataA_FRAC_BITS);
            enable      : out STD_LOGIC;
            -- Debug Ports
            dbg_sum697      : out SFIXED((batch_INT_BITS-1) downto -batch_FRAC_BITS);
            dbg_sum941      : out SFIXED((batch_INT_BITS-1) downto -batch_FRAC_BITS);
            dbg_sum1477     : out SFIXED((batch_INT_BITS-1) downto -batch_FRAC_BITS);
            dbg_batch_valid : out STD_LOGIC
        );
    end component;

    signal clk          : STD_LOGIC := '1';
    signal reset        : STD_LOGIC := '1';
    signal in_ready, out_valid : STD_LOGIC;
    signal in_valid     : STD_LOGIC := '0';
    signal out_ready    : STD_LOGIC := '0';
    signal dataA        : SFIXED((2) downto -13);
    signal enable       : STD_LOGIC := '0';
    
begin
    -- Instance of the design under test
    DUT: component toplevelv1
        port map(
            clk         => clk,
            reset       => reset,
            in_valid    => in_valid,
            out_ready   => out_ready,
            in_ready    => in_ready,
            out_valid   => out_valid,
            dataA       => dataA,
            enable      => enable,
            dbg_sum697      => open,
            dbg_sum941      => open,
            dbg_sum1477     => open,
            dbg_batch_valid => open
        );

    -- Clock process definitions
    clk <= not clk after clk_period / 2;

    process
    begin 
        reset <= '0' after 3 ns;
        wait;
    end process;

    DATA_READ: process
        file data_file    : text open read_mode is "dtmf_signal.txt";
        variable x_var    : real := 0.0;
        variable line_in  : line;
        variable counter  : integer := 0;
    begin
        while not endfile(data_file) loop
            readline(data_file, line_in);
            read(line_in, x_var);
            dataA <= to_sfixed(x_var, dataA);
            in_valid <= '1';
            wait for clk_period; -- Wait for one clock cycle
            in_valid <= '0';
            out_ready <= '0'; -- Reset out_ready to '0'
            wait for clk_period; -- Wait for another clock cycle
            out_ready <= '1'; -- Set out_ready after two clock cycles from in_valid
            wait for clk_period; -- This ensures dataA and in_valid are updated every 2 cycles
        end loop;
    end process;

end tb;