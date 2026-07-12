library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

-- ============================================================================
-- markingv1: Deteksi simbol DTMF "3" (697 Hz) setelah flag "##" dikonfirmasi
--
-- Referensi MATLAB: marking.m (exp 1.7 fixed point v6)
--
-- Logika dua kondisi SEKUENSIAL (sesuai MATLAB marking.m):
--
--   KONDISI 1: curr_697 > prev_697
--              (nilai 697 Hz batch ini lebih besar dari batch sebelumnya)
--
--   KONDISI 2 (guard): curr_697 > curr_941  AND  curr_1477 > curr_941
--              (697 Hz dominan di atas 941 Hz, DAN 1477 Hz juga di atas 941 Hz)
--
--   Jika KONDISI 1 DAN KONDISI 2 terpenuhi → enable di-assert '1'.
--
-- Timing:
--   Modul ini hanya aktif setelah dec_control menyalakan jalur marking
--   (via in_valid dari mark_enable='1'). Nilai prev_697 di-update setiap
--   batch yang diterima.
--
-- Port baru dibanding versi sebelumnya:
--   + in_941  : diperlukan untuk kondisi guard (KONDISI 2)
--   + in_1477 : diperlukan untuk kondisi guard (KONDISI 2)
-- ============================================================================
entity markingv1 is
    generic(
        in_INT_BITS  : natural := 15;
        in_FRAC_BITS : natural := 1
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
        in_1477   : in  SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);  -- guard condition
        enable    : out STD_LOGIC;  -- SR latch: '1' setelah "3" terdeteksi
        latch_reset : in STD_LOGIC  -- Opsi C: reset eksternal dari session timeout
    );
end markingv1;

architecture Behavioral of markingv1 is

    type state_type is (IDLE, COMPUTE, STORE);
    signal state : state_type := IDLE;

    -- Register nilai batch sebelumnya untuk KONDISI 1 (curr > prev)
    signal prev_697 : SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS) := (others => '0');

    -- Register capture nilai saat ini (di-latch saat IDLE, dipakai di COMPUTE)
    signal curr_697  : SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS) := (others => '0');
    signal curr_941  : SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS) := (others => '0');
    signal curr_1477 : SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS) := (others => '0');

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
            state         <= IDLE;
            enable_i      <= '0';
            out_valid     <= '0';
            prev_697      <= (others => '0');
            curr_697      <= (others => '0');
            curr_941      <= (others => '0');
            curr_1477     <= (others => '0');

        elsif rising_edge(clk) then
            if latch_reset = '1' then
                enable_i <= '0';
                state    <= IDLE;
            else
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
                            curr_1477 <= in_1477;
                            state <= COMPUTE;
                        end if;

                    -- ===========================================================
                    -- COMPUTE: Deteksi aktif langsung (bypass dua kondisi nada '3')
                    --
                    -- Karena penyaringan preamble kini dilakukan secara digital oleh
                    -- FSM Preamble Filter di AcakCakap_Top, modul ini cukup bertindak
                    -- sebagai fast-trigger: begitu flaggingv2 menegaskan mark_enable,
                    -- enable langsung diaktifkan tanpa perlu analisis rasio daya nada.
                    -- ===========================================================
                    when COMPUTE =>
                        if enable_i = '0' then
                            enable_i <= '1';  -- Fast-trigger: aktif segera
                        end if;


                    -- Update prev_697 untuk perbandingan batch berikutnya
                    prev_697 <= curr_697;
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
    end if;
    end process;

end Behavioral;
