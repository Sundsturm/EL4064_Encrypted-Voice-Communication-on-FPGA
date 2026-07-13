library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

-- ============================================================================
-- flaggingv2: Deteksi dua simbol "#" berurutan (941 Hz dan 1477 Hz)
--
-- Referensi MATLAB: flagging.m (exp 1.7 fixed point v6)
--
-- Logika:
--   Dua counter INDEPENDEN (count_941 dan count_1477), masing-masing naik
--   jika curr >= THRESHOLD_COEFF * prev_lookback_lalu. Jika salah satu gagal, hanya
--   counter yang gagal yang di-reset (tidak keduanya).
--
--   Setelah count_941 >= 5 DAN count_1477 >= 5 (masing-masing independen),
--   onoff_mark di-assert '1' secara permanen (SR latch — tidak pernah kembali
--   ke '0' kecuali reset global/master) untuk mengaktifkan modul marking.
--
-- Buffer:
--   Circular buffer dengan ukuran LOOKBACK_DEPTH + 1 slot (index 0..LOOKBACK_DEPTH)
--   memberikan delay lookback sesuai konfigurasi.
--   Mulai membandingkan setelah buffer penuh (full='1', setelah all slots terisi).
-- ============================================================================
entity flaggingv2 is
    generic(
        in_INT_BITS     : natural := 15;
        in_FRAC_BITS    : natural := 1;
        LOOKBACK_DEPTH  : natural := 16; -- Default: 16 batch updates (setara 2 simbol)
        THRESHOLD_COEFF : integer := 5;   -- Default: threshold pengali 3
        GUARD_FLOOR     : real := 32.0   -- Default: guard floor set to 16
    );
    Port (
        clk          : in  STD_LOGIC;
        master_reset : in  STD_LOGIC := '0';
        reset        : in  STD_LOGIC := '0';
        in_valid     : in  STD_LOGIC;
        out_ready    : in  STD_LOGIC;
        in_ready     : out STD_LOGIC;
        out_valid    : out STD_LOGIC;
        in_941       : in  SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
        in_1477      : in  SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
        onoff_mark   : out STD_LOGIC   -- SR latch: '1' setelah "##" terdeteksi
    );
end flaggingv2;

architecture Behavioral of flaggingv2 is

    type state_type is (IDLE, COMPUTE, STORE);
    signal state : state_type := IDLE;

    -- -------------------------------------------------------------------------
    -- Circular buffer: (LOOKBACK_DEPTH + 1) slot → lookback LOOKBACK_DEPTH batch
    -- -------------------------------------------------------------------------
    type cbuf_t is array (0 to LOOKBACK_DEPTH) of SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
    signal cbuffer941  : cbuf_t := (others => (others => '0'));
    signal cbuffer1477 : cbuf_t := (others => (others => '0'));

    signal index     : integer range 0 to LOOKBACK_DEPTH := 0;
    signal full      : STD_LOGIC := '0';  -- '1' setelah buffer pertama terisi penuh

    -- -------------------------------------------------------------------------
    -- Dua counter INDEPENDEN (ref MATLAB: count_941, count_1477)
    -- Range 0..5; dibatasi agar tidak overflow
    -- -------------------------------------------------------------------------
    signal count_941  : integer range 0 to 5 := 0;
    signal count_1477 : integer range 0 to 5 := 0;

    -- SR latches per frekuensi (ref MATLAB: detect_enable_941, detect_enable_1477)
    -- Hanya bisa berubah '0'→'1', tidak pernah kembali kecuali reset
    signal detect_941  : STD_LOGIC := '0';
    signal detect_1477 : STD_LOGIC := '0';

    -- Register perantara (di-capture di IDLE, dipakai di COMPUTE)
    signal new941, new1477 : SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
    signal old_941, old_1477 : SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);

begin

    -- in_ready kombinatorial: hanya IDLE yang bisa menerima data baru
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
    process(clk, reset, master_reset)
    begin
        if master_reset = '1' then
            state        <= IDLE;
            cbuffer941   <= (others => (others => '0'));
            cbuffer1477  <= (others => (others => '0'));
            index        <= 0;
            full         <= '0';
            count_941    <= 0;
            count_1477   <= 0;
            detect_941   <= '0';
            detect_1477  <= '0';
            onoff_mark   <= '0';
            out_valid    <= '0';
            new941       <= (others => '0');
            new1477      <= (others => '0');
            old_941      <= (others => '0');
            old_1477     <= (others => '0');

        elsif reset = '1' then
            -- Soft reset: hanya FSM state, counter, dan SR latch deteksi yang direset.
            -- Buffer historis (cbuffer941, cbuffer1477), index, dan full DIPERTAHANKAN
            -- agar korelator dapat langsung melanjutkan perbandingan setelah re-arm
            -- tanpa harus mengisi ulang buffer selama ~320 ms.
            state       <= IDLE;
            count_941   <= 0;
            count_1477  <= 0;
            detect_941  <= '0';
            detect_1477 <= '0';
            onoff_mark  <= '0';
            out_valid   <= '0';
            new941      <= (others => '0');
            new1477     <= (others => '0');
            old_941     <= (others => '0');
            old_1477    <= (others => '0');

        elsif rising_edge(clk) then
            case state is

                -- ===========================================================
                -- IDLE: Tunggu data baru, ambil nilai sekarang dan nilai
                --       lookback-lalu dari circular buffer
                -- ===========================================================
                when IDLE =>
                    out_valid <= '1';
                    if in_valid = '1' then
                        -- Simpan nilai batch saat ini
                        new941  <= in_941;
                        new1477 <= in_1477;
                        -- Baca nilai lookback-lalu (slot yang akan ditimpa)
                        -- Kalikan dengan THRESHOLD_COEFF sesuai threshold
                        old_941  <= resize(THRESHOLD_COEFF * cbuffer941(index),  old_941);
                        old_1477 <= resize(THRESHOLD_COEFF * cbuffer1477(index), old_1477);
                        state <= COMPUTE;
                    end if;

                -- ===========================================================
                -- COMPUTE: Bandingkan curr vs THRESHOLD_COEFF*prev per frekuensi,
                --          update counter independen, cek kondisi deteksi
                --
                -- Catatan timing RTL: signal assignment berlaku pada siklus
                -- berikutnya. Oleh karena itu:
                --   - count naik dari 0 ke 1 pada siklus ini
                --   - pada siklus berikutnya count = 1, dsb.
                --   - Threshold detect: count >= 4 (setara MATLAB count >= 5
                --     setelah increment, karena RTL memeriksa nilai SEBELUM
                --     increment efektif)
                -- ===========================================================
                when COMPUTE =>
                    out_valid <= '0';

                    if full = '1' then

                        -- --- 941 Hz: counter independen ---
                        if new941 >= old_941 and new941 > to_sfixed(GUARD_FLOOR, new941) then
                            -- Kondisi terpenuhi: naikkan counter (batasi di 5)
                            if count_941 < 5 then
                                count_941 <= count_941 + 1;
                            end if;
                        else
                            -- Kondisi gagal: reset HANYA counter 941
                            count_941 <= 0;
                        end if;

                        -- --- 1477 Hz: counter independen ---
                        if new1477 >= old_1477 and new1477 > to_sfixed(GUARD_FLOOR, new1477) then
                            if count_1477 < 5 then
                                count_1477 <= count_1477 + 1;
                            end if;
                        else
                            -- Reset HANYA counter 1477 (tidak memengaruhi count_941)
                            count_1477 <= 0;
                        end if;

                        -- --- Level-sensitive detection per frekuensi ---
                        -- Threshold >= 4 di RTL setara >= 5 di MATLAB
                        -- (kompensasi 1-cycle delay clocked logic)
                        if count_941 >= 4 then
                            detect_941 <= '1';
                        else
                            detect_941 <= '0';
                        end if;
                        if count_1477 >= 4 then
                            detect_1477 <= '1';
                        else
                            detect_1477 <= '0';
                        end if;

                        -- --- Konfirmasi flag "##": kedua frekuensi terdeteksi ---
                        -- onoff_mark adalah SR latch permanen: sekali '1', tidak
                        -- pernah kembali ke '0'. Marking akan aktif selamanya
                        -- setelah ini.
                        if detect_941 = '1' and detect_1477 = '1' then
                            onoff_mark <= '1';
                        end if;

                    end if; -- full = '1'

                    state <= STORE;

                -- ===========================================================
                -- STORE: Tulis nilai batch saat ini ke circular buffer,
                --        majukan index, tandai buffer penuh jika perlu
                -- ===========================================================
                when STORE =>
                    cbuffer941(index)  <= in_941;
                    cbuffer1477(index) <= in_1477;

                    -- Buffer dinyatakan penuh setelah slot terakhir (index=LOOKBACK_DEPTH) terisi
                    if index = LOOKBACK_DEPTH then
                        full <= '1';
                    end if;

                    if out_ready = '1' then
                        state <= IDLE;
                        -- Maju ke slot berikutnya (modular LOOKBACK_DEPTH + 1)
                        if index = LOOKBACK_DEPTH then
                            index <= 0;
                        else
                            index <= index + 1;
                        end if;
                    end if;

                when others =>
                    state <= IDLE;

            end case;
        end if;
    end process;

end Behavioral;
