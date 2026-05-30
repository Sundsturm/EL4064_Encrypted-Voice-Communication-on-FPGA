library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity generate_dtmf_signed is
    generic(
        addr_bits : integer range 1 to 31 := 9; -- Determines how many samples to store
        data_bits : integer range 1 to 32 := 16  -- Determines how many bits is going to be used to represent each samples
    );
    port (
        clk         : in std_logic;
        rst         : in std_logic;
        command     : in std_logic;
        tone_digit  : in std_logic_vector(3 downto 0);
        dtmf_out    : out signed(data_bits - 1 downto 0)
    );
end generate_dtmf_signed;

architecture rtl of generate_dtmf_signed is
    
    -- %% Signal for interfacing with the output %%
    signal sum : signed(data_bits downto 0); 
    -- Data for each DTMF generator
    signal data_low : signed (data_bits - 1 downto 0); -- Low frequency group
    signal data_high : signed (data_bits - 1 downto 0); -- High frequency group
    -- For determining the required phase increment to synthesize the frequency
    signal phase_incr_low : unsigned(31 downto 0); 
    signal phase_incr_high : unsigned(31 downto 0);

begin

    DIGIT_DECODER : process(tone_digit)
    begin 
        -- Default mappings to avoid latches
        phase_incr_low  <= (others => '0');
        phase_incr_high <= (others => '0');

        case tone_digit is
            when x"0" => -- Digit 0 (941, 1336)
                phase_incr_low  <= to_unsigned(219224, phase_incr_low'length);
                phase_incr_high <= to_unsigned(311220, phase_incr_high'length);
            when x"1" => -- Digit 1 (697, 1209)
                phase_incr_low  <= to_unsigned(162388, phase_incr_low'length);
                phase_incr_high <= to_unsigned(281644, phase_incr_high'length);
            when x"2" => -- Digit 2 (697, 1336)
                phase_incr_low  <= to_unsigned(162388, phase_incr_low'length);
                phase_incr_high <= to_unsigned(311220, phase_incr_high'length);
            when x"3" => -- Digit 3 (697, 1477)
                phase_incr_low  <= to_unsigned(162388, phase_incr_low'length);
                phase_incr_high <= to_unsigned(344056, phase_incr_high'length);
            when x"4" => -- Digit 4 (770, 1209)
                phase_incr_low  <= to_unsigned(179393, phase_incr_low'length);
                phase_incr_high <= to_unsigned(281644, phase_incr_high'length);
            when x"5" => -- Digit 5 (770, 1336)
                phase_incr_low  <= to_unsigned(179393, phase_incr_low'length);
                phase_incr_high <= to_unsigned(311220, phase_incr_high'length);
            when x"6" => -- Digit 6 (770, 1477)
                phase_incr_low  <= to_unsigned(179393, phase_incr_low'length);
                phase_incr_high <= to_unsigned(344056, phase_incr_high'length);
            when x"7" => -- Digit 7 (852, 1209)
                phase_incr_low  <= to_unsigned(198494, phase_incr_low'length);
                phase_incr_high <= to_unsigned(281644, phase_incr_high'length);
            when x"8" => -- Digit 8 (852, 1336)
                phase_incr_low  <= to_unsigned(198494, phase_incr_low'length);
                phase_incr_high <= to_unsigned(311220, phase_incr_high'length);
            when x"9" => -- Digit 9 (852, 1477)
                phase_incr_low  <= to_unsigned(198494, phase_incr_low'length);
                phase_incr_high <= to_unsigned(344056, phase_incr_high'length);
            when x"A" => -- Digit A (697, 1633)
                phase_incr_low  <= to_unsigned(162388, phase_incr_low'length);
                phase_incr_high <= to_unsigned(380394, phase_incr_high'length);
            when x"B" => -- Digit B (770, 1633)
                phase_incr_low  <= to_unsigned(179393, phase_incr_low'length);
                phase_incr_high <= to_unsigned(380394, phase_incr_high'length);
            when x"C" => -- Digit C (852, 1633)
                phase_incr_low  <= to_unsigned(198494, phase_incr_low'length);
                phase_incr_high <= to_unsigned(380394, phase_incr_high'length);
            when x"D" => -- Digit D (941, 1633)
                phase_incr_low  <= to_unsigned(219224, phase_incr_low'length);
                phase_incr_high <= to_unsigned(380394, phase_incr_high'length);
            when x"E" => -- Digit * (941, 1209)
                phase_incr_low  <= to_unsigned(219224, phase_incr_low'length);
                phase_incr_high <= to_unsigned(281644, phase_incr_high'length);
            when x"F" => -- Digit # (941, 1477)
                phase_incr_low  <= to_unsigned(219224, phase_incr_low'length);
                phase_incr_high <= to_unsigned(344056, phase_incr_high'length);
            when others =>
                phase_incr_low  <= to_unsigned(0, phase_incr_low'length);
                phase_incr_high <= to_unsigned(0, phase_incr_high'length);
        end case;
    end process;

    LOW_FREQ : entity work.sine_gen_signed(rtl) 
    generic map (
        addr_bits => addr_bits,
        data_bits => data_bits
    )
    port map (
        clk => clk,
        rst => rst,
        phase_incr  => phase_incr_low,
        data => data_low
    );

    HIGH_FREQ : entity work.sine_gen_signed(rtl) 
    generic map (
        addr_bits => addr_bits,
        data_bits => data_bits
    )
    port map (
        clk => clk,
        rst => rst,
        phase_incr  => phase_incr_high,
        data => data_high
    );

    sum <= resize(data_low, 17) + resize(data_high, 17); 

    dtmf_out <= sum(16) & sum(15 downto 1) when command = '1' 
                else (others => '0'); 

end architecture;