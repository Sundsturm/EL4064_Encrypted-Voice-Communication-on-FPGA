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
--   jika curr >= 3 * prev_32_batch_lalu. Jika salah satu gagal, hanya counter
--   yang gagal yang di-reset (tidak keduanya).
--
--   Setelah count_941 >= 2 DAN count_1477 >= 2 (masing-masing independen),
--   onoff_mark di-assert '1' secara permanen untuk mengaktifkan modul marking.
--
-- Buffer:
--   Circular buffer 33 slot (index 0..32) memberikan delay 32-batch lookback
--   sesuai MATLAB: prev = batch_sums(slide_i - 32, freq).
--   Mulai membandingkan setelah buffer penuh (full='1', setelah 33 batch masuk).
-- ============================================================================
entity flaggingv2 is
    generic(
        in_INT_BITS  : natural := 15;
        in_FRAC_BITS : natural := 1
    );
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        in_valid   : in  STD_LOGIC;
        out_ready  : in  STD_LOGIC;
        in_ready   : out STD_LOGIC;
        out_valid  : out STD_LOGIC;
        in_941     : in  SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
        in_1477    : in  SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
        onoff_mark : out STD_LOGIC;   -- SR latch: '1' setelah "##" terdeteksi
        latch_reset : in  STD_LOGIC   -- Opsi C: reset eksternal dari session timeout
    );
end flaggingv2;

architecture Behavioral of flaggingv2 is

    type state_type is (IDLE, COMPUTE, STORE);
    signal state : state_type := IDLE;

    -- -------------------------------------------------------------------------
    -- Circular buffer: 33 slot → lookback 32 batch (sesuai MATLAB slide_i-32)
    -- -------------------------------------------------------------------------
    type cbuf_t is array (0 to 32) of SFIXED((in_INT_BITS-1) downto -in_FRAC_BITS);
    signal cbuffer941  : cbuf_t := (others => (others => '0'));
    signal cbuffer1477 : cbuf_t := (others => (others => '0'));

    signal index     : integer range 0 to 32 := 0;
    signal full      : STD_LOGIC := '0';  -- '1' setelah 33 batch pertama terisi

    -- -------------------------------------------------------------------------
    -- Dua counter INDEPENDEN (ref MATLAB: count_941, count_1477)
    -- Range 0..5; dibatasi agar tidak overflow
    -- -------------------------------------------------------------------------
    signal count_941  : integer range 0 to 5 := 0;
    signal count_1477 : integer range 0 to 5 := 0;

    -- SR latches per frekuensi (ref MATLAB: detect_enable_941, detect_enable_1477)
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
    process(clk, reset)
    begin
        if reset = '1' then
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

        elsif rising_edge(clk) then
            if latch_reset = '1' then
                onoff_mark  <= '0';
                detect_941  <= '0';
                detect_1477 <= '0';
                count_941   <= 0;
                count_1477  <= 0;
                state       <= IDLE;
            else
                case state is

                -- ===========================================================
                -- IDLE: Tunggu data baru, ambil nilai sekarang dan nilai
                --       32-batch-lalu dari circular buffer
                -- ===========================================================
                when IDLE =>
                    out_valid <= '1';
                    if in_valid = '1' then
                        -- Simpan nilai batch saat ini
                        new941  <= in_941;
                        new1477 <= in_1477;
                        -- Baca nilai 32-batch lalu (slot yang akan ditimpa)
                        -- Kalikan dengan 3 sesuai threshold MATLAB: curr >= 3*prev
                        old_941  <= resize(3 * cbuffer941(index),  old_941);
                        old_1477 <= resize(3 * cbuffer1477(index), old_1477);
                        state <= COMPUTE;
                    end if;

                -- ===========================================================
                -- COMPUTE: Bandingkan curr vs 3*prev per frekuensi, update
                --          counter independen, cek kondisi deteksi
                --
                -- Catatan timing RTL: signal assignment berlaku pada siklus
                -- berikutnya. Oleh karena itu:
                --   - count naik dari 0 ke 1 pada siklus ini
                --   - pada siklus berikutnya count = 1, dsb.
                --   - Threshold detect: count >= 2 (diturunkan dari 4 untuk
                --     deteksi cepat pada sinyal hardware lemah / gain rendah)
                -- ===========================================================
                when COMPUTE =>
                    out_valid <= '0';

                    if full = '1' then

                        -- --- 941 Hz: counter independen ---
                        if new941 >= old_941 then
                            -- Kondisi terpenuhi: naikkan counter (batasi di 5)
                            if count_941 < 5 then
                                count_941 <= count_941 + 1;
                            end if;
                        else
                            -- Kondisi gagal: reset HANYA counter 941
                            count_941 <= 0;
                        end if;

                        -- --- 1477 Hz: counter independen ---
                        if new1477 >= old_1477 then
                            if count_1477 < 5 then
                                count_1477 <= count_1477 + 1;
                            end if;
                        else
                            -- Reset HANYA counter 1477 (tidak memengaruhi count_941)
                            count_1477 <= 0;
                        end if;

                        -- --- SR latch per frekuensi ---
                        -- Threshold diturunkan ke >= 2 (dari >= 4) untuk
                        -- deteksi cepat pada sinyal hardware dengan gain rendah
                        if count_941 >= 2 then
                            detect_941 <= '1';
                        end if;
                        if count_1477 >= 2 then
                            detect_1477 <= '1';
                        end if;

                        -- --- Konfirmasi flag "##": kedua frekuensi terdeteksi ---
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

                    -- Buffer dinyatakan penuh setelah slot terakhir (index=32) terisi
                    if index = 32 then
                        full <= '1';
                    end if;

                    if out_ready = '1' then
                        state <= IDLE;
                        -- Maju ke slot berikutnya (modular 33)
                        if index = 32 then
                            index <= 0;
                        else
                            index <= index + 1;
                        end if;
                    end if;

                when others =>
                    state <= IDLE;

            end case;
        end if;
    end if;
    end process;

end Behavioral;
