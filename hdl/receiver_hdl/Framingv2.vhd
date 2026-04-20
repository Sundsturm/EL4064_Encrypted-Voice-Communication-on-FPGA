library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity Framingv2 is
    generic(
        data_INT_BITS: natural := 2;
        data_FRAC_BITS: natural := 14;
        acc_INT_BITS: natural := 6;
        acc_FRAC_BITS: natural := 10
    );
    Port ( 
        clk, reset : in STD_LOGIC;
        
        in_valid    : in STD_LOGIC;
        out_ready   : in STD_LOGIC;
        in_ready    : out STD_LOGIC;
        out_valid   : out STD_LOGIC;
        -- Bus Data Input
        multsin697  : in SFIXED((data_INT_BITS-1) downto -data_FRAC_BITS);
        multsin941  : in SFIXED((data_INT_BITS-1) downto -data_FRAC_BITS);
        multsin1477 : in SFIXED((data_INT_BITS-1) downto -data_FRAC_BITS);
        multcos697  : in SFIXED((data_INT_BITS-1) downto -data_FRAC_BITS);
        multcos941  : in SFIXED((data_INT_BITS-1) downto -data_FRAC_BITS);
        multcos1477 : in SFIXED((data_INT_BITS-1) downto -data_FRAC_BITS);
        
        acc_sin697  : out SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS); 
        acc_sin941  : out SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS); 
        acc_sin1477 : out SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
        acc_cos697  : out SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS); 
        acc_cos941  : out SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS); 
        acc_cos1477 : out SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS) 
    );
end Framingv2;

architecture Behavioral of Framingv2 is
    type state_type is (IDLE, COMPUTE, STORE);
    signal state            : state_type;
    signal counter          : INTEGER range 0 to 32 := 0;

    -- Sinyal Temporarty Sin
    signal tempAcc_sin697   : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal tempAcc_sin941   : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal tempAcc_sin1477  : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal accout_sin697   : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal accout_sin941   : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal accout_sin1477  : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    
    -- Sinyal Temporary Cos
    signal tempAcc_cos697   : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal tempAcc_cos941   : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal tempAcc_cos1477  : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal accout_cos697   : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal accout_cos941   : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal accout_cos1477  : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    
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
            state <= IDLE;
            counter <= 0;
            tempAcc_sin697 <= (others => '0');
            tempAcc_sin941 <= (others => '0');
            tempAcc_sin1477<= (others => '0');
            tempAcc_cos697 <= (others => '0');
            tempAcc_cos941 <= (others => '0');
            tempAcc_cos1477<= (others => '0');
            accout_sin697 <= (others => '0');
            accout_sin941 <= (others => '0');
            accout_sin1477<= (others => '0');
            accout_cos697 <= (others => '0');
            accout_cos941 <= (others => '0');
            accout_cos1477<= (others => '0');
        elsif rising_edge(clk) then
            state <= state;
            case state is
                when IDLE =>
                    out_valid <= '0';
                    if in_valid = '1' then
                        state <= COMPUTE;
                    else
                        state <= IDLE;
                    end if;

                when COMPUTE =>
                    tempAcc_sin697 <= resize(multsin697 + accout_sin697, tempAcc_sin697);
                    tempAcc_sin941 <= resize(multsin941 + accout_sin941, tempAcc_sin941);
                    tempAcc_sin1477<= resize(multsin1477 + accout_sin1477, tempAcc_sin1477);

                    tempAcc_cos697 <= resize(multcos697 + accout_cos697, tempAcc_cos697);
                    tempAcc_cos941 <= resize(multcos941 + accout_cos941, tempAcc_cos941);
                    tempAcc_cos1477<= resize(multcos1477 + accout_cos1477, tempAcc_cos1477);
                    if counter < 31 then
                        accout_sin697 <= tempAcc_sin697;
                        accout_sin941 <= tempAcc_sin941;
                        accout_sin1477<= tempAcc_sin1477;
                        accout_cos697 <= tempAcc_cos697;
                        accout_cos941 <= tempAcc_cos941;
                        accout_cos1477<= tempAcc_cos1477;
                        counter <= counter + 1;
                        state <= IDLE;
                    else
                        tempAcc_sin697 <= resize(2*tempAcc_sin697, tempAcc_sin697);
                        tempAcc_sin941 <= resize(2*tempAcc_sin941, tempAcc_sin941);
                        tempAcc_sin1477<= resize(2*tempAcc_sin1477, tempAcc_sin1477);
                        tempAcc_cos697 <= resize(2*tempAcc_cos697, tempAcc_cos697);
                        tempAcc_cos941 <= resize(2*tempAcc_cos941, tempAcc_cos941);
                        tempAcc_cos1477<= resize(2*tempAcc_cos1477, tempAcc_cos1477);
                        state <= STORE;
                    end if;
                
                when STORE =>
                    acc_sin697 <= tempAcc_sin697;
                    acc_sin941 <= tempAcc_sin941;
                    acc_sin1477<= tempAcc_sin1477;
                    acc_cos697 <= tempAcc_cos697;
                    acc_cos941 <= tempAcc_cos941;
                    acc_cos1477<= tempAcc_cos1477;

                        -- Inisialisasi Accumulator menjadi 0 lagi
                    accout_sin697 <= (others => '0');
                    accout_sin941 <= (others => '0');
                    accout_sin1477<= (others => '0');
                    accout_cos697 <= (others => '0');
                    accout_cos941 <= (others => '0');
                    accout_cos1477<= (others => '0');
                    counter <= 0;
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