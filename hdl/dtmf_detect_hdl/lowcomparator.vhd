library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity lowcomparator is
    Port (
        clk, rst            : in STD_LOGIC;
        in_valid    : in STD_LOGIC;
        out_ready   : in STD_LOGIC;
        in_ready    : out STD_LOGIC;
        out_valid   : out STD_LOGIC;
        input697            : in STD_LOGIC_VECTOR(16 downto 0);
        input770            : in STD_LOGIC_VECTOR(16 downto 0);
        input852            : in STD_LOGIC_VECTOR(16 downto 0);
        input941            : in STD_LOGIC_VECTOR(16 downto 0);
        code                : out STD_LOGIC_VECTOR (2 downto 0)
    );
end lowcomparator;
    

architecture Behavioral of lowcomparator is
    type state_type is (IDLE, COMPUTE, STORE);
    --signal temp1, temp2, out_temp : STD_LOGIC_VECTOR(16 downto 0);
    signal state    : state_type;
    signal code_temp: STD_LOGIC_VECTOR(2 downto 0);

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
                    if input697 > input770 and input697 > input852 and input697 > input941 then
                        code_temp <= "001"; 
                    elsif input770 > input697 and input770 > input852 and input770 > input941 then
                        code_temp <= "010"; 
                    elsif input852 > input697 and input852 > input770 and input852 > input941 then
                        code_temp <= "011"; 
                    elsif input941 > input697 and input941 > input770 and input941 > input852 then
                        code_temp <= "100";  
                    else
                        --out_temp <= (others => '0'); -- Equal case, could also set to either input1 or input2
                        code_temp <= "000"; -- Code for equality
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
