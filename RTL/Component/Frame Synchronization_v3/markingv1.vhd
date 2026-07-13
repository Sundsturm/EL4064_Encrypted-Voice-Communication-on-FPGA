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
-- Logika dua kondisi SEKUENSIAL:
--
--   KONDISI 1: curr_697 > prev_697
--              (nilai 697 Hz batch ini lebih besar dari batch sebelumnya)
--
--   KONDISI 2 (guard): curr_941 < prev_941
--              (nilai 941 Hz batch ini lebih kecil dari batch sebelumnya,
--               menandakan tone 941 Hz sedang turun/transisi dari '#' ke '3')
--
--   Jika KONDISI 1 DAN KONDISI 2 terpenuhi → enable di-assert '1' (permanen).
--
-- Timing:
--   Modul ini hanya aktif setelah dec_control menyalakan jalur marking
--   (via in_valid dari mark_enable='1'). Nilai prev_697 dan prev_941 di-update
--   setiap batch yang diterima.
-- ============================================================================
entity markingv1 is
    generic(
        in_INT_BITS          : natural := 15;
        in_FRAC_BITS         : natural := 1;
        THRESHOLD_RISE_COEFF : integer := 2;  -- Faktor kenaikan 697 Hz dibanding reference
        THRESHOLD_FALL_COEFF : integer := 2;  -- Faktor penurunan 941 Hz dibanding reference
        GUARD_FLOOR          : real := 100.0  -- Batas daya minimum 697 Hz
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

    -- Nilai referensi hasil tangkapan di batch pertama (Opsi B)
    signal ref_697       : SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS) := (others => '0');
    signal ref_941       : SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS) := (others => '0');
    signal ref_captured  : STD_LOGIC := '0';

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
            ref_697      <= (others => '0');
            ref_941      <= (others => '0');
            ref_captured <= '0';

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
                        
                        -- Tangkap dan update secara dinamis (peak/floor tracking) sebelum trigger
                        if enable_i = '0' then
                            if ref_captured = '0' then
                                ref_697      <= in_697;
                                ref_941      <= in_941;
                                ref_captured <= '1';
                            else
                                -- 941 Hz track peak
                                if in_941 > ref_941 then
                                    ref_941 <= in_941;
                                end if;
                                -- 697 Hz track noise floor (minimum)
                                if in_697 < ref_697 then
                                    ref_697 <= in_697;
                                end if;
                            end if;
                        end if;
                        
                        state <= COMPUTE;
                    end if;

                -- ===========================================================
                -- COMPUTE: Bandingkan curr vs THRESHOLD*ref
                -- ===========================================================
                when COMPUTE =>
                    if enable_i = '0' then
                        -- Terapkan Opsi B (Captured Reference dengan pengali threshold)
                        if (curr_697 >= resize(THRESHOLD_RISE_COEFF * ref_697, curr_697)) and 
                           (curr_697 > to_sfixed(GUARD_FLOOR, curr_697)) and 
                           (ref_941 >= resize(THRESHOLD_FALL_COEFF * curr_941, ref_941)) then
                            enable_i <= '1';  -- SR latch: permanen
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
