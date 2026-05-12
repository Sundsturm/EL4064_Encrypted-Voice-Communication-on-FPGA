library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;  -- Library for numeric operations

entity dec_control is
    Port (
        clk         : in STD_LOGIC;
        reset       : in STD_LOGIC; 
        
        -- Bus IO
        in_valid    : in STD_LOGIC;
        out_ready   : in STD_LOGIC;
        in_ready    : out STD_LOGIC;
        out_valid   : out STD_LOGIC;

        in_valid_flag    : out STD_LOGIC;
        out_ready_flag   : out STD_LOGIC;
        in_ready_flag    : in STD_LOGIC;
        out_valid_flag   : in STD_LOGIC;

        in_valid_mark    : out STD_LOGIC;
        out_ready_mark   : out STD_LOGIC;
        in_ready_mark    : in STD_LOGIC;
        out_valid_mark   : in STD_LOGIC;
        mark_enable      : in STD_LOGIC; 

        mark_in     : in STD_LOGIC;
        mark_out    : out std_logic
    );
end dec_control;

architecture Behavioral of dec_control is
begin
    process(reset, clk)
    begin
        if reset = '1' then
            in_ready        <= '0';
            out_valid       <= '0';
            in_valid_flag   <= '0';
            out_ready_flag  <= '0';
            in_valid_mark   <= '0';
            out_ready_mark  <= '0';
            mark_out        <= '0';
        elsif rising_edge(clk) then
            if mark_enable = '1' then
                in_valid_mark   <= in_valid;
                out_ready_mark  <= out_ready;
                in_ready        <= in_ready_mark;
                out_valid       <= out_valid_mark;
                in_valid_flag   <= '0';
                out_ready_flag  <= '0';
            else
                in_valid_flag   <= in_valid;
                out_ready_flag  <= out_ready;
                in_ready        <= in_ready_flag;
                out_valid       <= out_valid_flag;
                in_valid_mark   <= '0';
                out_ready_mark  <= '0';
            end if;
            
            mark_out <= mark_in;            
        end if;
    end process;
end Behavioral;
