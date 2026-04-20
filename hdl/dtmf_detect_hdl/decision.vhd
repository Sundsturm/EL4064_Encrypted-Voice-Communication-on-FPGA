library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity decision is
    Port (
        clk, rst : in STD_LOGIC;
        in_valid    : in STD_LOGIC;
        out_ready   : in STD_LOGIC;
        in_ready    : out STD_LOGIC;
        out_valid   : out STD_LOGIC;
        code_low, code_high : in STD_LOGIC_VECTOR (2 downto 0);
        seg_out    : out STD_LOGIC_VECTOR(6 downto 0);
        dtmf_code : out STD_LOGIC_VECTOR (3 downto 0);
        anode    : out STD_LOGIC
    );
end decision;

architecture Behavioral of decision is
    type state_type is (IDLE, COMPUTE, STORE);
    signal state    : state_type;
    signal code_temp: STD_LOGIC_VECTOR(3 downto 0);
    signal codelow, codehigh : STD_LOGIC_VECTOR(2 downto 0);
    signal sevseg : STD_LOGIC_VECTOR(6 downto 0);
    
    
-- Notes
-- DTMF 1 = 000
-- DTMF 2 = 001
-- DTMF 4 = 010
-- DTMF 5 = 011
-- DTMF 7 = 100
-- DTMF 8 = 101
-- DTMF * = 110
-- DTMF 0 = 111

begin
    process(state)
    begin
        if state = IDLE then
            in_ready <= '1';
        else
            in_ready <= '0';
        end if;
    end process;
    process(clk, rst)
    begin
        if rst = '1' then
            -- Reset state
            dtmf_code <= "0000";
            code_temp <= "0000";
            codelow <= "000";
            codehigh <= "000";
            sevseg  <= "0000000";
        elsif rising_edge(clk) then
            state <= state;
            anode <= '0';
            case state is
                when IDLE =>
                    out_valid<= '0';
                    if in_valid = '1' then
                        codelow <= code_low;
                        codehigh <= code_high;
                        state <= COMPUTE;
                    else
                        state <= IDLE;
                    end if;
                    
                when COMPUTE =>
                    -- Normal operation
                    if codelow = "001" and codehigh = "001" then
                        code_temp   <= "1000"; -- DTMF 1
                        sevseg      <= "1111001";
                    elsif codelow = "001" and codehigh = "010" then
                        code_temp <= "1001"; -- DTMF 2
                        sevseg      <= "0100100";
                    elsif codelow = "010" and codehigh = "001" then
                        code_temp <= "1010"; -- DTMF 4
                        sevseg      <= "0011001";
                    elsif codelow = "010" and codehigh = "010" then
                        code_temp <= "1011"; -- DTMF 5
                        sevseg      <= "0010010";
                    elsif codelow = "011" and codehigh = "001" then
                        code_temp <= "1100"; -- DTMF 7
                        sevseg      <= "1111000";
                    elsif codelow = "011" and codehigh = "010" then
                        code_temp <= "1101"; -- DTMF 8
                        sevseg      <= "0000000";
                    elsif codelow = "100" and codehigh = "001" then
                        code_temp <= "1110"; -- DTMF *
                        sevseg      <= "0111111";
                    elsif codelow = "100" and codehigh = "010" then
                        code_temp <= "1111"; -- DTMF 0
                        sevseg      <= "1000000";
                    else
                        code_temp <= "0000";
                        sevseg      <= "1111111";
                    end if;
                    state <= STORE;

                when STORE =>
                    out_valid <= '1';
                    if out_ready = '1' then
                        seg_out <= sevseg;
                        dtmf_code <= code_temp;
                        state <= IDLE;
                    end if;
                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;
end Behavioral;
