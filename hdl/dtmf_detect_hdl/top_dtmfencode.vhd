library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity top_dtmfencode is
    Port (
        clk, rst        : in  STD_LOGIC;                    -- Reset signal
        in_valid        : in STD_LOGIC;
        in_ready        : out STD_LOGIC;
        corr_697        : in STD_LOGIC_VECTOR(16 downto 0);
        corr_770        : in STD_LOGIC_VECTOR(16 downto 0);
        corr_852        : in STD_LOGIC_VECTOR(16 downto 0);
        corr_941        : in STD_LOGIC_VECTOR(16 downto 0);
        corr_1209 : in STD_LOGIC_VECTOR(16 downto 0);
        corr_1336 : in STD_LOGIC_VECTOR(16 downto 0);
        corr_1477 : in STD_LOGIC_VECTOR(16 downto 0);
        corr_1633 : in STD_LOGIC_VECTOR(16 downto 0);
        out_ready   : in STD_LOGIC;
        out_valid       : out STD_LOGIC;
        sevseg          : out STD_LOGIC_VECTOR(6 downto 0);
        anode           : out STD_LOGIC;
        encode_out      : out STD_LOGIC_VECTOR(31 downto 0);
        dtmf_code_4bit  : out STD_LOGIC_VECTOR(3 downto 0);
        dtmf_code_valid : out STD_LOGIC
    );
end top_dtmfencode;

architecture Behavioral of top_dtmfencode is
    signal r2r1, v2vh, v2vl                         : STD_LOGIC;
    signal r2r2, v2v2, v2v3                         : STD_LOGIC;
    signal lowready, highready                      : STD_LOGIC;
    -- Signal Out tiap blok
    signal codelow, codehigh                        : STD_LOGIC_VECTOR(2 downto 0);    
    signal code_dtmf                                : STD_LOGIC_VECTOR(3 downto 0);  
    signal tone_valid                               : STD_LOGIC;
    signal framed_key                               : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal payload_shift                            : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal frame_done                               : STD_LOGIC := '0';
    signal payload_count                            : integer range 0 to 8 := 0;
    type frame_state_type is (WAIT_HASH, GOT_HASH, GOT_HASH_HASH, GOT_HASH_THREE, COLLECT_PAYLOAD);
    signal frame_state                              : frame_state_type := WAIT_HASH;
    -- Componen Declarations
    component lowcomparator is
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
    end component;

    component highcomparator is
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
    end component;

    component decision is
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
    end component;
    
    component shift_add is
        Port (
        clk, reset                : in  STD_LOGIC;
        in_valid    : in STD_LOGIC;
        out_ready   : in STD_LOGIC;
        in_ready    : out STD_LOGIC;
        out_valid   : out STD_LOGIC;                    -- Reset signal
        input3                  : in  STD_LOGIC_VECTOR(3 downto 0);  -- 4-bit input
        output32                : out STD_LOGIC_VECTOR(31 downto 0)   -- 32-bit output
        );
    end component;

begin
    in_ready <= lowready and highready;
    v2v2     <= v2vl and v2vh;
    dtmf_code_4bit <= code_dtmf;
    tone_valid <= '1' when (v2v3 = '1' and codelow /= "000" and codehigh /= "000") else '0';
    dtmf_code_valid <= tone_valid;
    encode_out <= framed_key;
    out_valid <= frame_done;
    r2r1 <= '1';

    FRAME_COLLECTOR : process(clk, rst)
        variable next_payload : STD_LOGIC_VECTOR(31 downto 0);
    begin
        if rst = '1' then
            framed_key <= (others => '0');
            payload_shift <= (others => '0');
            payload_count <= 0;
            frame_state <= WAIT_HASH;
            frame_done <= '0';
        elsif rising_edge(clk) then
            frame_done <= '0';
            if tone_valid = '1' then
                case frame_state is
                    when WAIT_HASH =>
                        if code_dtmf = x"F" then
                            frame_state <= GOT_HASH;
                        end if;

                    when GOT_HASH =>
                        if code_dtmf = x"F" then
                            frame_state <= GOT_HASH_HASH;
                        elsif code_dtmf = x"3" then
                            -- Also accept the shortened #,3,# view if the first
                            -- repeated # was consumed while the receiver was settling.
                            frame_state <= GOT_HASH_THREE;
                        else
                            frame_state <= WAIT_HASH;
                        end if;

                    when GOT_HASH_HASH =>
                        if code_dtmf = x"3" then
                            frame_state <= GOT_HASH_THREE;
                        elsif code_dtmf = x"F" then
                            frame_state <= GOT_HASH_HASH;
                        else
                            frame_state <= WAIT_HASH;
                        end if;

                    when GOT_HASH_THREE =>
                        if code_dtmf = x"F" then
                            payload_shift <= (others => '0');
                            payload_count <= 0;
                            frame_state <= COLLECT_PAYLOAD;
                        else
                            frame_state <= WAIT_HASH;
                        end if;

                    when COLLECT_PAYLOAD =>
                        next_payload := payload_shift(27 downto 0) & code_dtmf;
                        payload_shift <= next_payload;
                        if payload_count = 7 then
                            framed_key <= next_payload;
                            frame_done <= '1';
                            payload_count <= 0;
                            frame_state <= WAIT_HASH;
                        else
                            payload_count <= payload_count + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;
    -- Instance of comparator for frequency 697 and 770 Hz
    comp_low : component lowcomparator
        port map(
            clk     => clk ,
            rst     => rst ,
            in_valid        => in_valid,
            out_ready       => r2r2,
            in_ready        => lowready,
            out_valid       => v2vl,
            input697  => corr_697,
            input770  => corr_770,
            input852  => corr_852,
            input941  => corr_941,
            code    => codelow
        );
    
    comp_high : component highcomparator
        port map(
            clk         => clk,
            rst         => rst,
            in_valid => in_valid,
            out_ready => out_ready,
            in_ready => highready,
            out_valid => v2vh,
            input1209 => corr_1209,
            input1336 => corr_1336,
            input1477 => corr_1477,
            input1633 => corr_1633,
            code => codehigh
        );
    
    
    dec_DTMF : component decision
        port map(
            clk         => clk,
            rst         => rst,
            in_valid    => v2v2,
            out_ready   => r2r1,
            in_ready    => r2r2,
            out_valid   => v2v3,
            code_low    => codelow,
            code_high   => codehigh,
            anode       => anode,
            seg_out     => sevseg,
            dtmf_code   => code_dtmf
        );
    
end Behavioral;
