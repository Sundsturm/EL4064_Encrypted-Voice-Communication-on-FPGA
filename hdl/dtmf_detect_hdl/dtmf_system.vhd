library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dtmf_system is
    generic (
        DATA_WIDTH : integer := 16;
        BLOCK_SIZE : integer := 640
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        -- Input interface
        in_valid    : in  std_logic;
        in_ready    : out std_logic;
        dtmf_input  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        -- Output interface
        out_ready   : in  std_logic;
        out_valid   : out std_logic;
        sevseg      : out std_logic_vector(6 downto 0);
        anode       : out std_logic;
        encode_out  : out std_logic_vector(23 downto 0)
    );
end entity;

architecture rtl of dtmf_system is
    -- Internal signals between Goertzel and Encoder
    signal goertzel_out_valid, encoder_in_ready : std_logic;
    signal power_697, power_770, power_852, power_941 : std_logic_vector(DATA_WIDTH downto 0);
    signal power_1209, power_1336, power_1477 : std_logic_vector(DATA_WIDTH downto 0);

begin
    -- Goertzel filter bank instance
    goertzel_inst : entity work.Goertzel_top
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        BLOCK_SIZE => BLOCK_SIZE
    )
    port map (
        clk => clk,
        rst => rst,
        in_valid => in_valid,
        in_ready => in_ready,
        DTMF_sig => dtmf_input,
        out_ready => encoder_in_ready,
        out_valid => goertzel_out_valid,
        power_697 => power_697,
        power_770 => power_770,
        power_852 => power_852,
        power_941 => power_941,
        power_1209 => power_1209,
        power_1336 => power_1336,
        power_1477 => power_1477
    );

    -- DTMF encoder instance
    encoder_inst : entity work.top_dtmfencode
    port map (
        clk => clk,
        rst => rst,
        in_valid => goertzel_out_valid,
        in_ready => encoder_in_ready,
        corr_697 => power_697,
        corr_770 => power_770,
        corr_852 => power_852,
        corr_941 => power_941,
        corr_1209 => power_1209,
        corr_1336 => power_1336,
        corr_1477 => power_1477,
        out_ready => out_ready,
        out_valid => out_valid,
        sevseg => sevseg,
        anode => anode,
        encode_out => encode_out
    );

end architecture;