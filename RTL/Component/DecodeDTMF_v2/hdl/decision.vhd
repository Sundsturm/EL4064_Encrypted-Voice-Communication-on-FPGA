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

-- Standard DTMF 4x4 mapping (matches decision.m natural hex encoding):
--         1209Hz  1336Hz  1477Hz  1633Hz
-- 697Hz :   1(0x1)  2(0x2)  3(0x3)  A(0xA)
-- 770Hz :   4(0x4)  5(0x5)  6(0x6)  B(0xB)
-- 852Hz :   7(0x7)  8(0x8)  9(0x9)  C(0xC)
-- 941Hz :   *(0xE)  0(0x0)  #(0xF)  D(0xD)
--
-- code_low  : "001"=697Hz, "010"=770Hz, "011"=852Hz, "100"=941Hz
-- code_high : "001"=1209Hz, "010"=1336Hz, "011"=1477Hz, "100"=1633Hz

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
            codelow   <= "000";
            codehigh  <= "000";
            sevseg    <= "1111111";
        elsif rising_edge(clk) then
            state <= state;
            anode <= '0';
            case state is
                when IDLE =>
                    out_valid <= '0';
                    if in_valid = '1' then
                        codelow  <= code_low;
                        codehigh <= code_high;
                        state    <= COMPUTE;
                    else
                        state <= IDLE;
                    end if;

                when COMPUTE =>
                    -- Full 16-symbol DTMF mapping (natural hex encoding, matches decision.m)
                    -- Row 1: 697 Hz (code_low = "001")
                    if    codelow = "001" and codehigh = "001" then
                        code_temp <= "0001"; sevseg <= "1111001"; -- '1' -> 0x1
                    elsif codelow = "001" and codehigh = "010" then
                        code_temp <= "0010"; sevseg <= "0100100"; -- '2' -> 0x2
                    elsif codelow = "001" and codehigh = "011" then
                        code_temp <= "0011"; sevseg <= "0110000"; -- '3' -> 0x3
                    elsif codelow = "001" and codehigh = "100" then
                        code_temp <= "1010"; sevseg <= "0001000"; -- 'A' -> 0xA
                    -- Row 2: 770 Hz (code_low = "010")
                    elsif codelow = "010" and codehigh = "001" then
                        code_temp <= "0100"; sevseg <= "0011001"; -- '4' -> 0x4
                    elsif codelow = "010" and codehigh = "010" then
                        code_temp <= "0101"; sevseg <= "0010010"; -- '5' -> 0x5
                    elsif codelow = "010" and codehigh = "011" then
                        code_temp <= "0110"; sevseg <= "0000010"; -- '6' -> 0x6
                    elsif codelow = "010" and codehigh = "100" then
                        code_temp <= "1011"; sevseg <= "0000011"; -- 'B' -> 0xB
                    -- Row 3: 852 Hz (code_low = "011")
                    elsif codelow = "011" and codehigh = "001" then
                        code_temp <= "0111"; sevseg <= "1111000"; -- '7' -> 0x7
                    elsif codelow = "011" and codehigh = "010" then
                        code_temp <= "1000"; sevseg <= "0000000"; -- '8' -> 0x8
                    elsif codelow = "011" and codehigh = "011" then
                        code_temp <= "1001"; sevseg <= "0010000"; -- '9' -> 0x9
                    elsif codelow = "011" and codehigh = "100" then
                        code_temp <= "1100"; sevseg <= "0110001"; -- 'C' -> 0xC
                    -- Row 4: 941 Hz (code_low = "100")
                    elsif codelow = "100" and codehigh = "001" then
                        code_temp <= "1110"; sevseg <= "0111111"; -- '*' -> 0xE
                    elsif codelow = "100" and codehigh = "010" then
                        code_temp <= "0000"; sevseg <= "1000000"; -- '0' -> 0x0
                    elsif codelow = "100" and codehigh = "011" then
                        code_temp <= "1111"; sevseg <= "1001111"; -- '#' -> 0xF
                    elsif codelow = "100" and codehigh = "100" then
                        code_temp <= "1101"; sevseg <= "0100001"; -- 'D' -> 0xD
                    else
                        -- Ambiguous / no detection
                        code_temp <= "0000"; sevseg <= "1111111";
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
