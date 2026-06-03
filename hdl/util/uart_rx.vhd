library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    generic (
        -- Untuk Clock 50 MHz dan Baud Rate 115200 bps
        -- Clocks per bit = 50,000,000 / 115200 = 434
        CLKS_PER_BIT : integer := 434
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        rx        : in  std_logic;
        data_out  : out std_logic_vector(7 downto 0);
        rx_valid  : out std_logic
    );
end uart_rx;

architecture rtl of uart_rx is

    type state_type is (ST_IDLE, ST_START, ST_DATA, ST_STOP, ST_CLEANUP);
    signal current_state : state_type := ST_IDLE;

    signal clk_count : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal bit_index : integer range 0 to 7 := 0;
    signal rx_data   : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_sync_1 : std_logic := '1';
    signal rx_sync_2 : std_logic := '1';

begin

    -- Double-register the async rx signal to prevent metastability
    process(clk)
    begin
        if rising_edge(clk) then
            rx_sync_1 <= rx;
            rx_sync_2 <= rx_sync_1;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= ST_IDLE;
                clk_count <= 0;
                bit_index <= 0;
                rx_data <= (others => '0');
                rx_valid <= '0';
                data_out <= (others => '0');
            else
                case current_state is
                    when ST_IDLE =>
                        rx_valid <= '0';
                        clk_count <= 0;
                        bit_index <= 0;
                        
                        if rx_sync_2 = '0' then -- Start bit detected
                            current_state <= ST_START;
                        end if;

                    when ST_START =>
                        if clk_count = (CLKS_PER_BIT-1)/2 then
                            if rx_sync_2 = '0' then -- Confirm still low
                                clk_count <= 0;
                                current_state <= ST_DATA;
                            else
                                current_state <= ST_IDLE;
                            end if;
                        else
                            clk_count <= clk_count + 1;
                        end if;

                    when ST_DATA =>
                        if clk_count = CLKS_PER_BIT-1 then
                            clk_count <= 0;
                            rx_data(bit_index) <= rx_sync_2;
                            if bit_index < 7 then
                                bit_index <= bit_index + 1;
                            else
                                bit_index <= 0;
                                current_state <= ST_STOP;
                            end if;
                        else
                            clk_count <= clk_count + 1;
                        end if;

                    when ST_STOP =>
                        if clk_count = CLKS_PER_BIT-1 then
                            rx_valid <= '1';
                            data_out <= rx_data;
                            current_state <= ST_CLEANUP;
                            clk_count <= 0;
                        else
                            clk_count <= clk_count + 1;
                        end if;

                    when ST_CLEANUP =>
                        current_state <= ST_IDLE;
                        rx_valid <= '0';

                    when others =>
                        current_state <= ST_IDLE;
                end case;
            end if;
        end if;
    end process;

end rtl;
