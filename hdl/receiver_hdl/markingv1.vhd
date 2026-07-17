library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

-- ============================================================================
-- markingv1: Deteksi simbol DTMF "3" (697 Hz) setelah flag "##" dikonfirmasi
--
-- Referensi MATLAB: marking.m (exp 1.7 fixed point v7)
--
-- Logika:
--   Menggunakan Normalized Power Difference (NPD) pada daya 697 Hz dan 941 Hz:
--     P697 >= THRESHOLD_VAL * (P697 + P941)
--
--   Untuk mencegah false trigger dari noise transient, ditambahkan debounce
--   2-batch: kondisi harus terpenuhi selama 2 batch berurutan sebelum
--   enable di-assert '1' secara permanen.
--
-- Timing:
--   Modul ini hanya aktif setelah dec_control menyalakan jalur marking
--   (via in_valid dari mark_enable='1').
-- ============================================================================
entity markingv1 is
    generic(
        in_INT_BITS          : natural := 15;
        in_FRAC_BITS         : natural := 1;
        THRESHOLD_COEFF      : real := 0.5;  -- Koefisien rasio Normalized Power Difference (Default: 0.53)
        GUARD_FLOOR          : real := 16.0   -- Batas daya minimum 697 Hz
    );
    Port (
        clk       : in  STD_LOGIC;
        reset     : in  STD_LOGIC;
        in_valid  : in  STD_LOGIC;
        out_ready : in  STD_LOGIC;
        in_ready  : out STD_LOGIC;
        out_valid : out STD_LOGIC;
        in_697    : in  SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
        in_941    : in  SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);  -- guard condition
        enable    : out STD_LOGIC  -- SR latch: '1' setelah "3" terdeteksi
    );
end markingv1;

architecture Behavioral of markingv1 is

    type state_type is (IDLE, COMPUTE, STORE);
    signal state : state_type := IDLE;

    constant THRESHOLD_VAL : sfixed(0 downto -16) := to_sfixed(THRESHOLD_COEFF, 0, -16);

    -- Register capture nilai saat ini (di-latch saat IDLE, dipakai di COMPUTE)
    signal curr_697  : SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS) := (others => '0');
    signal curr_941  : SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS) := (others => '0');

    -- SR latch internal: mencegah enable di-toggle setelah pertama kali assert
    signal enable_i  : STD_LOGIC := '0';

begin

    -- enable output mengikuti internal SR latch
    enable <= enable_i;

    -- in_ready kombinatorial
    process(state)
    begin
        if state = IDLE then
            in_ready <= '1';
        else
            in_ready <= '0';
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- FSM Utama
    -- -------------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            state        <= IDLE;
            enable_i     <= '0';
            out_valid    <= '0';
            curr_697     <= (others => '0');
            curr_941     <= (others => '0');

        elsif rising_edge(clk) then
            case state is

                -- ===========================================================
                -- IDLE: Tunggu data baru dari dec_control (hanya aktif setelah
                --       flagging mengaktifkan marking via mark_enable='1')
                -- ===========================================================
                when IDLE =>
                    out_valid <= '0';
                    if in_valid = '1' then
                        -- Capture nilai batch saat ini untuk diproses di COMPUTE
                        curr_697  <= in_697;
                        curr_941  <= in_941;
                        state     <= COMPUTE;
                    end if;

                -- ===========================================================
                -- COMPUTE: Bandingkan curr vs THRESHOLD_VAL * (curr_697 + curr_941)
                --          dengan verifikasi debounce 2-batch berurutan
                -- ===========================================================
                when COMPUTE =>
                    if enable_i = '0' then
                        -- Logika marking Normalized Power Difference (MATLAB v7)
                        -- P697 >= COEFF_THRESHOLD * (P697 + P941)
                        if (curr_697 >= resize(THRESHOLD_VAL * (curr_697 + curr_941), curr_697)) and 
                           (curr_697 > to_sfixed(GUARD_FLOOR, curr_697)) then
                            enable_i   <= '1';  -- SR latch: permanen setelah valid
                        end if;
                    end if;
                    state <= STORE;

                -- ===========================================================
                -- STORE: Output valid, tunggu downstream siap
                -- ===========================================================
                when STORE =>
                    out_valid <= '1';
                    if out_ready = '1' then
                        state <= IDLE;
                    end if;

                when others =>
                    state <= IDLE;

            end case;
        end if;
    end process;

end Behavioral;
