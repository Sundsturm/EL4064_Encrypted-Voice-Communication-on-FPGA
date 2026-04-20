library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity toplevel_iq is
    generic(
        mult_INT_BITS:      natural := 2;
        mult_FRAC_BITS:     natural := 14;
        acc_INT_BITS:       natural := 6;
        acc_FRAC_BITS:      natural := 10;
        power_INT_BITS:     natural := 10;
        power_FRAC_BITS:    natural := 6;
        batch_INT_BITS:     natural := 14;
        batch_FRAC_BITS:    natural := 2
    );
    Port ( 
        clk, reset  : in STD_LOGIC;
        in_valid    : in STD_LOGIC;
        out_ready   : in STD_LOGIC;
        in_ready    : out STD_LOGIC;
        out_valid   : out STD_LOGIC;
        -- Bus Data
        dataA       : in std_logic_vector(15 downto 0);
        enable      : out std_logic
    );
end toplevel_iq;

architecture Behavioral of toplevel_iq is
    signal address_signal : std_logic_vector(9 downto 0);
    -- I/O signal
    signal r2r1           : STD_LOGIC;
    signal v2v1           : STD_LOGIC;
    signal r2r2           : STD_LOGIC;
    signal v2v2           : STD_LOGIC;
    signal r2r3           : STD_LOGIC;
    signal v2v3           : STD_LOGIC;
    signal r2r4           : STD_LOGIC;
    signal v2v4           : STD_LOGIC;

    -- Dari LUT Cos ke Multiplier
    signal sine_697       : std_logic_vector(15 downto 0);
    signal sine_941       : std_logic_vector(15 downto 0);
    signal sine_1477      : std_logic_vector(15 downto 0);

    -- Dari LUT Cos ke Multipleir
    signal cosine_697       : std_logic_vector(15 downto 0);
    signal cosine_941       : std_logic_vector(15 downto 0);
    signal cosine_1477      : std_logic_vector(15 downto 0);

    -- Dari multiplier ke accumulator
    signal multout_sin697    : SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
    signal multout_sin941    : SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
    signal multout_sin1477   : SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
    signal multout_cos697    : SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
    signal multout_cos941    : SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
    signal multout_cos1477   : SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);

    -- Dari Accumulator ke power
    signal accout_sin697  : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal accout_sin941  : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal accout_sin1477 : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal accout_cos697  : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal accout_cos941  : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
    signal accout_cos1477 : SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);

    -- Dari Power ke Sliding Window
    signal power_697    : SFIXED((power_INT_BITS-1) downto -power_FRAC_BITS);
    signal power_941    : SFIXED((power_INT_BITS-1) downto -power_FRAC_BITS);
    signal power_1477   : SFIXED((power_INT_BITS-1) downto -power_FRAC_BITS);

    signal sum697     : SFIXED((batch_INT_BITS-1) downto -batch_FRAC_BITS);
    signal sum941     : SFIXED((batch_INT_BITS-1) downto -batch_FRAC_BITS);
    signal sum1477    : SFIXED((batch_INT_BITS-1) downto -batch_FRAC_BITS);
    
    -- Sinyal Control Decision Block
    signal flag_invalid, flag_outready, flag_inready, flag_outvalid : STD_LOGIC;
    signal mark_invalid, mark_outready, mark_inready, mark_outvalid : STD_LOGIC;     
    signal mark_onoff : STD_LOGIC;
    signal markout : STD_LOGIC;

    -- component declarations
    component dec_control is
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
    end component;

    component flaggingv2 is
        generic(
            in_INT_BITS: natural        := 14;
            in_FRAC_BITS: natural       := 2
        );
        Port (
            clk         : in STD_LOGIC;                           -- Clock signal
            reset       : in STD_LOGIC;                         -- Reset signal
            
            in_valid    : in STD_LOGIC;
            out_ready   : in STD_LOGIC;
            in_ready    : out STD_LOGIC;
            out_valid   : out STD_LOGIC;
            
            in_941      : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);             -- SFIXED input data
            in_1477     : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);             -- SFIXED input data
            onoff_mark  : out std_logic
        );
    end component;

    component markingv1 is
        generic(
            in_INT_BITS: natural        := 14;
            in_FRAC_BITS: natural       := 2
        );
        Port (
            clk         : in STD_LOGIC;                           -- Clock signal
            reset       : in STD_LOGIC;                         -- Reset signal
            in_valid    : in STD_LOGIC;
            out_ready   : in STD_LOGIC;
            in_ready    : out STD_LOGIC;
            out_valid   : out STD_LOGIC;

            in_697      : in SFIXED(11 downto -4);             -- SFIXED input data
            enable      : out std_logic
        );
    end component;
    component slidingv5 is
        generic(
            in_INT_BITS:    natural := 10;
            in_FRAC_BITS:   natural := 6;
            out_INT_BITS:   natural := 14;
            out_FRAC_BITS:  natural := 2
        );
        Port (
            clk, reset : in STD_LOGIC;
            in_valid    : in STD_LOGIC;
            out_ready   : in STD_LOGIC;
            in_ready    : out STD_LOGIC;
            out_valid   : out STD_LOGIC;
            in_697      : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
            in_941      : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
            in_1477     : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
            sum_697     : out SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);
            sum_941     : out SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);
            sum_1477    : out SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS)
        );
    end component;

    component powercalcv1 is
        generic(
            in_INT_BITS: natural        := 6;
            in_FRAC_BITS: natural       := 10;
            out_INT_BITS: natural       := 10;
            out_FRAC_BITS: natural      := 6
        );
        Port ( 
            clk, reset : in STD_LOGIC;
            in_valid    : in STD_LOGIC;
            out_ready   : in STD_LOGIC;
            in_ready    : out STD_LOGIC;
            out_valid   : out STD_LOGIC;
            -- Framing Sin
            in_sin697   : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
            in_sin941   : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
            in_sin1477  : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
            -- Framing Cos
            in_cos697   : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
            in_cos941   : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
            in_cos1477  : in SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
            -- Hasil Power Calc
            out_697     : out SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);
            out_941     : out SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS);
            out_1477    : out SFIXED((out_INT_BITS-1) downto -out_FRAC_BITS)
        );
    end component;
    component Framingv2 is
        generic(
            data_INT_BITS: natural := 2;
            data_FRAC_BITS: natural := 14;
            acc_INT_BITS: natural := 6;
            acc_FRAC_BITS: natural := 10
        );
        Port ( 
            clk, reset : in STD_LOGIC;
            
            in_valid    : in STD_LOGIC;
            out_ready   : in STD_LOGIC;
            in_ready    : out STD_LOGIC;
            out_valid   : out STD_LOGIC;
            -- Bus Data Input
            multsin697  : in SFIXED((data_INT_BITS-1) downto -data_FRAC_BITS);
            multsin941  : in SFIXED((data_INT_BITS-1) downto -data_FRAC_BITS);
            multsin1477 : in SFIXED((data_INT_BITS-1) downto -data_FRAC_BITS);
            multcos697  : in SFIXED((data_INT_BITS-1) downto -data_FRAC_BITS);
            multcos941  : in SFIXED((data_INT_BITS-1) downto -data_FRAC_BITS);
            multcos1477 : in SFIXED((data_INT_BITS-1) downto -data_FRAC_BITS);
            
            acc_sin697  : out SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS); 
            acc_sin941  : out SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS); 
            acc_sin1477 : out SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS);
            acc_cos697  : out SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS); 
            acc_cos941  : out SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS); 
            acc_cos1477 : out SFIXED((acc_INT_BITS-1) downto -acc_FRAC_BITS) 
        );
    end component;

    component multv6 is
        generic(
            mult_INT_BITS: natural := 2;
            mult_FRAC_BITS: natural := 14
        );
        Port ( 
            clk, reset  : in STD_LOGIC;

            in_valid    : in STD_LOGIC;
            out_ready   : in STD_LOGIC;
            in_ready    : out STD_LOGIC;
            out_valid   : out STD_LOGIC;

            -- Bus Data Input
            dataA       : in std_logic_vector(15 downto 0);
            sin697      : in std_logic_vector(15 downto 0);
            sin941      : in std_logic_vector(15 downto 0);
            sin1477     : in std_logic_vector(15 downto 0);
            cos697      : in std_logic_vector(15 downto 0);
            cos941      : in std_logic_vector(15 downto 0);
            cos1477     : in std_logic_vector(15 downto 0);

            -- Bus Data Output
            multsin_697 : out SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
            multsin_941 : out SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
            multsin_1477: out SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
            multcos_697 : out SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
            multcos_941 : out SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
            multcos_1477: out SFIXED((mult_INT_BITS-1) downto -mult_FRAC_BITS);
            address     : out STD_LOGIC_VECTOR(9 downto 0)
        );
    end component;

    component lutsin_block is
        Port (
            address      : in  std_logic_vector(9 downto 0);                    -- 640 alamat
            sine_697     : out std_logic_vector(15 downto 0);  -- Format: 1.0.15
            sine_941     : out std_logic_vector(15 downto 0);  -- Format: 1.0.15
            sine_1477    : out std_logic_vector(15 downto 0)  -- Format: 1.0.15
        );
    end component;

    component lutcos_block is
        Port (
            address      : in  std_logic_vector(9 downto 0);                    -- 640 alamat
            cosine_697     : out std_logic_vector(15 downto 0);  -- Format: 1.0.15
            cosine_941     : out std_logic_vector(15 downto 0);  -- Format: 1.0.15
            cosine_1477    : out std_logic_vector(15 downto 0)  -- Format: 1.0.15
        );
    end component;

begin
    cntrl_unit  : component dec_control
        port map(
            clk         => clk,
            reset       => reset,
            in_valid    => v2v4,
            out_ready   => out_ready,
            in_ready    => r2r4,
            out_valid   => out_valid,

            in_valid_flag   => flag_invalid,
            out_ready_flag  => flag_outready,
            in_ready_flag   => flag_inready,
            out_valid_flag  => flag_outvalid,
            
            in_valid_mark   => mark_invalid,
            out_ready_mark  => mark_outready,
            in_ready_mark   => mark_inready,
            out_valid_mark  => mark_outvalid,
            mark_enable     => mark_onoff,

            mark_in         => markout,
            mark_out        => enable
        );
    flag_unit   : component flaggingv2
        generic map(
            in_INT_BITS     => 14,
            in_FRAC_BITS    => 2
        )
        port map(
            clk         => clk,
            reset       => reset,
            
            in_valid    => flag_invalid, 
            out_ready   => flag_outready,
            in_ready    => flag_inready,
            out_valid   => flag_outvalid,
            
            in_941      => sum941,
            in_1477     => sum1477,
            onoff_mark  => mark_onoff
        );

    mark_unit   : component markingv1
        generic map(
            in_INT_BITS     => 14,
            in_FRAC_BITS    => 2
        )
        port map(
            clk         => clk,
            reset       => reset,

            in_valid    => mark_invalid,
            out_ready   => mark_outready,
            in_ready    => mark_inready,
            out_valid   => mark_outvalid,

            in_697      => sum697,
            enable      => markout
        );
    batch_unit : component slidingv5
        generic map(
            in_INT_BITS     => 10,
            in_FRAC_BITS    => 6,
            out_INT_BITS    => 14,
            out_FRAC_BITS   => 2
        )
        port map(
            clk         => clk,
            reset       => reset,
            in_valid    => v2v3,
            out_ready   => r2r4,
            in_ready    => r2r3,
            out_valid   => v2v4,

            -- Input Batch
            in_697      => power_697,
            in_941      => power_941,
            in_1477     => power_1477,
        
            -- Output Batch
            sum_697     => sum697,
            sum_941     => sum941,
            sum_1477    => sum1477
        );

    powercalc : component powercalcv1
        generic map(
            in_INT_BITS     => 6,
            in_FRAC_BITS    => 10,
            out_INT_BITS    => 10,
            out_FRAC_BITS   => 6
        )
        port map(
            clk         => clk,
            reset       => reset,
            in_valid    => v2v2,
            out_ready   => r2r3,
            in_ready    => r2r2,
            out_valid   => v2v3,

            -- Input Power Sin
            in_sin697   => accout_sin697,
            in_sin941   => accout_sin941,
            in_sin1477  => accout_sin1477,
            -- Input Power Cos
            in_cos697   => accout_cos697,
            in_cos941   => accout_cos941,
            in_cos1477  => accout_cos1477,

            -- Output Power
            out_697     => power_697,
            out_941     => power_941,
            out_1477    => power_1477
        );
    framing   : component Framingv2
        generic map(
            data_INT_BITS => 2,
            data_FRAC_BITS => 14,
            acc_INT_BITS => 6,
            acc_FRAC_BITS => 10
        )
        port map(
            clk         => clk,
            reset       => reset,
            in_valid    => v2v1,
            out_ready   => r2r2,
            in_ready    => r2r1,
            out_valid   => v2v2,

            -- Input Frame Sin
            multsin697  => multout_sin697,
            multsin941  => multout_sin941,
            multsin1477 => multout_sin1477,

            -- Input Frame Cos
            multcos697  => multout_cos697,
            multcos941  => multout_cos941,
            multcos1477 => multout_cos1477,

            -- Output Frame Sin
            acc_sin697  => accout_sin697,
            acc_sin941  => accout_sin941,
            acc_sin1477 => accout_sin1477,
            -- Output Frame Cos
            acc_cos697  => accout_cos697,
            acc_cos941  => accout_cos941,
            acc_cos1477 => accout_cos1477

        );
    mult_unit : component multv6
        generic map (
            mult_INT_BITS   => 2,
            mult_FRAC_BITS  => 14
        )
        port map (
            clk             => clk,
            reset           => reset,
            -- Port IO Bus Multiplier
            in_valid        => in_valid,
            out_ready       => r2r1,
            in_ready        => in_ready,
            out_valid       => v2v1,

            -- Input Multiplier
            dataA           => dataA,
            -- Input Multiplier Sin
            sin697          => sine_697,
            sin941          => sine_941,
            sin1477         => sine_1477,
            -- Input Multiplier Cos
            cos697          => cosine_697,
            cos941          => cosine_941,
            cos1477         => cosine_1477,

            -- Output Multiplier Sin
            multsin_697     => multout_sin697,
            multsin_941     => multout_sin941,
            multsin_1477    => multout_sin1477,
            -- Output Multiplier Cos
            multcos_697     => multout_cos697,
            multcos_941     => multout_cos941,
            multcos_1477    => multout_cos1477,
            address         => address_signal
        );
    lutsin_unit: component lutsin_block
        port map (
            address      => address_signal,
            sine_697     => sine_697,
            sine_941     => sine_941,
            sine_1477    => sine_1477
        );
    lutcos_unit: component lutcos_block
        port map (
            address      => address_signal,
            cosine_697   => cosine_697,
            cosine_941   => cosine_941,
            cosine_1477  => cosine_1477
        );
end Behavioral;