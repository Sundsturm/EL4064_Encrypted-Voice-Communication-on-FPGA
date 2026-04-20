library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;  -- Library for numeric operations
library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity slidingv5 is
    generic(
        in_INT_BITS: natural        := 10;
        in_FRAC_BITS: natural       := 6;
        out_INT_BITS: natural       := 14;
        out_FRAC_BITS: natural      := 2
    );
    Port (
        clk : in STD_LOGIC;                           -- Clock signal
        reset : in STD_LOGIC;                         -- Reset signal

        in_valid    : in STD_LOGIC;
        out_ready   : in STD_LOGIC;
        in_ready    : out STD_LOGIC;
        out_valid   : out STD_LOGIC;

        in_697 : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);             -- SFIXED input data
        in_941 : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);             -- SFIXED input data
        in_1477: in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);             -- SFIXED input data
        
        sum_697 : out SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);         -- SFIXED output for the sum697
        sum_941 : out SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);        -- SFIXED output for the sum697
        sum_1477: out SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS)         -- SFIXED output for the sum697
    );
end slidingv5;

architecture Behavioral of slidingv5 is
    type state_type is (IDLE, COMPUTE, STORE);
    signal state            : state_type;

    type cbuffer_697 is array (0 to 19) of SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);
    signal cbuffer697 : cbuffer_697;
    type cbuffer_941 is array (0 to 19) of SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);
    signal cbuffer941 : cbuffer_941;
    type cbuffer_1477 is array (0 to 19) of SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);
    signal cbuffer1477 : cbuffer_1477;
    
    signal index : integer range 0 to 19 := 0;  -- Index to manage buffer
    signal sum697, sum941, sum1477 : SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS) := (others => '0');

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
            cbuffer697 <= (others => (others => '0'));
            cbuffer941 <= (others => (others => '0'));
            cbuffer1477<= (others => (others => '0'));
            index <= 0;
            sum697 <= (others => '0');
            sum941 <= (others => '0');
            sum1477<= (others => '0');
        elsif rising_edge(clk) then
            state <= state;
            case state is
                when IDLE =>
                    -- Write new data and update the index
                    cbuffer697(index) <= resize(in_697, 13, -2);
                    cbuffer941(index) <= resize(in_941, 13, -2);
                    cbuffer1477(index) <= resize(in_1477, 13, -2);
                    
                    out_valid <= '0';
                    if in_valid = '1' then
                        state <= COMPUTE;
                    else
                        state <= IDLE;
                    end if;

                when COMPUTE =>
                    -- Recalculate the sum697 of all elements in the buffer
                    sum697 <= resize(cbuffer697(0) + cbuffer697(1) + cbuffer697(2) + cbuffer697 (3) + cbuffer697(4) + cbuffer697(5) + cbuffer697(6) + cbuffer697(7) + cbuffer697(8) + cbuffer697(9) + cbuffer697(10) + cbuffer697 (11) + cbuffer697(12) + cbuffer697(13) + cbuffer697(14) + cbuffer697 (15) + cbuffer697(16) + cbuffer697(17) + cbuffer697(18) + cbuffer697 (19),sum697);
                    sum941 <= resize(cbuffer941(0) + cbuffer941(1) + cbuffer941(2) + cbuffer941 (3) + cbuffer941(4) + cbuffer941(5) + cbuffer941(6) + cbuffer941(7) + cbuffer941(8) + cbuffer941(9) + cbuffer941(10) + cbuffer941 (11) + cbuffer941(12) + cbuffer941(13) + cbuffer941(14) + cbuffer941 (15) + cbuffer941(16) + cbuffer941(17) + cbuffer941(18) + cbuffer941 (19),sum941);
                    sum1477 <= resize(cbuffer1477(0) + cbuffer1477(1) + cbuffer1477(2) + cbuffer1477 (3) + cbuffer1477(4) + cbuffer1477(5) + cbuffer1477(6) + cbuffer1477(7) + cbuffer1477(8) + cbuffer1477(9) + cbuffer1477(10) + cbuffer1477 (11) + cbuffer1477(12) + cbuffer1477(13) + cbuffer1477(14) + cbuffer1477 (15) + cbuffer1477(16) + cbuffer1477(17) + cbuffer1477(18) + cbuffer1477 (19),sum1477);
                    index <= (index + 1) mod 20;
                    state <= STORE;

                when STORE =>
                    sum_697 <= sum697;
                    sum_941 <= sum941;
                    sum_1477 <= sum1477;
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