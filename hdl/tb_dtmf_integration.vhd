library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_dtmf_integration is
end entity;

architecture sim of tb_dtmf_integration is
    constant CLK_PERIOD : time := 54.25 ns; -- ~18.432 MHz
    constant CLK_PER_SAMPLE : integer := 576; -- 18.432 MHz / 32 kHz
    constant SAMPLES_20MS : integer := 640;

    signal clk  : std_logic := '0';
    signal rst  : std_logic := '1';

    signal start_tx : std_logic := '0';
    signal test_key_in : std_logic_vector(23 downto 0) := (others => '0');
    signal reconstructed_key_out : std_logic_vector(23 downto 0);

    signal audio_loopback : std_logic_vector(15 downto 0);

    -- Sender-side signals
    signal sender_command : std_logic := '0';
    signal sender_rst : std_logic := '1';
    signal sender_tone_digit : std_logic_vector(9 downto 0) := (others => '0');
    signal sender_dtmf_out : signed(15 downto 0);

    type tx_state_type is (TX_IDLE, TX_TRANSMIT, TX_SILENCE);
    signal tx_state : tx_state_type := TX_IDLE;
    signal tx_sample_counter : integer range 0 to SAMPLES_20MS := 0;
    signal tx_segment_counter : integer range 0 to 9 := 0;
    signal goertzel_enable : std_logic := '0';
    signal sample_div_counter : integer range 0 to CLK_PER_SAMPLE-1 := 0;
    signal sample_tick : std_logic := '0';

    -- Receiver-side interconnects
    signal goertzel_in_ready : std_logic;
    signal goertzel_out_valid : std_logic;
    signal encoder_in_ready : std_logic;

    signal power_697  : std_logic_vector(16 downto 0);
    signal power_770  : std_logic_vector(16 downto 0);
    signal power_852  : std_logic_vector(16 downto 0);
    signal power_941  : std_logic_vector(16 downto 0);
    signal power_1209 : std_logic_vector(16 downto 0);
    signal power_1336 : std_logic_vector(16 downto 0);
    signal power_1477 : std_logic_vector(16 downto 0);

    signal encoder_out_valid : std_logic;
    signal sevseg_dummy : std_logic_vector(6 downto 0);
    signal anode_dummy : std_logic;
    signal encode_out_dummy : std_logic_vector(23 downto 0);
    signal dtmf_code_4bit : std_logic_vector(3 downto 0);
    signal dtmf_code_valid : std_logic;

    signal shift_add_in_ready : std_logic;
    signal shift_add_out_valid : std_logic;
    signal shift_add_valid_in : std_logic := '0';
    signal payload_symbol_count : integer range 0 to 8 := 0;

    function segment_to_tone(
        segment_idx : integer;
        key24 : std_logic_vector(23 downto 0)
    ) return std_logic_vector is
        variable key_bits : std_logic_vector(2 downto 0);
        variable bit_hi : integer;
    begin
        if segment_idx = 0 then
            return "1000000001"; -- '#'
        elsif segment_idx = 1 then
            return "0000000100"; -- '3'
        else
            bit_hi := 23 - ((segment_idx - 2) * 3);
            key_bits := key24(bit_hi downto bit_hi - 2);

            case key_bits is
                when "000" => return "0000000001"; -- '1'
                when "001" => return "0000000010"; -- '2'
                when "010" => return "0000001000"; -- '4'
                when "011" => return "0000010000"; -- '5'
                when "100" => return "0001000000"; -- '7'
                when "101" => return "0010000000"; -- '8'
                when "110" => return "1000000000"; -- '*'
                when others => return "0000000000"; -- '0'
            end case;
        end if;
    end function;

begin
    -- 1) Clock generator
    clk <= not clk after CLK_PERIOD / 2;

    -- 32 kHz sample strobe derived from 18.432 MHz clock.
    SAMPLE_TICK_PROC : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sample_div_counter <= 0;
                sample_tick <= '0';
            elsif sample_div_counter = CLK_PER_SAMPLE - 1 then
                sample_div_counter <= 0;
                sample_tick <= '1';
            else
                sample_div_counter <= sample_div_counter + 1;
                sample_tick <= '0';
            end if;
        end if;
    end process;

    -- 2) Audio loopback: sender output -> receiver input
    audio_loopback <= std_logic_vector(sender_dtmf_out);

    -- 3) Sender UUT: DTMF tone generator
    UUT_SENDER : entity work.generate_dtmf_signed(rtl)
    generic map (
        addr_bits => 9,
        data_bits => 16
    )
    port map (
        clk => clk,
        rst => sender_rst,
        command => sender_command,
        tone_digit => sender_tone_digit,
        dtmf_out => sender_dtmf_out
    );

    -- Drive sender/receiver enables from transmission state.
    sender_command <= '1' when tx_state = TX_TRANSMIT else '0';
    sender_rst <= '0' when (rst = '0' and tx_state = TX_TRANSMIT) else '1';
    sender_tone_digit <= segment_to_tone(tx_segment_counter, test_key_in) when tx_state = TX_TRANSMIT else (others => '0');
    goertzel_enable <= '1' when tx_state = TX_TRANSMIT else '0';

    -- Accept only first 8 payload symbols (bit3='1') for key reconstruction.
    SHIFT_ADD_INPUT_CTRL : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                shift_add_valid_in <= '0';
                payload_symbol_count <= 0;
            else
                shift_add_valid_in <= '0';
                if (dtmf_code_valid = '1') and (dtmf_code_4bit(3) = '1') and (payload_symbol_count < 8) then
                    report "RX payload symbol[" & integer'image(payload_symbol_count) & "]=" &
                           integer'image(to_integer(unsigned(dtmf_code_4bit(2 downto 0)))) severity note;
                    payload_symbol_count <= payload_symbol_count + 1;
                    shift_add_valid_in <= '1';
                end if;
            end if;
        end if;
    end process;

    -- Sender control FSM in TB (10 segments, each 20 ms tone + 20 ms silence)
    TX_FSM_PROC : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                tx_state <= TX_IDLE;
                tx_sample_counter <= 0;
                tx_segment_counter <= 0;
            elsif sample_tick = '1' then
                case tx_state is
                    when TX_IDLE =>
                        tx_sample_counter <= 0;
                        tx_segment_counter <= 0;

                        if start_tx = '1' then
                            tx_state <= TX_TRANSMIT;
                        end if;

                    when TX_TRANSMIT =>
                        if tx_sample_counter = SAMPLES_20MS - 1 then
                            tx_sample_counter <= 0;
                            tx_state <= TX_SILENCE;
                        else
                            tx_sample_counter <= tx_sample_counter + 1;
                        end if;

                    when TX_SILENCE =>
                        if tx_sample_counter = SAMPLES_20MS - 1 then
                            tx_sample_counter <= 0;
                            if tx_segment_counter < 9 then
                                tx_segment_counter <= tx_segment_counter + 1;
                                tx_state <= TX_TRANSMIT;
                            else
                                tx_state <= TX_IDLE;
                            end if;
                        else
                            tx_sample_counter <= tx_sample_counter + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    -- 4) Receiver UUT chain
    UUT_GOERTZEL : entity work.Goertzel_top(rtl)
    generic map (
        DATA_WIDTH => 16,
        BLOCK_SIZE => 640
    )
    port map (
        clk => clk,
        rst => rst,
        in_ready => goertzel_in_ready,
        in_valid => goertzel_enable and sample_tick,
        DTMF_sig => audio_loopback,
        out_ready => encoder_in_ready,
        out_valid => goertzel_out_valid,
        power_697 => power_697,
        power_770 => power_770,
        power_852 => power_852,
        power_941 => power_941,
        power_1209 => power_1209,
        power_1336 => power_1336,
        power_1477 => power_1477
    );

    UUT_DTMF_ENCODER : entity work.top_dtmfencode(Behavioral)
    port map (
        clk => clk,
        rst => rst,
        in_valid => goertzel_out_valid,
        in_ready => encoder_in_ready,
        corr_697 => power_697,
        corr_770 => power_770,
        corr_852 => power_852,
        corr_941 => power_941,
        corr_1209 => power_1209,
        corr_1336 => power_1336,
        corr_1477 => power_1477,
        out_ready => '1',
        out_valid => encoder_out_valid,
        sevseg => sevseg_dummy,
        anode => anode_dummy,
        encode_out => encode_out_dummy,
        dtmf_code_4bit => dtmf_code_4bit,
        dtmf_code_valid => dtmf_code_valid
    );

    UUT_SHIFT_ADD : entity work.shift_add(Behavioral)
    port map (
        clk => clk,
        reset => rst,
        in_valid => shift_add_valid_in,
        out_ready => '1',
        in_ready => shift_add_in_ready,
        out_valid => shift_add_out_valid,
        input3 => dtmf_code_4bit,
        output32 => reconstructed_key_out
    );

    -- 5) Stimulus
    STIM_PROC : process
    begin
        -- Reset 100 ns
        rst <= '1';
        start_tx <= '0';
        test_key_in <= (others => '0');
        wait for 100 ns;

        -- Release reset + wait a few cycles
        rst <= '0';
        wait for 10 * CLK_PERIOD;

        -- Load test key
        test_key_in <= x"A5C3B1";
        wait for 5 * CLK_PERIOD;

        -- Pulse start trigger
        start_tx <= '1';
        wait for 1 ms;
        start_tx <= '0';

        -- Wait long enough for 10 segments + receiver pipeline latency margin.
        wait for 520 ms;

        -- Result check
        if reconstructed_key_out = test_key_in then
            assert false report "INTEGRATION TEST PASSED" severity note;
        else
            assert false
                report "TEST FAILED | expected=" & integer'image(to_integer(unsigned(test_key_in))) &
                       " got=" & integer'image(to_integer(unsigned(reconstructed_key_out)))
                severity error;
        end if;

        wait;
    end process;

end architecture;
