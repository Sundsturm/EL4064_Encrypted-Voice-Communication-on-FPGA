library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;  -- Library for numeric operations
library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity flaggingv2 is
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
        
        in_941      : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);             -- SFIXED input data
        in_1477     : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);             -- SFIXED input data
        onoff_mark      : out std_logic
    );
end flaggingv2;

architecture Behavioral of flaggingv2 is
    type state_type is (IDLE, COMPUTE, STORE);
    signal state : state_type;

    type cbuffer_941 is array (0 to 24) of SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
    signal cbuffer941 : cbuffer_941;
    type cbuffer_1477 is array (0 to 24) of SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
    signal cbuffer1477 : cbuffer_1477;
    
    signal index : integer range 0 to 24 := 0;  -- Index to manage buffer
    signal counter : integer range 0 to 5 := 0;
    signal full     : STD_LOGIC;
    signal new941, new1477 : SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
    signal old_941,old_1477  : SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
   
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
            state       <= IDLE;
            cbuffer941  <= (others => (others => '0'));
            cbuffer1477 <= (others => (others => '0'));
            index       <= 0;
            counter     <= 0;
            onoff_mark      <= '0';
            full        <= '0';
            new941     <= (others => '0');
            new1477    <= (others => '0');
            old_941     <= (others => '0');
            old_1477    <= (others => '0');
        elsif rising_edge(clk) then
            state <= state;
            case state is
                when IDLE =>
                    out_valid <= '1';
                    if in_valid = '1' then
                        new941     <= in_941;
                        new1477    <= in_1477;
                        old_941 <= resize(3*cbuffer941(index), old_941);
                        old_1477 <= resize(3*cbuffer1477(index), old_1477);    
                        state <= COMPUTE;
                    else
                        state <= IDLE;
                    end if;

                when COMPUTE => 
                    out_valid <= '0';    
                    if full = '1' then
                        if new941 > old_941 and new1477 > old_1477 then
                            counter <= counter + 1;
                        else
                            counter <= 0;
                        end if;
                    end if;              
                    
                    state <= STORE;

                when STORE =>
                    cbuffer941(index)   <= in_941;
                    cbuffer1477(index)  <= in_1477;
                    if index = 24 then
                        full <= '1';
                    end if;
                    if counter < 5 then
                        counter <= counter;
                    else
                        onoff_mark <= '1';
                        counter <= 0;
                    end if;

                    if out_ready = '1' then
                        state <= IDLE;
                        index <= (index + 1) mod 25;
                    end if;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;
end Behavioral;
