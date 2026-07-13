library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.fixed_pkg.all;
use std.textio.all;

entity toplevel_tb2 is
end toplevel_tb2;

architecture tb of toplevel_tb2 is

    constant clk_hz : integer := 50e6;
    constant clk_period : time := 1 sec / clk_hz;

    -- Component declaration matching toplevel_iq_text entity
    component toplevel_iq_text
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
            dataA       : in SFIXED((dataA_INT_BITS-1) downto -dataA_FRAC_BITS);
            enable      : out STD_LOGIC;
            dbg_sum697      : out SFIXED((batch_INT_BITS-1) downto -batch_FRAC_BITS);
            dbg_sum941      : out SFIXED((batch_INT_BITS-1) downto -batch_FRAC_BITS);
            dbg_sum1477     : out SFIXED((batch_INT_BITS-1) downto -batch_FRAC_BITS);
            dbg_batch_valid : out STD_LOGIC
        );
    end component;

    signal clk          : STD_LOGIC := '1';
    signal reset        : STD_LOGIC := '1';
    signal in_ready     : STD_LOGIC;
    signal out_valid    : STD_LOGIC;
    signal in_valid     : STD_LOGIC := '0';
    signal out_ready    : STD_LOGIC := '0';
    signal dataA        : SFIXED(2 downto -13);
    signal enable       : STD_LOGIC := '0';

    -- Debug signals
    signal dbg_sum697   : SFIXED(14 downto -1);
    signal dbg_sum941   : SFIXED(14 downto -1);
    signal dbg_sum1477  : SFIXED(14 downto -1);
    signal dbg_batch_valid : STD_LOGIC;

    signal sim_done     : boolean := false;

begin
    DUT: component toplevel_iq_text
        port map(
            clk             => clk,
            reset           => reset,
            in_valid        => in_valid,
            out_ready       => out_ready,
            in_ready        => in_ready,
            out_valid       => out_valid,
            dataA           => dataA,
            enable          => enable,
            dbg_sum697      => dbg_sum697,
            dbg_sum941      => dbg_sum941,
            dbg_sum1477     => dbg_sum1477,
            dbg_batch_valid => dbg_batch_valid
        );

    -- Clock
    clk <= not clk after clk_period / 2 when not sim_done else '0';

    -- Reset
    process
    begin
        reset <= '1';
        wait for 3 ns;
        reset <= '0';
        wait;
    end process;

    -- Data stimulus
    DATA_READ: process
        file data_file    : text open read_mode is "dtmf_signal_v2.txt";
        variable x_var    : real := 0.0;
        variable line_in  : line;
        variable sample_count : integer := 0;
    begin
        wait until reset = '0';
        wait for clk_period;

        report "============================================";
        report "  Frame Synchronization RTL Verification";
        report "  Q3.13 Input | Q8.8 Acc | Q12.4 Power | Q15.1 Batch";
        report "  Frame Size=40 | Batch Size=16";
        report "============================================";

        while not endfile(data_file) loop
            readline(data_file, line_in);
            read(line_in, x_var);
            dataA <= to_sfixed(x_var, dataA);
            in_valid <= '1';
            wait for clk_period;
            in_valid <= '0';
            out_ready <= '0';
            wait for clk_period;
            out_ready <= '1';
            wait for clk_period;
            sample_count := sample_count + 1;
        end loop;

        -- Wait for pipeline to flush
        wait for clk_period * 20;

        report "============================================";
        report "  Simulation Complete";
        report "  Total samples processed: " & integer'image(sample_count);
        report "  Enable (detection) = " & std_logic'image(enable);
        report "============================================";

        sim_done <= true;
        wait;
    end process;

    -- Monitor batch outputs
    BATCH_MONITOR: process
        variable batch_count : integer := 0;
        variable l : line;
    begin
        wait until reset = '0';
        loop
            wait until rising_edge(clk) or sim_done;
            exit when sim_done;

            if dbg_batch_valid = '1' then
                -- Convert SFIXED to real for printing
                write(l, string'("[Batch #"));
                write(l, batch_count);
                write(l, string'("] sum697="));
                write(l, to_real(dbg_sum697), right, 10, 4);
                write(l, string'("  sum941="));
                write(l, to_real(dbg_sum941), right, 10, 4);
                write(l, string'("  sum1477="));
                write(l, to_real(dbg_sum1477), right, 10, 4);

                -- Indicate dominant frequencies
                if to_real(dbg_sum941) > to_real(dbg_sum697) and 
                   to_real(dbg_sum1477) > to_real(dbg_sum697) then
                    write(l, string'("  -> [941+1477 dominant = '#']"));
                elsif to_real(dbg_sum697) > to_real(dbg_sum941) and 
                      to_real(dbg_sum1477) > to_real(dbg_sum941) then
                    write(l, string'("  -> [697+1477 dominant = '3']"));
                end if;

                writeline(output, l);
                batch_count := batch_count + 1;
            end if;
        end loop;

        report "Total batch outputs: " & integer'image(batch_count);
        wait;
    end process;

    -- Monitor enable signal
    ENABLE_MONITOR: process
    begin
        wait until enable = '1' or sim_done;
        if not sim_done then
            report ">>> ENABLE ASSERTED - Frame sync point detected! <<<" severity note;
        end if;
        wait;
    end process;

end tb;
