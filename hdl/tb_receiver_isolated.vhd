library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_receiver_isolated is
end tb_receiver_isolated;

architecture behavior of tb_receiver_isolated is
    -- Clock & Reset
    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    
    -- Simulation clock period (e.g. 54 ns for ~18.432 MHz)
    constant clk_period : time := 54.25 ns;
    signal sim_done     : boolean := false;
    
    -- Sample rate emulation (pulse Ldone every 576 system clocks)
    signal Ldone        : std_logic := '0';
    signal Lin          : signed(15 downto 0) := (others => '0');
    
    -- Transmitter signals
    signal start_transmission : std_logic := '0';
    signal dtmf_tone_enable   : std_logic := '0';
    signal tone_digit         : std_logic_vector(3 downto 0) := (others => '0');
    signal dtmf_lout          : signed(15 downto 0);
    
    -- Transmitter FSM
    type tx_state_type is (IDLE, PRE_SILENCE, TRANSMIT);
    signal tx_state         : tx_state_type := IDLE;
    signal tx_sample_cnt    : integer range 0 to 2047 := 0;
    signal tx_segment_cnt   : unsigned(3 downto 0) := (others => '0');
    signal current_key      : std_logic_vector(31 downto 0) := x"3A7C9B1D";
    signal tx_digit_to_send : std_logic_vector(3 downto 0) := (others => '0');
    
    -- Receiver signals
    signal enable           : std_logic := '0';
    signal corr_out_valid   : std_logic;
    signal Aud_interface_ready : std_logic;
    
    -- Goertzel & Decoder signals
    signal goertzel_enable    : std_logic;
    signal goertzel_out_valid : std_logic;
    signal encoder_in_ready   : std_logic;
    signal power_697          : std_logic_vector(16 downto 0);
    signal power_770          : std_logic_vector(16 downto 0);
    signal power_852          : std_logic_vector(16 downto 0);
    signal power_941          : std_logic_vector(16 downto 0);
    signal power_1209         : std_logic_vector(16 downto 0);
    signal power_1336         : std_logic_vector(16 downto 0);
    signal power_1477         : std_logic_vector(16 downto 0);
    signal power_1633         : std_logic_vector(16 downto 0);
    signal dtmf_code_4bit     : std_logic_vector(3 downto 0);
    signal dtmf_code_valid    : std_logic;
    signal reconstructed_key  : std_logic_vector(31 downto 0);
    signal out_valid          : std_logic;
    
    -- Local reset logic for receiver
    signal rx_rst             : std_logic;
    
    -- Alignment FSM signals (duplicated from top-level)
    signal enable_d         : std_logic := '0';
    signal align_armed      : std_logic := '0';
    signal align_counter    : integer range 0 to 2047 := 0;
    signal goertzel_aligned : std_logic := '0';

begin
    -- Clock Generation (~18.432 MHz)
    clk <= not clk after clk_period/2 when not sim_done else '0';
    
    -- Receiver local reset
    rx_rst <= rst;
    
    -- Gated goertzel enable
    goertzel_enable <= Ldone and enable and goertzel_aligned;
    
    -- Loopback audio
    Lin <= dtmf_lout;

    -- =========================================================================
    -- TRANSMITTER BEHAVIORAL SIMULATION MODEL (Replaces generate_dtmf_signed)
    -- Synthesizes correct frequencies directly at the 32kHz sample rate.
    -- =========================================================================
    BEHAVIORAL_DTMF_GEN : process(clk)
        variable n : real := 0.0;
        variable f_low, f_high : real := 0.0;
        variable sin_low, sin_high : real;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                n := 0.0;
                dtmf_lout <= (others => '0');
            else
                if dtmf_tone_enable = '1' then
                    -- Select frequencies based on tone_digit
                    case tone_digit is
                        when x"0" => f_low := 941.0;  f_high := 1336.0;
                        when x"1" => f_low := 697.0;  f_high := 1209.0;
                        when x"2" => f_low := 697.0;  f_high := 1336.0;
                        when x"3" => f_low := 697.0;  f_high := 1477.0;
                        when x"4" => f_low := 770.0;  f_high := 1209.0;
                        when x"5" => f_low := 770.0;  f_high := 1336.0;
                        when x"6" => f_low := 770.0;  f_high := 1477.0;
                        when x"7" => f_low := 852.0;  f_high := 1209.0;
                        when x"8" => f_low := 852.0;  f_high := 1336.0;
                        when x"9" => f_low := 852.0;  f_high := 1477.0;
                        when x"A" => f_low := 697.0;  f_high := 1633.0;
                        when x"B" => f_low := 770.0;  f_high := 1633.0;
                        when x"C" => f_low := 852.0;  f_high := 1633.0;
                        when x"D" => f_low := 941.0;  f_high := 1633.0;
                        when x"E" => f_low := 941.0;  f_high := 1209.0; -- '*'
                        when x"F" => f_low := 941.0;  f_high := 1477.0; -- '#'
                        when others => f_low := 0.0;  f_high := 0.0;
                    end case;
                    
                    if Ldone = '1' then
                        sin_low  := sin(2.0 * MATH_PI * f_low * n / 32000.0);
                        sin_high := sin(2.0 * MATH_PI * f_high * n / 32000.0);
                        dtmf_lout <= to_signed(integer((sin_low + sin_high) * 8191.0), 16);
                        n := n + 1.0;
                    end if;
                else
                    dtmf_lout <= (others => '0');
                    n := 0.0;
                end if;
            end if;
        end if;
    end process;

    -- Combinational segment multiplexer for 32-bit payload key
    process(current_key, tx_segment_cnt)
        variable seg : integer;
    begin
        seg := to_integer(tx_segment_cnt);
        case seg is
            when 4 => tx_digit_to_send <= current_key(31 downto 28);
            when 5 => tx_digit_to_send <= current_key(27 downto 24);
            when 6 => tx_digit_to_send <= current_key(23 downto 20);
            when 7 => tx_digit_to_send <= current_key(19 downto 16);
            when 8 => tx_digit_to_send <= current_key(15 downto 12);
            when 9 => tx_digit_to_send <= current_key(11 downto 8);
            when 10 => tx_digit_to_send <= current_key(7 downto 4);
            when 11 => tx_digit_to_send <= current_key(3 downto 0);
            when others => tx_digit_to_send <= (others => '0');
        end case;
    end process;

    -- Preamble + Payload multiplexer
    process(tx_segment_cnt, tx_digit_to_send)
        variable seg : integer;
    begin
        seg := to_integer(tx_segment_cnt);
        case seg is
            when 0 | 1 | 3 =>
                tone_digit <= x"F"; -- '#'
            when 2 =>
                tone_digit <= x"3"; -- '3'
            when others =>
                tone_digit <= tx_digit_to_send;
        end case;
    end process;

    -- Transmitter FSM
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                tx_state <= IDLE;
                tx_sample_cnt <= 0;
                tx_segment_cnt <= (others => '0');
                dtmf_tone_enable <= '0';
            else
                case tx_state is
                    when IDLE =>
                        dtmf_tone_enable <= '0';
                        tx_sample_cnt <= 0;
                        if start_transmission = '1' then
                            tx_segment_cnt <= (others => '0');
                            tx_state <= PRE_SILENCE;
                        end if;
                        
                    when PRE_SILENCE =>
                        dtmf_tone_enable <= '0';
                        if Ldone = '1' then
                            if tx_sample_cnt = 1599 then
                                tx_sample_cnt <= 0;
                                tx_state <= TRANSMIT;
                            else
                                tx_sample_cnt <= tx_sample_cnt + 1;
                            end if;
                        end if;
                        
                    when TRANSMIT =>
                        dtmf_tone_enable <= '1';
                        if Ldone = '1' then
                            if tx_sample_cnt = 639 then
                                tx_sample_cnt <= 0;
                                if tx_segment_cnt < 11 then
                                    tx_segment_cnt <= tx_segment_cnt + 1;
                                else
                                    tx_state <= IDLE;
                                end if;
                            else
                                tx_sample_cnt <= tx_sample_cnt + 1;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

    -- Ldone Generation (Sample clock pulse sped up: 1 high out of 10 system clocks)
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
    -- RECEIVER INSTANCES
    -- =========================================================================
    DTMF_corr: entity work.toplevel_iq_fpga
    generic map (
        mult_INT_BITS   => 2,
        mult_FRAC_BITS  => 14,
        acc_INT_BITS    => 6,
        acc_FRAC_BITS   => 10,
        power_INT_BITS  => 10,
        power_FRAC_BITS => 6,
        batch_INT_BITS  => 14,
        batch_FRAC_BITS => 2,
        GUARD_FLOOR     => 100.0
    )
    port map (
        clk          => clk,
        master_reset => rst,
        reset        => rx_rst,
        in_valid     => Ldone, 
        out_ready    => '1',
        in_ready     => Aud_interface_ready,
        out_valid    => corr_out_valid,
        dataA        => std_logic_vector(Lin),
        enable       => enable
    );
    
    -- Alignment FSM
    GOERTZEL_ALIGN_FSM : process(clk)
    begin
        if rising_edge(clk) then
            if rx_rst = '1' then
                enable_d         <= '0';
                align_armed      <= '0';
                align_counter    <= 0;
                goertzel_aligned <= '0';
            else
                enable_d <= enable;
                if goertzel_aligned = '0' then
                    if align_armed = '0' then
                        if enable = '1' and enable_d = '0' then
                            align_armed   <= '1';
                            align_counter <= 0;
                        end if;
                    else
                        if Ldone = '1' then
                            -- Fine-tuned delay to align Goertzel window perfectly with symbol boundaries.
                            -- Preamble detection (enable) goes high at sample 3397.
                            -- Segment 4 starts at sample 4160.
                            -- Delay = 4160 - 3397 = 763 samples.
                            if align_counter = 857 then
                                goertzel_aligned <= '1';
                            else
                                align_counter <= align_counter + 1;
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- Goertzel Filter Bank
    GOERTZEL_RX : entity work.Goertzel_top
    generic map (
        DATA_WIDTH => 16,
        BLOCK_SIZE => 640
    )
    port map (
        clk       => clk,
        rst       => rx_rst,
        in_ready  => open,
        in_valid  => goertzel_enable,
        DTMF_sig  => std_logic_vector(Lin),
        out_ready => encoder_in_ready,
        out_valid => goertzel_out_valid,
        power_697 => power_697,
        power_770 => power_770,
        power_852 => power_852,
        power_941 => power_941,
        power_1209 => power_1209,
        power_1336 => power_1336,
        power_1477 => power_1477,
        power_1633 => power_1633
    );
    
    -- DTMF Decoder
    DTMF_ENCODER_RX : entity work.top_dtmfencode
    generic map (
        THRESHOLD_VAL => 1000
    )
    port map (
        clk        => clk,
        rst        => rx_rst,
        in_valid   => goertzel_out_valid,
        in_ready   => encoder_in_ready,
        corr_697   => power_697,
        corr_770   => power_770,
        corr_852   => power_852,
        corr_941   => power_941,
        corr_1209  => power_1209,
        corr_1336  => power_1336,
        corr_1477  => power_1477,
        corr_1633  => power_1633,
        out_ready  => '1',
        out_valid  => out_valid,
        sevseg     => open,
        anode      => open,
        encode_out => reconstructed_key
    );

    -- Stimulus Control Process: Sends 3 keys sequentially
    STIM_PROC: process
    begin
        -- Reset sequence
        rst <= '1';
        start_transmission <= '0';
        wait for clk_period * 20;
        rst <= '0';
        wait for clk_period * 20;
        
        -- =====================================================================
        -- Test Key 1: 0x3A7C9B1D (Standard Key)
        -- =====================================================================
        current_key <= x"3A7C9B1D";
        report "[TB_ISO] === Phase 1: Transmitting 0x3A7C9B1D ===" severity note;
        start_transmission <= '1';
        wait until rising_edge(clk);
        start_transmission <= '0';
        
        -- Wait until decoded or timeout
        wait until rising_edge(clk) and out_valid = '1' for 10 ms;
        assert reconstructed_key = x"3A7C9B1D"
            report "[TB_ISO] ERROR: Key 1 Mismatch! Got 0x" & to_hstring(reconstructed_key)
            severity failure;
        report "[TB_ISO] SUCCESS: Key 1 Decoded correctly! 0x" & to_hstring(reconstructed_key) severity note;
        
        wait for 10 us; -- Inter-frame gap
        rst <= '1';
        wait for clk_period * 20;
        rst <= '0';
        wait for clk_period * 20;
        
        -- =====================================================================
        -- Test Key 2: 0xFF3F3FF3 (Worst Case: contains '#' and '3')
        -- =====================================================================
        current_key <= x"FF3F3FF3";
        report "[TB_ISO] === Phase 2: Transmitting 0xFF3F3FF3 ===" severity note;
        start_transmission <= '1';
        wait until rising_edge(clk);
        start_transmission <= '0';
        
        wait until rising_edge(clk) and out_valid = '1' for 10 ms;
        assert reconstructed_key = x"FF3F3FF3"
            report "[TB_ISO] ERROR: Key 2 Mismatch! Got 0x" & to_hstring(reconstructed_key)
            severity failure;
        report "[TB_ISO] SUCCESS: Key 2 Decoded correctly! 0x" & to_hstring(reconstructed_key) severity note;
        
        wait for 10 us;
        rst <= '1';
        wait for clk_period * 20;
        rst <= '0';
        wait for clk_period * 20;
        
        -- =====================================================================
        -- Test Key 3: 0x88888888 (Stress Case: continuous identical characters)
        -- =====================================================================
        current_key <= x"88888888";
        report "[TB_ISO] === Phase 3: Transmitting 0x88888888 ===" severity note;
        start_transmission <= '1';
        wait until rising_edge(clk);
        start_transmission <= '0';
        
        wait until rising_edge(clk) and out_valid = '1' for 10 ms;
        assert reconstructed_key = x"88888888"
            report "[TB_ISO] ERROR: Key 3 Mismatch! Got 0x" & to_hstring(reconstructed_key)
            severity failure;
        report "[TB_ISO] SUCCESS: Key 3 Decoded correctly! 0x" & to_hstring(reconstructed_key) severity note;
        
        wait for 10 us;
        rst <= '1';
        wait for clk_period * 20;
        rst <= '0';
        wait for clk_period * 20;
        
        report "[TB_ISO] ===================================================" severity note;
        report "[TB_ISO] === ALL DIRECT TRANSCEIVER TESTS PASSED (100% PASS) ===" severity note;
        report "[TB_ISO] ===================================================" severity note;
        
        sim_done <= true;
        wait;
    end process;
    
    -- Monitor output for visual confirmation
    MONITOR_PROC: process
    begin
        loop
            wait until rising_edge(clk) or sim_done;
            exit when sim_done;
            if enable = '1' and enable_d = '0' then
                report "[TB_ISO] Preamble detected! Enable went HIGH." severity note;
            end if;
            if Ldone = '1' and tx_sample_cnt = 0 and tx_state = TRANSMIT then
                report "[TB_ISO] TX Segment " & integer'image(to_integer(tx_segment_cnt)) &
                       " starting, Digit: " & to_string(tone_digit) severity note;
            end if;
            if goertzel_out_valid = '1' then
                report "[TB_ISO] Goertzel block finished. Powers -> " &
                       "697: " & to_string(power_697) & ", " &
                       "770: " & to_string(power_770) & ", " &
                       "852: " & to_string(power_852) & ", " &
                       "941: " & to_string(power_941) & " | " &
                       "1209: " & to_string(power_1209) & ", " &
                       "1336: " & to_string(power_1336) & ", " &
                       "1477: " & to_string(power_1477) & ", " &
                       "1633: " & to_string(power_1633) severity note;
            end if;
            if dtmf_code_valid = '1' then
                report "[TB_ISO] Symbol Decoded: " & integer'image(to_integer(unsigned(dtmf_code_4bit))) severity note;
            end if;
        end loop;
        wait;
    end process;

end behavior;
