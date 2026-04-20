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
        tone_digit  : in std_logic_vector(9 downto 0);
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

--    DIGIT_DECODER : process(tone_digit)
--    begin 
--        case tone_digit is
--            WHEN "0000000000" => -- Digit 0
--                phase_incr_low  <= to_unsigned(113006493, phase_incr_low'length); -- Freq 941
--                phase_incr_high <= to_unsigned(153654571, phase_incr_high'length); -- Freq 1336
--            WHEN "0000000001" => -- Digit 1
--                phase_incr_low  <= to_unsigned(86052438, phase_incr_low'length); -- Freq 697
--                phase_incr_high <= to_unsigned(140965780, phase_incr_high'length); -- Freq 1209
--            WHEN "0000000010" => -- Digit 2
--                phase_incr_low  <=  to_unsigned(86052438, phase_incr_low'length); -- Freq 697
--                phase_incr_high <=  to_unsigned(153654571, phase_incr_high'length); -- Freq 1336
--            WHEN "0000000100" => -- Digit 3
--                phase_incr_low  <= to_unsigned(86052438, phase_incr_low'length); -- Freq 697
--                phase_incr_high <= to_unsigned(167343745, phase_incr_high'length); -- Freq 1477
--            WHEN "0000001000" => -- Digit 4
--                phase_incr_low  <= to_unsigned(94273798, phase_incr_low'length); -- Freq 770
--                phase_incr_high <= to_unsigned(140965780, phase_incr_high'length); -- Freq 1209
--            WHEN "0000010000" => -- Digit 5
--                phase_incr_low <= to_unsigned(94273798, phase_incr_low'length); -- Freq 770
--                phase_incr_high <= to_unsigned(153654571, phase_incr_high'length); -- Freq 1336
--            WHEN "0000100000" => -- Digit 6
--                phase_incr_low <= to_unsigned(94273798, phase_incr_low'length); -- Freq 770
--                phase_incr_high <= to_unsigned(167343745, phase_incr_high'length); -- Freq 1477
--            WHEN "0001000000" => -- Digit 7
--                phase_incr_low <= to_unsigned(103347044, phase_incr_low'length); -- Freq 852
--                phase_incr_high <= to_unsigned(140965780, phase_incr_high'length); -- Freq 1209
--            WHEN "0010000000" => -- Digit 8
--                phase_incr_low <= to_unsigned(103347044, phase_incr_low'length); -- Freq 852
--                phase_incr_high <= to_unsigned(153654571, phase_incr_high'length); -- Freq 1336
--            WHEN "0100000000" => -- Digit 9
--                phase_incr_low <= to_unsigned(103347044, phase_incr_low'length); -- Freq 852
--                phase_incr_high <= to_unsigned(167343745, phase_incr_high'length); -- Freq 1477
--            WHEN "1000000000" => -- Digit *
--                phase_incr_low <= to_unsigned(113006493, phase_incr_low'length); -- Freq 941
--                phase_incr_high <= to_unsigned(140965780, phase_incr_high'length); -- Freq 1209;
--            WHEN "1000000001" => -- Digit #
--                phase_incr_low <= to_unsigned(113006493, phase_incr_low'length); -- Freq 941
--                phase_incr_high <= to_unsigned(167343745, phase_incr_high'length); -- Freq 1477
--            WHEN others => -- Send zero phase increment
--                phase_incr_low  <= to_unsigned(0, phase_incr_low'length); 
--                phase_incr_high <= to_unsigned(0, phase_incr_high'length); 
--        end case;
--    end process;

    DIGIT_DECODER : process(tone_digit)
    begin 
        case tone_digit is
            WHEN "0000000000" => -- Digit 0
                phase_incr_low  <= to_unsigned(219224, phase_incr_low'length); -- Freq 941
                phase_incr_high <= to_unsigned(311220, phase_incr_high'length); -- Freq 1336
            WHEN "0000000001" => -- Digit 1
                phase_incr_low  <= to_unsigned(162388, phase_incr_low'length); -- Freq 697
                phase_incr_high <= to_unsigned(281644, phase_incr_high'length); -- Freq 1209
            WHEN "0000000010" => -- Digit 2
                phase_incr_low  <= to_unsigned(162388, phase_incr_low'length); -- Freq 697
                phase_incr_high <= to_unsigned(311220, phase_incr_high'length); -- Freq 1336
            WHEN "0000000100" => -- Digit 3
                phase_incr_low  <= to_unsigned(162388, phase_incr_low'length); -- Freq 697
                phase_incr_high <= to_unsigned(344056, phase_incr_high'length); -- Freq 1477
            WHEN "0000001000" => -- Digit 4
                phase_incr_low  <= to_unsigned(179393, phase_incr_low'length); -- Freq 770
                phase_incr_high <= to_unsigned(281644, phase_incr_high'length); -- Freq 1209
            WHEN "0000010000" => -- Digit 5
                phase_incr_low  <= to_unsigned(179393, phase_incr_low'length); -- Freq 770
                phase_incr_high <= to_unsigned(311220, phase_incr_high'length); -- Freq 1336
            WHEN "0000100000" => -- Digit 6
                phase_incr_low  <= to_unsigned(179393, phase_incr_low'length); -- Freq 770
                phase_incr_high <= to_unsigned(344056, phase_incr_high'length); -- Freq 1477
            WHEN "0001000000" => -- Digit 7
                phase_incr_low  <= to_unsigned(198494, phase_incr_low'length); -- Freq 852
                phase_incr_high <= to_unsigned(281644, phase_incr_high'length); -- Freq 1209
            WHEN "0010000000" => -- Digit 8
                phase_incr_low  <= to_unsigned(198494, phase_incr_low'length); -- Freq 852
                phase_incr_high <= to_unsigned(311220, phase_incr_high'length); -- Freq 1336
            WHEN "0100000000" => -- Digit 9
                phase_incr_low  <= to_unsigned(198494, phase_incr_low'length); -- Freq 852
                phase_incr_high <= to_unsigned(344056, phase_incr_high'length); -- Freq 1477
            WHEN "1000000000" => -- Digit *
                phase_incr_low  <= to_unsigned(219224, phase_incr_low'length); -- Freq 941
                phase_incr_high <= to_unsigned(281644, phase_incr_high'length); -- Freq 1209
            WHEN "1000000001" => -- Digit #
                phase_incr_low  <= to_unsigned(219224, phase_incr_low'length); -- Freq 941
                phase_incr_high <= to_unsigned(344056, phase_incr_high'length); -- Freq 1477
            WHEN others => -- Send zero phase increment
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