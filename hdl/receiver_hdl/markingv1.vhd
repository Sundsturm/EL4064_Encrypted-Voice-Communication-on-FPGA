library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;  -- Library for numeric operations
library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity markingv1 is
    generic(
        in_INT_BITS: natural        := 14;
        in_FRAC_BITS: natural       := 2
    );
    Port (
        clk         : in STD_LOGIC;                           -- Clock signal
        reset       : in STD_LOGIC;                         -- Reset signal
        in_valid    : in STD_LOGIC;
        out_ready   : in STD_LOGIC;
        in_ready    : out STD_LOGIC;
        out_valid   : out STD_LOGIC;

        in_697      : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);             -- SFIXED input data
        enable      : out std_logic
    );
end markingv1;

architecture Behavioral of markingv1 is
    type state_type is (IDLE, COMPUTE, STORE);
    signal state : state_type;
    signal counter : integer range 0 to 5 := 0;
    signal max697 : SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS) := (others => '0');
    
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
            counter     <= 0;
            enable      <= '0';
            max697     <= (others => '0');
        elsif rising_edge(clk) then
            state       <= state;
            case state is
                when IDLE =>
                    out_valid <= '0';
                    if in_valid = '1' then
                        if counter < 5 then
                            state <= COMPUTE;
                        else
                            state <= STORE;
                        end if;
                    else
                        state <= IDLE;
                    end if;
                 
                when COMPUTE =>
                    if max697 > in_697 then
                        max697  <= max697;
                        counter <= counter + 1;
                    else
                        max697 <= in_697;
                        counter  <= 0;
                    end if;
                    state <= STORE;
                      
                when STORE =>
                    if counter < 5 then
                        counter  <= counter;
                    else
                        enable <= '1';
                        counter <= counter;
                    end if;
                    out_valid <= '1';
                    state <= IDLE;
                    
                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;
end Behavioral;
