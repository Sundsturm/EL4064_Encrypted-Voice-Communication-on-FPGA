library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity AcakCakap_Top is
	port (

		------------ CLOCK ------------
		CLOCK2_50 : in std_logic;
		CLOCK3_50 : in std_logic;
		CLOCK4_50 : in std_logic;
		CLOCK_50 : in std_logic;

		------------ KEY ------------
		KEY : in std_logic_vector(3 downto 0);

		------------ SW ------------
		SW : in std_logic_vector(9 downto 0);

		------------ UART ------------
		UART_RXD : in std_logic;

		------------ LED ------------
		LEDR : out std_logic_vector(9 downto 0);

		------------ Seg7 ------------
		HEX0 : out std_logic_vector(6 downto 0);
		HEX1 : out std_logic_vector(6 downto 0);
		HEX2 : out std_logic_vector(6 downto 0);
		HEX3 : out std_logic_vector(6 downto 0);
		HEX4 : out std_logic_vector(6 downto 0);
		HEX5 : out std_logic_vector(6 downto 0);

		------------ Audio ------------
		AUD_ADCDAT : in std_logic;
		AUD_ADCLRCK : inout std_logic;
		AUD_BCLK : inout std_logic;
		AUD_DACDAT : out std_logic;
		AUD_DACLRCK : inout std_logic;
		AUD_XCK : buffer std_logic;

		------------ I2C for Audio and Video-In ------------
		FPGA_I2C_SCLK : out std_logic;
		FPGA_I2C_SDAT : inout std_logic
	);

end entity;

---------------------------------------------------------
--  Structural coding
---------------------------------------------------------

architecture rtl of AcakCakap_Top is

	-- declare --
	-- For interfacing with the Audio Interface design
	signal Lin, Rin, Lout, Rout : signed(15 downto 0);
	signal Ldone, Rdone : std_logic;

	-- For interfacing with correlator
	signal corr_out_valid : std_logic;
	signal out_valid : std_logic;
	signal Aud_interface_ready : std_logic := '1';
	signal enable : std_logic := '0';
	signal goertzel_enable : std_logic := '0';

	-- Interconnect for Goertzel_top -> top_dtmfencode
	signal goertzel_out_valid : std_logic;
	signal encoder_in_ready : std_logic;
	signal power_697 : std_logic_vector(16 downto 0);
	signal power_770 : std_logic_vector(16 downto 0);
	signal power_852 : std_logic_vector(16 downto 0);
	signal power_941 : std_logic_vector(16 downto 0);
	signal power_1209 : std_logic_vector(16 downto 0);
	signal power_1336 : std_logic_vector(16 downto 0);
	signal power_1477 : std_logic_vector(16 downto 0);
	signal power_1633 : std_logic_vector(16 downto 0);
	signal dtmf_code_4bit : std_logic_vector(3 downto 0);
	signal dtmf_code_valid : std_logic;
	signal reconstructed_key_32bit : std_logic_vector(31 downto 0);
	signal shift_add_in_ready : std_logic;
	signal shift_add_out_valid : std_logic;

	-- For interfacing with the Tone Detection Design 
	signal in_ready : std_logic;
	signal anode : std_logic;
	signal encode_out : std_logic_vector(23 downto 0);

	-- %% For interfacing with the DTMF Generator %%
	signal dtmf_lout : signed(15 downto 0); -- intermediate; Lout driven via MUX
	signal command : std_logic;
	signal dtmf_out : signed(15 downto 0);
	signal tone_digit : std_logic_vector(3 downto 0);
	signal payload_data : std_logic_vector(31 downto 0);
	signal segment_counter : unsigned(3 downto 0) := (others => '0');
	signal current_4bit_segment : std_logic_vector(3 downto 0);
	signal dtmf_digit_to_send : std_logic_vector(3 downto 0);

	-- %% UART Interface %%
	signal uart_rx_data : std_logic_vector(7 downto 0);
	signal uart_rx_valid : std_logic;
	signal uart_key_reg  : std_logic_vector(31 downto 0) := (others => '0');
	signal uart_trigger  : std_logic := '0';
	-- Toggle-based CDC: CLOCK_50 -> AUD_XCK
	-- Setiap byte diterima, uart_toggle di-flip (tidak bergantung pulse width)
	signal uart_toggle      : std_logic := '0'; -- domain CLOCK_50
	signal uart_data_latch  : std_logic_vector(7 downto 0) := (others => '0'); -- domain CLOCK_50
	signal uart_tog_meta    : std_logic := '0'; -- 2-FF sync di AUD_XCK
	signal uart_tog_sync    : std_logic := '0';
	signal uart_tog_prev    : std_logic := '0'; -- untuk edge detection
	signal rst_50mhz        : std_logic := '1'; -- reset domain CLOCK_50

	-- Phase 2 FSM sender control
	type state_type is (IDLE, TRANSMIT);
	signal current_state : state_type := IDLE;
	signal sample_counter  : integer range 0 to 640 := 0;
	signal start_transmission : std_logic := '0';
	signal dtmf_tone_enable : std_logic := '0';
	constant SAMPLES_20MS : integer := 640; -- Durasi 1 simbol DTMF @ 32kHz

	-- Local clock/reset alias for synchronous FSM process
	signal clk : std_logic;
	signal rst : std_logic;

	-- Synchronized reset for AUD_XCK domain
	signal aud_rst_reg : std_logic := '1';
	signal aud_rst : std_logic := '1';

	signal LED : std_logic := '0';
	-- State machine for button pressing 
	type command_state is (WAIT_FOR_PRESS, WAIT_FOR_RELEASE, RELEASE_STATE);
	signal button_state : command_state;

	-- Debouncer untuk SW(0) — mencegah glitch saat ganti mode tampilan
	-- DEBOUNCE_LIMIT = 50.000 cycles CLOCK_50 = 1 ms
	constant DEBOUNCE_LIMIT : integer := 50000;
	signal sw0_stable    : std_logic := '0';
	signal debounce_cnt  : integer range 0 to DEBOUNCE_LIMIT := 0;

begin

	-- body --
	clk <= AUD_XCK;
	rst <= not KEY(0);
	start_transmission <= command or uart_trigger; -- Dual-trigger mechanism
	goertzel_enable <= Ldone and enable;

	-- Audio interface core instantiation
	Audio_interface : entity work.Audio_interface
		generic map(
			SAMPLE_RATE => 32 --in KHz
		)
		port map(
			clk => clock_50,
			rst => not KEY(0),
			AUD_XCK => AUD_XCK,
			I2C_SCLK => FPGA_I2C_SCLK,
			I2C_SDAT => FPGA_I2C_SDAT,
			AUD_BCLK => AUD_BCLK,
			AUD_DACLRCK => AUD_DACLRCK,
			AUD_ADCLRCK => AUD_ADCLRCK,
			AUD_ADCDAT => AUD_ADCDAT,
			AUD_DACDAT => AUD_DACDAT,
			Lin => Lin,
			Rin => Rin,
			Ldone => Ldone,
			Rdone => Rdone,
			Rout => Rout,
			Lout => Lout
		);

	-- Reset Synchronizer for AUD_XCK Domain
	process (AUD_XCK)
	begin
		if rising_edge(AUD_XCK) then
			aud_rst_reg <= not KEY(0);
			aud_rst <= aud_rst_reg;
		end if;
	end process;

	-- =========================================================
	-- DEBOUNCER DIGITAL untuk SW(0)
	-- SW(0) harus stabil selama DEBOUNCE_LIMIT cycles CLOCK_50
	-- (~1 ms) sebelum sw0_stable diperbarui.
	-- Ini mencegah glitch/bounce pada transisi slide switch.
	-- =========================================================
	DEBOUNCE_SW0 : process(CLOCK_50)
	begin
		if rising_edge(CLOCK_50) then
			if SW(0) /= sw0_stable then
				-- SW(0) berubah: mulai hitung
				if debounce_cnt = DEBOUNCE_LIMIT then
					sw0_stable   <= SW(0); -- Stabil selama 1ms -> terima
					debounce_cnt <= 0;
				else
					debounce_cnt <= debounce_cnt + 1;
				end if;
			else
				-- SW(0) sama dengan stable: reset counter
				debounce_cnt <= 0;
			end if;
		end if;
	end process;

	-- DTMF Generator instance
	DTMF_generator : entity work.generate_dtmf_signed(rtl)
		generic map(
			addr_bits => 9,
			data_bits => 16
		)
		port map(
			clk => AUD_XCK,
			rst => aud_rst,
			command => dtmf_tone_enable,
			tone_digit => tone_digit,
			dtmf_out => dtmf_lout
		);

	-- =========================================================
	-- UART RX & Protocol Instance
	-- =========================================================
	rst_50mhz <= not KEY(0); -- reset sinkron domain 50 MHz

	UART_RX_INST : entity work.uart_rx
		generic map(
			CLKS_PER_BIT => 434 -- 50 MHz / 115200 bps = 434
		)
		port map(
			clk => CLOCK_50,
			rst => rst_50mhz,
			rx => UART_RXD,
			data_out => uart_rx_data,
			rx_valid => uart_rx_valid
		);

	-- =========================================================
	-- CDC: Toggle-based synchronizer CLOCK_50 -> AUD_XCK
	-- Setiap byte valid dari UART RX, uart_toggle di-flip di CLOCK_50.
	-- Di AUD_XCK, toggle di-sync 2-FF lalu edge-detected.
	-- Metode ini andal untuk pulse < 1 period clock tujuan.
	-- =========================================================
	CDC_TOGGLE_GEN : process(CLOCK_50)
	begin
		if rising_edge(CLOCK_50) then
			if rst_50mhz = '1' then
				uart_toggle    <= '0';
				uart_data_latch <= (others => '0');
			elsif uart_rx_valid = '1' then
				uart_data_latch <= uart_rx_data; -- Latch data dulu
				uart_toggle     <= not uart_toggle; -- Flip toggle
			end if;
		end if;
	end process;

	CDC_TOGGLE_SYNC : process(AUD_XCK)
	begin
		if rising_edge(AUD_XCK) then
			uart_tog_meta <= uart_toggle;   -- FF1 (metastability)
			uart_tog_sync <= uart_tog_meta; -- FF2 (stable)
		end if;
	end process;

	-- UART Protocol FSM: jalan di AUD_XCK, mendeteksi setiap byte baru
	-- lewat perubahan uart_tog_sync (edge detection)
	UART_PROTOCOL_FSM : process(AUD_XCK)
	begin
		if rising_edge(AUD_XCK) then
			if aud_rst = '1' then
				uart_key_reg  <= (others => '0');
				uart_trigger  <= '0';
				uart_tog_prev <= '0';
			else
				uart_trigger <= '0'; -- Default: tidak trigger
				uart_tog_prev <= uart_tog_sync;
				-- Edge detection: setiap perubahan toggle = 1 byte baru
				if uart_tog_sync /= uart_tog_prev then
					if uart_data_latch = x"0A" then
						uart_trigger <= '1'; -- LF = trigger transmisi
					else
						uart_key_reg <= uart_key_reg(23 downto 0) & uart_data_latch;
					end if;
				end if;
			end if;
		end if;
	end process;

	-- DTMF Correlator instantiation
	DTMF_corr : entity work.toplevel_iq
		generic map(
			mult_INT_BITS => 2,
			mult_FRAC_BITS => 14,
			acc_INT_BITS => 6,
			acc_FRAC_BITS => 10,
			power_INT_BITS => 10,
			power_FRAC_BITS => 6,
			batch_INT_BITS => 14,
			batch_FRAC_BITS => 2
		)
		port map(
			clk => AUD_XCK,
			reset => aud_rst,
			in_valid => Ldone,
			out_ready => '1',
			-- Output port 
			in_ready => Aud_interface_ready,
			out_valid => corr_out_valid,
			-- Data interfacing
			dataA => std_logic_vector(Lin),
			enable => enable
		);

	-- =========================================================
	-- Receiver Phase 4: Goertzel power bank + DTMF encoder chain
	-- =========================================================
	GOERTZEL_RX : entity work.Goertzel_top
		generic map(
			DATA_WIDTH => 16,
			BLOCK_SIZE => 640
		)
		port map(
			clk => AUD_XCK,
			rst => aud_rst,
			in_ready => in_ready,
			in_valid => goertzel_enable,
			DTMF_sig => std_logic_vector(Lin),
			out_ready => encoder_in_ready,
			out_valid => goertzel_out_valid,
			power_697 => power_697,
			power_770 => power_770,
			power_852 => power_852,
			power_941 => power_941,
			power_1209 => power_1209,
			power_1336 => power_1336,
			power_1477 => power_1477,
			power_1633 => power_1633
		);

	DTMF_ENCODER_RX : entity work.top_dtmfencode
		port map(
			clk => AUD_XCK,
			rst => aud_rst,
			in_valid => goertzel_out_valid,
			in_ready => encoder_in_ready,
			corr_697 => power_697,
			corr_770 => power_770,
			corr_852 => power_852,
			corr_941 => power_941,
			corr_1209 => power_1209,
			corr_1336 => power_1336,
			corr_1477 => power_1477,
			corr_1633 => power_1633,
			out_ready => '1',
			out_valid => out_valid,
			sevseg => open, -- Tidak dipakai langsung, digantikan MUX Visualisasi
			anode => anode,
			encode_out => reconstructed_key_32bit,
			dtmf_code_4bit => dtmf_code_4bit,
			dtmf_code_valid => dtmf_code_valid
		);

	SHIFT_ADD_RX : entity work.shift_add
		port map(
			clk => AUD_XCK,
			reset => aud_rst,
			in_valid => dtmf_code_valid,
			out_ready => '1',
			in_ready => shift_add_in_ready,
			out_valid => shift_add_out_valid,
			input3 => dtmf_code_4bit,
			output32 => open -- Dipetakan melalui encode_out
		);

	-- =========================================================
	-- AUDIO MULTIPLEXER (MODEM TRANSCEIVER)
	-- =========================================================
	-- Di SISI PENGIRIM (TX): Jalur mikrofon (Lin/Rin) di-mute total selama pengiriman
	-- Di SISI PENERIMA (RX): Jalur Lin diloopsback ke Lout untuk speaker
	Lout <= dtmf_lout when dtmf_tone_enable = '1' else
		Lin;
	Rout <= dtmf_lout when dtmf_tone_enable = '1' else
		Rin;

	-- MUX untuk Injeksi Kunci Dinamis
	-- Jika SW(8) = '1', gunakan kunci dinamis dari injeksi memori UART
	-- Jika SW(8) = '0', gunakan kunci statis kombinasi fisik SW(7 downto 0)
	payload_data <= uart_key_reg when SW(8) = '1' else
		SW(7 downto 0) & SW(7 downto 0) & SW(7 downto 0) & SW(7 downto 0);

	-- Combinational multiplexer: for segment 4..11 select one 4-bit key segment.
	SEGMENT_MUX : process (payload_data, segment_counter)
	begin
		case to_integer(segment_counter) is
			when 4 => current_4bit_segment <= payload_data(31 downto 28);
			when 5 => current_4bit_segment <= payload_data(27 downto 24);
			when 6 => current_4bit_segment <= payload_data(23 downto 20);
			when 7 => current_4bit_segment <= payload_data(19 downto 16);
			when 8 => current_4bit_segment <= payload_data(15 downto 12);
			when 9 => current_4bit_segment <= payload_data(11 downto 8);
			when 10 => current_4bit_segment <= payload_data(7 downto 4);
			when 11 => current_4bit_segment <= payload_data(3 downto 0);
			when others => current_4bit_segment <= (others => '0');
		end case;
	end process;

	-- Combinational decoder with preamble: [0]='#', [1]='#', [2]='3', [3]='#', [4..11]=encoded key.
	SEGMENT_TO_DTMF_DECODER : process (segment_counter, current_4bit_segment)
	begin
		case to_integer(segment_counter) is
			when 0 | 1 | 3 =>
				dtmf_digit_to_send <= x"F"; -- DTMF '#'
			when 2 =>
				dtmf_digit_to_send <= x"3"; -- DTMF '3'
			when others =>
				-- Segmen 4 s.d 11 adalah Payload
				dtmf_digit_to_send <= current_4bit_segment;
		end case;
	end process;

	-- Apply DTMF tone only during TRANSMIT state.
	tone_digit <= dtmf_digit_to_send when dtmf_tone_enable = '1' else
		(others => '0');

	-- Phase 2 sequential FSM for DTMF transmission timing
	FSM_DTMF_TRANSMITTER : process (clk)
	begin
		if rising_edge(clk) then
			if aud_rst = '1' then
				current_state    <= IDLE;
				sample_counter   <= 0;
				segment_counter  <= (others => '0');
				dtmf_tone_enable <= '0';
			else
				case current_state is
					when IDLE =>
						dtmf_tone_enable <= '0';
						sample_counter   <= 0;
						if start_transmission = '1' then
							segment_counter <= (others => '0');
							current_state   <= TRANSMIT;
						end if;

					when TRANSMIT =>
						dtmf_tone_enable <= '1';
						if Ldone = '1' then
							if sample_counter = SAMPLES_20MS - 1 then
								sample_counter <= 0;
								-- Sekuens 12 Simbol (Index 0 sampai 11)
								if segment_counter < to_unsigned(11, segment_counter'length) then
									segment_counter <= segment_counter + 1;
									current_state   <= TRANSMIT; -- Langsung sambung (NO SILENCE)
								else
									current_state <= IDLE;
								end if;
							else
								sample_counter <= sample_counter + 1;
							end if;
						end if;
				end case;
			end if;
		end if;
	end process;

	-- FSM for issueing the "Go" command of transmitting DTMF
	FSM_COMMAND : process (AUD_XCK)
	begin
		if rising_edge(AUD_XCK) then
			if aud_rst = '1' then
				LED <= '0';
				button_state <= WAIT_FOR_PRESS;
				command <= '0';
			else
				case button_state is
					when WAIT_FOR_PRESS =>
						command <= '0';
						LED <= '0';
						if (KEY(1) = '0') then
							button_state <= WAIT_FOR_RELEASE;
						end if;
					when WAIT_FOR_RELEASE =>
						if (KEY(1) = '1') then
							button_state <= RELEASE_STATE;
						end if;
					when RELEASE_STATE =>
						command <= '1';
						LED <= '1';
						button_state <= WAIT_FOR_PRESS;
				end case;
			end if;
		end if;
	end process;

	-- =========================================================
	-- TUGAS 3: MULTIPLEXING VISUALISASI SEVEN-SEGMENT
	-- =========================================================
	VISUALIZATION_MUX : process(sw0_stable, reconstructed_key_32bit)
		-- Fungsi internal konversi HEX ke Seven-Segment (Active-Low)
		function hex_to_sevseg(hex_in : std_logic_vector(3 downto 0)) return std_logic_vector is
		begin
			case hex_in is
				when x"0" => return "1000000";
				when x"1" => return "1111001";
				when x"2" => return "0100100";
				when x"3" => return "0110000";
				when x"4" => return "0011001";
				when x"5" => return "0010010";
				when x"6" => return "0000010";
				when x"7" => return "1111000";
				when x"8" => return "0000000";
				when x"9" => return "0010000";
				when x"A" => return "0001000";
				when x"B" => return "0000011";
				when x"C" => return "1000110";
				when x"D" => return "0100001";
				when x"E" => return "0000110";
				when x"F" => return "0001110";
				when others => return "0111111"; -- Karakter Strip '-'
			end case;
		end function;
	begin
		if sw0_stable = '0' then
			-- LSB Mode: Tampilkan 24-bit (6 digit) terbawah
			HEX5 <= hex_to_sevseg(reconstructed_key_32bit(23 downto 20));
			HEX4 <= hex_to_sevseg(reconstructed_key_32bit(19 downto 16));
			HEX3 <= hex_to_sevseg(reconstructed_key_32bit(15 downto 12));
			HEX2 <= hex_to_sevseg(reconstructed_key_32bit(11 downto 8));
			HEX1 <= hex_to_sevseg(reconstructed_key_32bit(7 downto 4));
			HEX0 <= hex_to_sevseg(reconstructed_key_32bit(3 downto 0));
		else
			-- MSB Mode: Tampilkan 8-bit (2 digit) teratas
			HEX5 <= hex_to_sevseg(reconstructed_key_32bit(31 downto 28));
			HEX4 <= hex_to_sevseg(reconstructed_key_32bit(27 downto 24));
			HEX3 <= "0111111"; -- Karakter Strip '-' (Segmen G menyala)
			HEX2 <= "0111111";
			HEX1 <= "0111111";
			HEX0 <= "0111111";
		end if;
	end process;

end rtl;