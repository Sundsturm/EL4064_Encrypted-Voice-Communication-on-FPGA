library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity Goertzel_top is
    generic (
        DATA_WIDTH : integer := 16;
        BLOCK_SIZE : integer := 640
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        
        -- Input bus signals
        in_ready : out std_logic;  -- This is an output because we tell upstream when we're ready
        in_valid : in std_logic;
        DTMF_sig : in std_logic_vector(DATA_WIDTH-1 DOWNTO 0);

        -- Output bus signals
        out_ready : in std_logic;
        out_valid : buffer std_logic;
        power_697    : out std_logic_vector(DATA_WIDTH  downto 0);
        power_770    : out std_logic_vector(DATA_WIDTH  downto 0);
        power_852    : out std_logic_vector(DATA_WIDTH  downto 0);
        power_941    : out std_logic_vector(DATA_WIDTH  downto 0);
        power_1209   : out std_logic_vector(DATA_WIDTH  downto 0);
        power_1336   : out std_logic_vector(DATA_WIDTH  downto 0);
        power_1477   : out std_logic_vector(DATA_WIDTH  downto 0)
    );
end Goertzel_top;

architecture rtl of Goertzel_top is
    constant COEFF_697      : real    := 1.98113868088715; -- For frequency 697 Hz
    constant COEFF_770      : real    := 1.97537668119028; -- For frequency 770 Hz
    constant COEFF_852      : real    := 1.96885313617978;
    constant COEFF_941      : real    := 1.96530655866142;
    constant COEFF_1209     : real    := 1.94006250638909;
    constant COEFF_1336     : real    := 1.93014734462309;
    constant COEFF_1477     : real    := 1.91388067146442;

    -- Individual ready/valid signals
    signal ready_697, ready_770, ready_852, ready_941 : std_logic;
    signal ready_1209, ready_1336, ready_1477 : std_logic;
    signal valid_697, valid_770, valid_852, valid_941 : std_logic;
    signal valid_1209, valid_1336, valid_1477 : std_logic;

begin
    -- Top-level ready is high only when all filters are ready
    in_ready <= ready_697 and ready_770 and ready_852 and ready_941 and 
                ready_1209 and ready_1336 and ready_1477;
    
    -- Top-level valid is high only when all filters are valid
    out_valid <= valid_697 and valid_770 and valid_852 and valid_941 and 
                 valid_1209 and valid_1336 and valid_1477;

    GOERTZEL_697 : entity work.Goertzel(rtl)
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        BLOCK_SIZE => BLOCK_SIZE,
        COEFF      => COEFF_697 
    )
    port map (
        clk => clk,
        rst => rst,
        in_valid => in_valid,
        DTMF_sig => DTMF_sig,
        out_ready => out_ready,
        in_ready => ready_697,    -- Output from filter
        out_valid => valid_697,   -- Output from filter
        power => power_697
    );

    GOERTZEL_770 : entity work.Goertzel(rtl)
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        BLOCK_SIZE => BLOCK_SIZE,
        COEFF      => COEFF_770 
    )
    port map (
        clk => clk,
        rst => rst,
        in_valid => in_valid,
        DTMF_sig => DTMF_sig,
        out_ready => out_ready,
        in_ready => ready_770,
        out_valid => valid_770,
        power => power_770
    );

    GOERTZEL_852 : entity work.Goertzel(rtl)
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        BLOCK_SIZE => BLOCK_SIZE,
        COEFF      => COEFF_852 
    )
    port map (
        clk => clk,
        rst => rst,
        in_valid => in_valid,
        DTMF_sig => DTMF_sig,
        out_ready => out_ready,
        in_ready => ready_852,
        out_valid => valid_852,
        power => power_852
    );

    GOERTZEL_941 : entity work.Goertzel(rtl)
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        BLOCK_SIZE => BLOCK_SIZE,
        COEFF      => COEFF_941 
    )
    port map (
        clk => clk,
        rst => rst,
        in_valid => in_valid,
        DTMF_sig => DTMF_sig,
        out_ready => out_ready,
        in_ready => ready_941,
        out_valid => valid_941,
        power => power_941
    );

    GOERTZEL_1209 : entity work.Goertzel(rtl)
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        BLOCK_SIZE => BLOCK_SIZE,
        COEFF      => COEFF_1209 
    )
    port map (
        clk => clk,
        rst => rst,
        in_valid => in_valid,
        DTMF_sig => DTMF_sig,
        out_ready => out_ready,
        in_ready => ready_1209,
        out_valid => valid_1209,
        power => power_1209
    );

    GOERTZEL_1336 : entity work.Goertzel(rtl)
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        BLOCK_SIZE => BLOCK_SIZE,
        COEFF      => COEFF_1336 
    )
    port map (
        clk => clk,
        rst => rst,
        in_valid => in_valid,
        DTMF_sig => DTMF_sig,
        out_ready => out_ready,
        in_ready => ready_1336,
        out_valid => valid_1336,
        power => power_1336
    );

    GOERTZEL_1477 : entity work.Goertzel(rtl)
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        BLOCK_SIZE => BLOCK_SIZE,
        COEFF      => COEFF_1477 
    )
    port map (
        clk => clk,
        rst => rst,
        in_valid => in_valid,
        DTMF_sig => DTMF_sig,
        out_ready => out_ready,
        in_ready => ready_1477,
        out_valid => valid_1477,
        power => power_1477
    );

end architecture;