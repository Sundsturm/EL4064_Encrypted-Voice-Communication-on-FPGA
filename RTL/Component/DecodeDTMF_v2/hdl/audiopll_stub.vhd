-- =============================================================================
-- audiopll_stub.vhd
-- Simulation stub for Quartus Platform Designer AudioPLL IP.
-- Provides both the PACKAGE (for "use audiopll.AudioPLL") AND
-- the ENTITY (for "entity audiopll.AudioPLL port map(...)").
-- Compile into library "audiopll" BEFORE Audio_interface.vhd.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

-- Package stub (required by: use audiopll.AudioPLL;)
package AudioPLL is
end package AudioPLL;

-- Entity stub (required by: entity audiopll.AudioPLL port map(...))
library ieee;
use ieee.std_logic_1164.all;

entity AudioPLL is
    port (
        refclk   : in  std_logic := '0';
        rst      : in  std_logic := '0';
        outclk_0 : out std_logic
    );
end entity AudioPLL;

architecture sim of AudioPLL is
begin
    -- Simple pass-through for simulation (no actual PLL behavior)
    outclk_0 <= refclk;
end architecture sim;
