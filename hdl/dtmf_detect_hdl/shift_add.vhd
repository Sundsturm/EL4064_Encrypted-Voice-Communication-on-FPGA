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
        output32    : out std_logic_vector(31 downto 0) -- Output signal
    );
end shift_add;

architecture Behavioral of shift_add is
    signal counter   : integer range 0 to 8 := 0;
    signal temp_sig  : std_logic_vector(31 downto 0) := (others => '0');
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
            state <= IDLE;
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
                    temp_sig <= std_logic_vector(shift_left(unsigned(temp_sig), 4));
                    temp_sig(3 downto 0) <= input3;
                    counter <= counter + 1;
                    state <= STORE;

                when STORE =>
                    if counter = 8 then
                        output32 <= temp_sig;
                        out_valid <= '1';
                        counter <= 0;
                    else
                        out_valid <= '0';
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
