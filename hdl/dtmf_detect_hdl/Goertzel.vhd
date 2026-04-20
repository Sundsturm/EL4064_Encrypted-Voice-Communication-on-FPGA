library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity Goertzel is
    generic (
        DATA_WIDTH : integer := 16;
        BLOCK_SIZE : integer := 640;
        COEFF      : real := 1.98113868088715
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        -- Input bus signals
        in_ready : buffer std_logic;
        in_valid : in std_logic;
        DTMF_sig : in std_logic_vector(DATA_WIDTH-1 DOWNTO 0);

        -- Output bus signals
        out_ready : in std_logic;
        out_valid : buffer std_logic;
        power     : out std_logic_vector(DATA_WIDTH DOWNTO 0) -- 18 bit data 
    );
end Goertzel;

architecture rtl of Goertzel is
    
    -- Constant for determining the Q format (obtained from MATLAB Fixed-point tools)
    constant COEFF_INT_BITS : integer := 2;
    constant COEFF_FRAC_BITS : integer := 14;

    constant Q_INT_BITS : integer := 13;
    constant Q_FRAC_BITS : integer := 3;

    constant X_INT_BITS  : integer   := 2;
    constant X_FRAC_BITS : integer   := 14;

    constant COEFF_Q1_INT_BITS : integer := 14;
    constant COEFF_Q1_FRAC_BITS : integer := 2;

    constant X_MIN_Q2_INT_BITS : integer := 13;
    constant X_MIN_Q2_FRAC_BITS: integer := 3;

    -- Constant for calculating the sfixed representation of coeff
    constant coeff_sfixed : sfixed(COEFF_INT_BITS-1 downto -COEFF_FRAC_BITS) := to_sfixed(coeff, COEFF_INT_BITS-1, -COEFF_FRAC_BITS);
    
    --%% Declaring register %%
    -- Temporary register
    signal coeff_Q1 : sfixed(COEFF_Q1_INT_BITS-1 downto -COEFF_Q1_FRAC_BITS); -- Format: Signed Q14.2
    signal x_min_q2 : sfixed(X_MIN_Q2_INT_BITS-1 downto -X_MIN_Q2_FRAC_BITS); -- Format: Signed Q13.3
    signal Q1_squared  : ufixed(22 downto 0);
    signal Q2_squared  : ufixed(22 downto 0);
    signal coeff_Q1_Q2    : sfixed(23 downto 0);
    signal Q1_squared_plus_Q2_squared : ufixed(23 downto 0);
    signal power_fix : sfixed(17 downto 0) := (others => '0');
    -- Input sample register
    signal DTMF_sampled : sfixed(X_INT_BITS - 1 downto -X_FRAC_BITS); -- Format: Signed Q2.14
    -- Delay register
    signal Q0_reg, Q1_reg, Q2_reg   : sfixed(Q_INT_BITS-1 downto -Q_FRAC_BITS); -- Format : Signed Q13.3

    --%% Declaring signals for each combinational block %%
    --^^ Goertzel calc block^^
    -- Signals for multiplier (signed Q2.14 with signed Q13.3)
    signal mult_a : sfixed(COEFF_INT_BITS-1 downto -COEFF_FRAC_BITS); -- For coeff   
    signal mult_b : sfixed(Q_INT_BITS-1 downto -Q_FRAC_BITS); -- For Q1
    signal mult_out : sfixed(COEFF_INT_BITS + Q_INT_BITS - 1 downto -(Q_FRAC_BITS + COEFF_FRAC_BITS)); -- 32 bit

    -- Signals for substraction (signed Q2.14 with signed Q13.3)
    signal sub_a : sfixed(X_INT_BITS - 1 downto -X_FRAC_BITS); -- For DTMF signal
    signal sub_b : sfixed(Q_INT_BITS-1 downto -Q_FRAC_BITS); -- For Q2 
    signal sub_out : sfixed(Q_INT_BITS  downto -X_FRAC_BITS); -- 28 bit 
    
    -- Signals for the adder (signed Q14.2 with signed Q13.3)
    signal add_a : sfixed(COEFF_Q1_INT_BITS-1 downto -COEFF_Q1_FRAC_BITS); -- For coeff_Q1
    signal add_b : sfixed(X_MIN_Q2_INT_BITS-1 downto -X_MIN_Q2_FRAC_BITS); -- For x_min_Q2
    signal add_out : sfixed(COEFF_Q1_INT_BITS  downto -X_MIN_Q2_FRAC_BITS); -- 18 bit 

    -- ^^ Goertzel power block^^
    --Signals for squaring
    signal square_in  : sfixed(Q_INT_BITS-1 downto -Q_FRAC_BITS);
    signal square_out : ufixed(2*Q_INT_BITS-1 downto -(Q_FRAC_BITS + Q_FRAC_BITS)); -- Ouput of squaring must be 32 bit

    -- Signals for multypling coeff_Q1 with Q2
    signal mult_coeff_q1 : sfixed(COEFF_Q1_INT_BITS-1 downto -COEFF_Q1_FRAC_BITS);
    signal mult_q2       : sfixed(Q_INT_BITS-1 downto -Q_FRAC_BITS);
    signal mult_out_2    : sfixed(COEFF_Q1_INT_BITS + Q_INT_BITS - 1 downto -(COEFF_Q1_FRAC_BITS + Q_FRAC_BITS)); -- 32 bit


    -- %% Declaring counter %%
    -- Counter for determining the recursive part length
    signal counter : integer range 0 to BLOCK_SIZE - 1;
    
    --%% State machine declaration %%
    type state_type is (IDLE, COMPUTE_FILTER_1, COMPUTE_FILTER_2, COMPUTE_FILTER_3, STORE_TO_Q0, UPDATE, COMPUTE_POWER_1, COMPUTE_POWER_2, COMPUTE_POWER_3, COMPUTE_POWER_4, COMPUTE_POWER_5, OUTPUT);
    signal state : state_type;

begin
    --^^ Recursive goertzel part^^
    -- Multplication for coeff and Q1
    MULT_PROC: process(mult_a, mult_b)
    begin 
        mult_out <= mult_a * mult_b;
    end process;
    -- Subtraction of signed
    SUB_PROC: process(sub_a, sub_b) 
    begin 
        sub_out <= sub_a - sub_b;
    end process;    
    -- Addition of signed
    ADD_PROC: process(add_a, add_b) 
    begin 
        add_out <= add_a + add_b;
    end process;

    -- ^^ Power computation part^^
    -- Squaring process
    SQUARE_PROC: process(square_in)
    begin 
        square_out <= ufixed(square_in * square_in);
    end process;

    -- Multiplying coeff_Q1 with Q2
    MULT_COEFF_Q1_Q2_PROC: process(mult_coeff_q1, mult_q2)
    begin 
        mult_out_2 <= mult_coeff_q1 * mult_q2;
    end process;

    -- Main filter state machine
    GOERTZEL_PROC: process(clk, rst) 
        variable power_v : std_logic_vector(DATA_WIDTH+1 DOWNTO 0);
    begin 
        if rst = '1' then
            -- Control signal reset value
            in_ready <= '0';
            out_valid <= '0';
            state <= IDLE;
            
            -- Block counter reset value
            counter <= 0;
            
            -- Delay register reset value
            Q0_reg <= (others => '0');
            Q1_reg <= (others => '0');
            Q2_reg <= (others => '0');

            -- Temp register reset value
            Q1_squared  <= (others => '0');
            Q2_squared  <= (others => '0');
            coeff_Q1_Q2 <= (others => '0'); 
            Q1_squared_plus_Q2_squared <= (others => '0');
            power_fix   <= (others => '0');

            -- Input register reset value
            DTMF_sampled <= (others => '0');

            -- Intermediate register reset value
            coeff_Q1 <= (others => '0');
            x_min_Q2 <= (others => '0');

        elsif rising_edge(clk) then 
            case state is
                WHEN IDLE => 
                    in_ready <= '1';
                    if in_ready = '1' and in_valid = '1' then 
                        state <= COMPUTE_FILTER_1;
                        in_ready <= '0'; -- The module will not accept any input after consuming data 
                        DTMF_sampled <= to_sfixed(DTMF_sig, X_INT_BITS - 1, -X_FRAC_BITS);
                    end if; 
                WHEN COMPUTE_FILTER_1 =>
                    state <= COMPUTE_FILTER_2;
                    -- load multiplier with coeff and Q1 (multiplication of signed Q2.14)
                    mult_a <= coeff_sfixed;
                    mult_b <= Q1_reg;
                    -- load subtractor with x and Q2 
                    sub_a <= DTMF_sampled;  
                    sub_b <= Q2_reg;
                WHEN COMPUTE_FILTER_2 =>  
                    state <= COMPUTE_FILTER_3;
                    -- store multiplier and subtractor result
                    coeff_Q1 <= resize(mult_out, COEFF_Q1_INT_BITS-1, -COEFF_Q1_FRAC_BITS);
                    x_min_Q2 <= resize(sub_out, X_MIN_Q2_INT_BITS-1, -X_MIN_Q2_FRAC_BITS); 
                WHEN COMPUTE_FILTER_3 =>
                    state <= STORE_TO_Q0;
                    -- load coeff_Q1 and x_min_Q2 to adder 
                    add_a <= coeff_Q1;
                    add_b <= x_min_Q2;
                WHEN STORE_TO_Q0 =>  
                    state <= UPDATE;
                    Q0_reg <= resize(add_out, Q_INT_BITS-1, -Q_FRAC_BITS);
                WHEN UPDATE =>
                    Q2_reg <= Q1_reg;
                    Q1_reg <= Q0_reg;
                    if counter = BLOCK_SIZE - 1 then 
                        counter <= 0;
                        state <= COMPUTE_POWER_1;
                    else
                        counter <= counter + 1;
                        state <= IDLE;
                    end if;
                -- Computing power state
                WHEN COMPUTE_POWER_1 => -- Square Q1 and multiply coeff_Q1 with Q2
                    state <= COMPUTE_POWER_2;
                    square_in <= Q1_reg;
                    mult_coeff_q1 <= coeff_Q1;
                    mult_q2 <= Q2_reg;
                WHEN COMPUTE_POWER_2 => -- Store square of Q1 to temp, square Q2, and store coeff_Q1_Q2 to temporary register 
                    state <= COMPUTE_POWER_3; 
                    Q1_squared <= resize(square_out, 22, 0);
                    coeff_Q1_Q2 <= resize(mult_out_2, 23, 0);
                    square_in <= Q2_reg;
                WHEN COMPUTE_POWER_3 => -- Store Q2 to Q2 squared 
                    state <= COMPUTE_POWER_4;
                    Q2_squared <= resize(square_out, 22, 0);
                WHEN COMPUTE_POWER_4 => -- Subtract the sum of square value by coeff_q1_q2 and store the result into power_fix reg
                    state <= COMPUTE_POWER_5;
                    Q1_squared_plus_Q2_squared <= Q2_squared + Q1_squared;
                WHEN COMPUTE_POWER_5 => 
                    state <= OUTPUT;
                    power_fix <= resize(abs(sfixed(Q1_squared_plus_Q2_squared) - coeff_Q1_Q2), 17, 0);
                WHEN OUTPUT =>
                    power_v := to_std_logic_vector(power_fix);
                    power   <= power_v(16 downto 0);
                    out_valid <= '1';
                    if out_valid = '1' and out_ready = '1' then
                        state <= IDLE;
                        out_valid <= '0';
                        -- Delay register reset value
                        Q0_reg <= (others => '0');
                        Q1_reg <= (others => '0');
                        Q2_reg <= (others => '0');

                        -- Temp register reset value
                        Q1_squared  <= (others => '0');
                        Q2_squared  <= (others => '0');
                        coeff_Q1_Q2 <= (others => '0'); 
                        Q1_squared_plus_Q2_squared <= (others => '0');
                        power_fix   <= (others => '0');

                        -- Input register reset value
                        DTMF_sampled <= (others => '0');

                        -- Intermediate register reset value
                        coeff_Q1 <= (others => '0');
                        x_min_Q2 <= (others => '0');
                    end if;
            end case;
        end if;  
    end process;

end architecture;