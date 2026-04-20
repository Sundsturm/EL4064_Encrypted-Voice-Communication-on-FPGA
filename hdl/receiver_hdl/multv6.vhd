library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity multv6 is
    generic(
        dataA_INT_BITS: natural := 2;
        dataA_FRAC_BITS: natural := 14;
        tempsin_INT_BITS: natural := 1;
        tempsin_FRAC_BITS: natural := 15;
        tempcos_INT_BITS: natural := 2;
        tempcos_FRAC_BITS: natural := 14;
        mult_INT_BITS: natural := 2;
        mult_FRAC_BITS: natural := 14
    );
    Port ( 
        clk, reset  : in STD_LOGIC;

        in_valid    : in STD_LOGIC;
        out_ready   : in STD_LOGIC;
        in_ready    : out STD_LOGIC;
        out_valid   : out STD_LOGIC;

        -- Bus Data Input
        dataA       : in std_logic_vector(15 downto 0);
        sin697      : in std_logic_vector(15 downto 0);
        sin941      : in std_logic_vector(15 downto 0);
        sin1477     : in std_logic_vector(15 downto 0);
        cos697      : in std_logic_vector(15 downto 0);
        cos941      : in std_logic_vector(15 downto 0);
        cos1477     : in std_logic_vector(15 downto 0);

        -- Bus Data Output
        multsin_697 : out SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
        multsin_941 : out SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
        multsin_1477: out SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
        multcos_697 : out SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
        multcos_941 : out SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
        multcos_1477: out SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
        address     : out STD_LOGIC_VECTOR(9 downto 0)
    );
end multv6;

architecture Behavioral of multv6 is
    type state_type is (IDLE, COMPUTE, STORE);
    signal state : state_type;
    signal address_internal : INTEGER range 0 to 640 := 0;
    signal tempinput    : SFIXED((dataA_INT_BITS-1) downto -dataA_FRAC_BITS);
    -- Sinyal Temporary Sin
    signal tempsin697   : sfixed((tempsin_INT_BITS-1) downto -tempsin_FRAC_BITS);
    signal tempsin941   : sfixed((tempsin_INT_BITS-1) downto -tempsin_FRAC_BITS);
    signal tempsin1477  : sfixed((tempsin_INT_BITS-1) downto -tempsin_FRAC_BITS);
    signal mult_sin697  : SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
    signal mult_sin941  : SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
    signal mult_sin1477 : SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
    

    -- Sinyal Temporary Cos
    signal tempcos697  : sfixed((tempcos_INT_BITS-1) downto -tempcos_FRAC_BITS);
    signal tempcos941  : sfixed((tempcos_INT_BITS-1) downto -tempcos_FRAC_BITS);
    signal tempcos1477 : sfixed((tempcos_INT_BITS-1) downto -tempcos_FRAC_BITS);
    signal mult_cos697 : SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
    signal mult_cos941 : SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
    signal mult_cos1477: SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
    
begin
    process(state)
    begin
        if state = IDLE then
            in_ready <= '1';
            out_valid <= '0';
        elsif state = STORE then
            out_valid <= '1';
            in_ready <= '0';
        else
            out_valid <= '0';
            in_ready <= '0';
        end if;
    end process;

    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            tempinput   <= (others => '0');

            tempsin697  <= (others => '0');
            tempsin941  <= (others => '0');
            tempsin1477 <= (others => '0');
            tempcos697  <= (others => '0');
            tempcos941  <= (others => '0');
            tempcos1477 <= (others => '0');

            -- Inisialisasi Sinyal Internal Multiplier
            mult_sin697 <= (others => '0');
            mult_sin941 <= (others => '0');
            mult_sin1477<= (others => '0');
            mult_cos697 <= (others => '0');
            mult_cos941 <= (others => '0');
            mult_cos1477<= (others => '0');
        elsif rising_edge(clk) then
            state <= state;
            case state is
                when IDLE =>
                    -- Convert LUT Sin to SFIXED (1).(0).(15)
                    tempinput   <= to_sfixed(dataA, dataA_INT_BITS-1, -dataA_FRAC_BITS);
                    tempsin697  <= to_sfixed(sin697, tempsin_INT_BITS-1, -tempsin_FRAC_BITS);
                    tempsin941  <= to_sfixed(sin941, tempsin_INT_BITS-1, -tempsin_FRAC_BITS);
                    tempsin1477 <= to_sfixed(sin1477, tempsin_INT_BITS-1, -tempsin_FRAC_BITS);

                    -- Convert LUT Cos to SFIXED (1).(1).(14)
                    tempcos697 <= to_sfixed(cos697, tempcos_INT_BITS-1, -tempcos_FRAC_BITS);
                    tempcos941 <= to_sfixed(cos941, tempcos_INT_BITS-1, -tempcos_FRAC_BITS);
                    tempcos1477 <= to_sfixed(cos1477, tempcos_INT_BITS-1, -tempcos_FRAC_BITS);
                    if in_valid = '1' then
                        state <= COMPUTE;
                    else
                        state <= IDLE;
                    end if;

                when COMPUTE =>
                    -- Sin Multiplier
                    mult_sin697    <= resize(tempinput * tempsin697, mult_sin697);
                    mult_sin941    <= resize(tempinput * tempsin941, mult_sin941);
                    mult_sin1477   <= resize(tempinput * tempsin1477, mult_sin1477);

                    -- Cose Multipliery
                    mult_cos697    <= resize(tempinput * tempcos697, mult_cos697);
                    mult_cos941    <= resize(tempinput * tempcos941, mult_cos941);
                    mult_cos1477   <= resize(tempinput * tempcos1477, mult_cos1477);
                    state <= STORE;
                
                when STORE =>
                    multsin_697 <= mult_sin697;
                    multsin_941 <= mult_sin941;
                    multsin_1477<= mult_sin1477;
                    multcos_697 <= mult_cos697;
                    multcos_941 <= mult_cos941;
                    multcos_1477<= mult_cos1477;
                    address_internal <= (address_internal + 1) mod 640;
                    if out_ready = '1' then
                        state <= IDLE;
                    end if;
                
                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;
    address <= std_logic_vector(to_unsigned(address_internal, 10));
end Behavioral;
