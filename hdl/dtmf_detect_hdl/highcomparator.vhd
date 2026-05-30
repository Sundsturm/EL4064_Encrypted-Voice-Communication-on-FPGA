library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity highcomparator is
    Port (
        clk, rst            : in STD_LOGIC;
        in_valid    : in STD_LOGIC;
        out_ready   : in STD_LOGIC;
        in_ready    : out STD_LOGIC;
        out_valid   : out STD_LOGIC;
        input1209           : in STD_LOGIC_VECTOR(16 downto 0);
        input1336           : in STD_LOGIC_VECTOR(16 downto 0);
        input1477           : in STD_LOGIC_VECTOR(16 downto 0);
        input1633           : in STD_LOGIC_VECTOR(16 downto 0);
        code                : out STD_LOGIC_VECTOR (2 downto 0)
    );
end highcomparator;
    

architecture Behavioral of highcomparator is
    type state_type is (IDLE, COMPUTE, STORE);
    --signal temp1, temp2, out_temp : STD_LOGIC_VECTOR(16 downto 0);
    signal state    : state_type;
    signal code_temp: STD_LOGIC_VECTOR(2 downto 0);
    
    -- Ambang batas daya (Power Threshold)
    -- Jika nilai daya tertinggi masih di bawah nilai ini, ia akan dianggap sebagai NOISE / SILENCE.
    constant THRESHOLD : STD_LOGIC_VECTOR(16 downto 0) := "00000100100000000"; -- x"003E8"

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
            --output1a <= (others => '0');
            --temp1 <= (others => '0');
            --temp2 <= (others => '0');
            --out_temp <= (others => '0');
            code <= "000";
            code_temp <= "000";
        elsif rising_edge(clk) then
            state <= state;
            case state is
                when IDLE =>
                    out_valid<= '0';
                    if in_valid = '1' then
                        state <= COMPUTE;
                    else
                        state <= IDLE;
                    end if;
                
                when COMPUTE =>
                    if (input1209 > input1336 and input1209 > input1477 and input1209 > input1633) and (input1209 > THRESHOLD) then
                        code_temp <= "001"; 
                    elsif (input1336 > input1209 and input1336 > input1477 and input1336 > input1633) and (input1336 > THRESHOLD) then
                        code_temp <= "010"; 
                    elsif (input1477 > input1209 and input1477 > input1336 and input1477 > input1633) and (input1477 > THRESHOLD) then
                        code_temp <= "011"; 
                    elsif (input1633 > input1209 and input1633 > input1336 and input1633 > input1477) and (input1633 > THRESHOLD) then
                        code_temp <= "100";
                    else
                        code_temp <= "000"; -- Code for equality / silence
                    end if;
                    state <= STORE;

                when STORE =>
                    out_valid <= '1';
                    if out_ready = '1' then
                        code <= code_temp;
                        --output1a <= out_temp;
                        state <= IDLE;
                    end if;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;
end Behavioral;
