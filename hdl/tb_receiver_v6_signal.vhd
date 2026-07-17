library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library ieee_proposed;
use ieee_proposed.fixed_pkg.all;
use std.textio.all;

entity tb_receiver_v6_signal is
end tb_receiver_v6_signal;

architecture behavior of tb_receiver_v6_signal is
    -- Clock & Reset
    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    
    -- Simulation clock period (54.25 ns for ~18.432 MHz)
    constant clk_period : time := 54.25 ns;
    signal sim_done     : boolean := false;
    
    -- Sample rate emulation (pulse Ldone every 10 system clocks to speed up simulation)
    signal Ldone        : std_logic := '0';
    
    -- Transmitter signals
    signal start_transmission : std_logic := '0';
    signal dataA              : SFIXED(2 downto -13) := (others => '0');
    
    -- Transmitter FSM states to match run_frame_sync_demo_v6_signal.m:
    --   [ noise (1280) | '#' (640) | '#' (640) | '3' (640) | '#' (640) | noise (1280) ]
    type tx_state_type is (IDLE, LEADING_NOISE, HASH_1, HASH_2, TONE_3, HASH_3, TRAILING_NOISE, DONE);
    signal tx_state         : tx_state_type := IDLE;
    signal tx_sample_cnt    : integer range 0 to 2047 := 0;
    
    -- Receiver signals
    signal enable           : std_logic := '0';
    signal corr_out_valid   : std_logic;
    signal Aud_interface_ready : std_logic;
    
    -- Debug signals (Matching toplevel_tb2 from Frame Synchronization_v3)
    signal dbg_sum697       : SFIXED(14 downto -1);
    signal dbg_sum941       : SFIXED(14 downto -1);
    signal dbg_sum1477      : SFIXED(14 downto -1);
    signal dbg_batch_valid  : STD_LOGIC;

begin
    -- Clock Generation
    clk <= not clk after clk_period/2 when not sim_done else '0';

    -- =========================================================================
    -- V6-SIGNAL GENERATION PROCESS (Equivalent to MATLAB v6 run_frame_sync_demo)
    -- =========================================================================
    BEHAVIORAL_DTMF_GEN : process(clk)
        variable seed1 : positive := 12345;
        variable seed2 : positive := 67890;
        variable rand_val : real;
        variable n : real := 0.0;
        variable temp_val : real := 0.0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                tx_state <= IDLE;
                tx_sample_cnt <= 0;
                temp_val := 0.0;
                dataA <= (others => '0');
            else
                case tx_state is
                    when IDLE =>
                        dataA <= (others => '0');
                        tx_sample_cnt <= 0;
                        if start_transmission = '1' then
                            tx_state <= LEADING_NOISE;
                        end if;
                        
                    when LEADING_NOISE =>
                        if Ldone = '1' then
                            uniform(seed1, seed2, rand_val);
                            temp_val := (4.0 * rand_val) - 2.0; -- Uniform noise range [-2.0, 2.0]
                            dataA <= to_sfixed(temp_val, dataA);
                            if tx_sample_cnt = 1279 then
                                tx_sample_cnt <= 0;
                                tx_state <= HASH_1;
                                n := 0.0;
                            else
                                tx_sample_cnt <= tx_sample_cnt + 1;
                            end if;
                        end if;
                        
                    when HASH_1 =>
                        if Ldone = '1' then
                            -- '#' = 941 Hz + 1477 Hz
                            temp_val := sin(2.0 * MATH_PI * 941.0 * n / 32000.0) + sin(2.0 * MATH_PI * 1477.0 * n / 32000.0);
                            dataA <= to_sfixed(temp_val, dataA);
                            n := n + 1.0;
                            if tx_sample_cnt = 639 then
                                tx_sample_cnt <= 0;
                                tx_state <= HASH_2;
                                n := 0.0;
                            else
                                tx_sample_cnt <= tx_sample_cnt + 1;
                            end if;
                        end if;

                    when HASH_2 =>
                        if Ldone = '1' then
                            -- '#' = 941 Hz + 1477 Hz
                            temp_val := sin(2.0 * MATH_PI * 941.0 * n / 32000.0) + sin(2.0 * MATH_PI * 1477.0 * n / 32000.0);
                            dataA <= to_sfixed(temp_val, dataA);
                            n := n + 1.0;
                            if tx_sample_cnt = 639 then
                                tx_sample_cnt <= 0;
                                tx_state <= TONE_3;
                                n := 0.0;
                            else
                                tx_sample_cnt <= tx_sample_cnt + 1;
                            end if;
                        end if;

                    when TONE_3 =>
                        if Ldone = '1' then
                            -- '3' = 697 Hz + 1477 Hz
                            temp_val := sin(2.0 * MATH_PI * 697.0 * n / 32000.0) + sin(2.0 * MATH_PI * 1477.0 * n / 32000.0);
                            dataA <= to_sfixed(temp_val, dataA);
                            n := n + 1.0;
                            if tx_sample_cnt = 639 then
                                tx_sample_cnt <= 0;
                                tx_state <= HASH_3;
                                n := 0.0;
                            else
                                tx_sample_cnt <= tx_sample_cnt + 1;
                            end if;
                        end if;

                    when HASH_3 =>
                        if Ldone = '1' then
                            -- '#' = 941 Hz + 1477 Hz
                            temp_val := sin(2.0 * MATH_PI * 941.0 * n / 32000.0) + sin(2.0 * MATH_PI * 1477.0 * n / 32000.0);
                            dataA <= to_sfixed(temp_val, dataA);
                            n := n + 1.0;
                            if tx_sample_cnt = 639 then
                                tx_sample_cnt <= 0;
                                tx_state <= TRAILING_NOISE;
                            else
                                tx_sample_cnt <= tx_sample_cnt + 1;
                            end if;
                        end if;

                    when TRAILING_NOISE =>
                        if Ldone = '1' then
                            uniform(seed1, seed2, rand_val);
                            temp_val := (4.0 * rand_val) - 2.0; -- Uniform noise range [-2.0, 2.0]
                            dataA <= to_sfixed(temp_val, dataA);
                            if tx_sample_cnt = 1279 then
                                tx_sample_cnt <= 0;
                                tx_state <= DONE;
                            else
                                tx_sample_cnt <= tx_sample_cnt + 1;
                            end if;
                        end if;

                    when DONE =>
                        dataA <= (others => '0');
                end case;
            end if;
        end if;
    end process;

    -- Ldone Generation (Sample clock pulse)
    process
        variable ldone_cnt : integer := 0;
    begin
        loop
            wait until rising_edge(clk) or sim_done;
            exit when sim_done;
            if ldone_cnt = 9 then
                Ldone <= '1';
                ldone_cnt := 0;
            else
                Ldone <= '0';
                ldone_cnt := ldone_cnt + 1;
            end if;
        end loop;
        wait;
    end process;


    -- =========================================================================
    -- RECEIVER INSTANCE UNDER TEST (toplevel_iq_text from receiver_hdl)
    -- =========================================================================
    DTMF_corr: entity work.toplevel_iq_text
    generic map (
        dataA_INT_BITS  => 3,
        dataA_FRAC_BITS => 13,
        mult_INT_BITS   => 3,
        mult_FRAC_BITS  => 13,
        acc_INT_BITS    => 8,
        acc_FRAC_BITS   => 8,
        power_INT_BITS  => 12,
        power_FRAC_BITS => 4,
        batch_INT_BITS  => 15,
        batch_FRAC_BITS => 1,
        GUARD_FLOOR     => 16.0
    )
    port map (
        clk             => clk,
        reset           => rst,
        in_valid        => Ldone, 
        out_ready       => '1',
        in_ready        => Aud_interface_ready,
        out_valid       => corr_out_valid,
        dataA           => dataA,
        enable          => enable,
        dbg_sum697      => dbg_sum697,
        dbg_sum941      => dbg_sum941,
        dbg_sum1477     => dbg_sum1477,
        dbg_batch_valid => dbg_batch_valid
    );

    -- Stimulus Sequence Control
    STIM_PROC: process
    begin
        -- Assert reset
        rst <= '1';
        start_transmission <= '0';
        wait for clk_period * 20;
        rst <= '0';
        wait for clk_period * 20;
        
        -- Trigger stimulus sequence
        report "[TB_V6] Starting Frame Synchronization Test with v6 Noisy Signal Sequence..." severity note;
        start_transmission <= '1';
        wait until rising_edge(clk);
        start_transmission <= '0';
        
        -- Wait for sequence to complete
        wait until tx_state = DONE;
        wait for clk_period * 50;
        
        report "[TB_V6] Simulation Finished." severity note;
        sim_done <= true;
        wait;
    end process;
    
    -- Monitor batch outputs (matching toplevel_tb2.vhd)
    BATCH_MONITOR: process
        variable batch_count : integer := 0;
        variable l : line;
    begin
        wait until rst = '0';
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

end behavior;
