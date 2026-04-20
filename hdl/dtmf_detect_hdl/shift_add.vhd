library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity shift_add is
    Port (
        clk         : in  std_logic; -- Clock signal
        reset       : in  std_logic; -- Reset signal
        in_valid    : in STD_LOGIC;
        out_ready   : in STD_LOGIC;
        in_ready    : out STD_LOGIC;
        out_valid   : out STD_LOGIC;
        input3      : in  std_logic_vector(3 downto 0); -- Input signal
        output32    : out std_logic_vector(23 downto 0) -- Output signal
    );
end shift_add;

architecture Behavioral of shift_add is
    signal counter   : integer range 0 to 8 := 0;
    signal temp_sig  : std_logic_vector(23 downto 0) := (others => '0');
    type state_type is (IDLE, COMPUTE, STORE);
    signal state    : state_type;
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
            -- Reset all signals
            temp_sig <= (others => '0');
            counter <= 0;
            output32 <= (others => '0');
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
                    if input3(3) = '1' then
                        temp_sig <= std_logic_vector(shift_left(unsigned(temp_sig), 3));
                        temp_sig(2 downto 0) <= input3(2 downto 0);
                        counter <= counter + 1;
                    else
                        temp_sig <= temp_sig;
                        counter <= counter;
                    end if;
                    state <= STORE;

                when STORE =>
                    -- If input3(3) = '0', do nothing, just wait
                    out_valid <= '1';
                    if counter < 8 then
                        counter <= counter;
                    else
                        -- Output the temp_sig when counter is 8 or more
                        output32 <= temp_sig;
                        counter <= 0;
                    end if;
                    if out_ready = '1' then
                        state <= IDLE;
                    end if;


                when others =>
                    state <= IDLE;
            end case; 
        end if;
    end process;
end Behavioral;
