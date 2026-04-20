library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity powercalcv1 is
    generic(
        in_INT_BITS: natural        := 6;
        in_FRAC_BITS: natural       := 10;
        s2sin_INT_BITS: natural     := 10;
        s2sin_FRAC_BITS: natural    := 6;
        s2cos_INT_BITS: natural     := 9;
        s2cos_FRAC_BITS: natural    := 7;
        out_INT_BITS: natural       := 10;
        out_FRAC_BITS: natural      := 6
    );
    Port ( 
        clk, reset : in STD_LOGIC;
        in_valid    : in STD_LOGIC;
        out_ready   : in STD_LOGIC;
        in_ready    : out STD_LOGIC;
        out_valid   : out STD_LOGIC;
        -- Bus Data
        -- Framing Sin
        in_sin697   : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
        in_sin941   : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
        in_sin1477  : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);

        -- Framing Cos
        in_cos697   : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
        in_cos941   : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
        in_cos1477  : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);

        -- Hasil Power Calc
        out_697     : out SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);
        out_941     : out SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);
        out_1477    : out SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS)
    );
end powercalcv1;

architecture Behavioral of powercalcv1 is
    type state_type is (IDLE, COMPUTE, STORE);
    signal state : state_type;
    
    signal tempsin697, tempsin941, tempsin1477              : SFIXED((s2sin_INT_BITS-1) downto -s2sin_FRAC_BITS);
    signal tempcos697, tempcos941, tempcos1477              : SFIXED((s2cos_INT_BITS-1) downto -s2cos_FRAC_BITS);
    
    signal power_697        : SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);
    signal power_941        : SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);
    signal power_1477       : SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);

begin
    process(state)
    begin
        if state = IDLE then
            in_ready <= '1';
        else
            in_ready <= '0';
        end if;
    end process;

    process(clk, reset)
    begin
        if reset = '1' then
            out_valid <= '0';
            state <= IDLE;
            tempsin697 <= (others => '0');
            tempsin941 <= (others => '0');
            tempsin1477<= (others => '0');
            tempcos697 <= (others => '0');
            tempcos941 <= (others => '0');
            tempcos1477<= (others => '0');
            power_697 <= (others => '0');
            power_941 <= (others => '0');
            power_1477 <= (others => '0');
        elsif rising_edge(clk) then
            state <= state;
            case state is
                when IDLE =>
                    -- Proses Kuadrat Sin
                    tempsin697   <= resize(in_sin697 * in_sin697, tempsin697);
                    tempsin941   <= resize(in_sin941 * in_sin941, tempsin941);
                    tempsin1477  <= resize(in_sin1477 * in_sin1477, tempsin1477);
                    
                    -- Proses Kuadrat Cos
                    tempcos697   <= resize(in_cos697 * in_cos697, tempcos697);
                    tempcos941   <= resize(in_cos941 * in_cos941, tempcos941);
                    tempcos1477  <= resize(in_cos1477 * in_cos1477, tempcos1477);
                    
                    out_valid <= '0'; 
                    if in_valid = '1' then
                        state <= COMPUTE;
                    else
                        state <= IDLE;
                    end if;

                when COMPUTE =>
                    -- Proses Penambahan Komponen Sin dan Cos
                    power_697        <= resize(tempsin697 + tempcos697, power_697);
                    power_941        <= resize(tempsin941 + tempcos941, power_941);
                    power_1477       <= resize(tempsin1477 + tempcos1477, power_1477);
                    state <= STORE;
                
                when STORE =>
                    out_697          <= power_697;
                    out_941          <= power_941;
                    out_1477         <= power_1477;
                    out_valid <= '1'; 
                    if out_ready = '1' then
                        state <= IDLE;
                    end if;
                
                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;

end Behavioral;
