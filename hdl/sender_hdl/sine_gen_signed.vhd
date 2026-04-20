library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sine_gen_signed is
  generic (
    addr_bits : integer range 1 to 31 := 10; -- Determines how many samples to store
    data_bits : integer range 1 to 32 := 19  -- Determines how many bits is going to be used to represent each samples
  );
  port (
    clk : in std_logic;
    rst : in std_logic;
    phase_incr : in unsigned(31 downto 0);
    data : out signed(data_bits - 1 downto 0)
  );
end sine_gen_signed;

architecture rtl of sine_gen_signed is

  constant rom_width : integer := data_bits - 1;
  constant rom_depth : integer := 2**addr_bits;

  subtype rom_addr_range is integer range 0 to rom_depth - 1;
  subtype rom_data_type is unsigned(rom_width - 1 downto 0);
  type rom_type is array (rom_addr_range) of rom_data_type;

  -- Pre-calculates ROM values for the first quadrant of a sine wave
  -- Scaled to half range to prevent overflow when negating
  function init_rom return rom_type is
    variable rom_v : rom_type;
    variable angle : real;
    variable sin_scaled : real;
  begin
    for i in rom_addr_range loop
      angle := real(i) * ((MATH_PI/2.0) / real(rom_depth));
      -- Scale to half the maximum positive range of signed number
      sin_scaled := sin(angle) * (2.0**(rom_width-1) - 1.0);
      rom_v(i) := to_unsigned(integer(round(sin_scaled)), rom_width);
    end loop;
    return rom_v;
  end init_rom;

  constant rom : rom_type := init_rom;

  signal rom_addr : unsigned(addr_bits - 1 downto 0);
  signal rom_dout : rom_data_type;
  signal rom_data : rom_data_type;

  -- Initialize phase_acc to start at 90 degrees (0x40000000) so the sine wave starts at 0 and goes positive
  signal phase_acc : unsigned(31 downto 0) := "01000000000000000000000000000000";
  signal quadrant : unsigned(1 downto 0);
  signal quadrant_p1 : unsigned(1 downto 0);
  signal quadrant_p2 : unsigned(1 downto 0);

  function init_base_phase_acc_incr return unsigned is
    variable ret : unsigned(phase_acc'range) := (others => '0');
  begin
    ret(phase_acc'high - addr_bits - 1) := '1';
    return ret;
  end function;

  -- The lowest value to add to phase_acc that always will increment the ROM address 
  constant base_phase_acc_incr : unsigned(31 downto 0) := init_base_phase_acc_incr;

  -- Ranges for slicing the phase_acc signal
  subtype phase_acc_quadrant_range is integer range phase_acc'high downto phase_acc'high - 1;
  subtype phase_acc_addr_range is integer range phase_acc'high - 2 downto phase_acc'high - addr_bits - 1;

begin

  quadrant <= phase_acc(phase_acc_quadrant_range);

  ROM_ADDR_PROC : process(quadrant, phase_acc)
  begin
    case quadrant is
      when "01" | "11" =>
        rom_addr <= phase_acc(phase_acc_addr_range);
      when others => -- "00" OR "10"
        rom_addr <= (rom_depth - 1 - phase_acc(phase_acc_addr_range));
    end case;
  end process;

  ROM_PROC : process(clk)
  begin
    if rising_edge(clk) then
      rom_dout <= rom(to_integer(rom_addr));
    end if;
  end process;

  REG_PROC : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        quadrant_p1 <= (others => '0');
        quadrant_p2 <= (others => '0');
        rom_data <= (others => '0');
      else
        quadrant_p1 <= quadrant;
        quadrant_p2 <= quadrant_p1;
        rom_data <= rom_dout;
      end if;
    end if;
  end process;

  ACC_PROC : process(clk)
    variable acc : unsigned(phase_acc'range);
    variable rom_index : unsigned(addr_bits - 1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        phase_acc <= "01000000000000000000000000000000";  -- Reset to 90 degrees
      else
        acc := phase_acc + phase_incr;
        rom_index := acc(phase_acc_addr_range);

        if rom_index = rom_depth - 1 then
          acc := acc + base_phase_acc_incr;
        end if;

        phase_acc <= acc;
      end if;
    end if;
  end process;

  DATA_OUT_PROC : process(clk)
    variable signed_value : signed(data_bits-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        data <= (others => '0');
      else
        case quadrant_p2 is
          when "01" | "10" =>  -- Positive quadrants
            signed_value := signed('0' & rom_data);
          when others =>       -- Negative quadrants
            signed_value := -signed('0' & rom_data);
        end case;
        data <= signed_value;
      end if;
    end if;
  end process;

end architecture;