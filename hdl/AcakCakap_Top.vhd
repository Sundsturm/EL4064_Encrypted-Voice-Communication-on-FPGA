library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity AcakCakap_Top is
port
(

	------------ CLOCK ------------
	CLOCK2_50       	:in    	std_logic;
	CLOCK3_50       	:in    	std_logic;
	CLOCK4_50       	:in    	std_logic;
	CLOCK_50        	:in    	std_logic;

	------------ KEY ------------
	KEY             	:in    	std_logic_vector(3 downto 0);

	------------ SW ------------
	SW              	:in    	std_logic_vector(9 downto 0);

	------------ LED ------------
	LEDR            	:out   	std_logic_vector(9 downto 0);

	------------ Seg7 ------------
	HEX0            	:out   	std_logic_vector(6 downto 0);
	HEX1            	:out   	std_logic_vector(6 downto 0);
	HEX2            	:out   	std_logic_vector(6 downto 0);
	HEX3            	:out   	std_logic_vector(6 downto 0);
	HEX4            	:out   	std_logic_vector(6 downto 0);
	HEX5            	:out   	std_logic_vector(6 downto 0);

	------------ Audio ------------
	AUD_ADCDAT      	:in    	std_logic;
	AUD_ADCLRCK     	:inout 	std_logic;
	AUD_BCLK        	:inout 	std_logic;
	AUD_DACDAT      	:out   	std_logic;
	AUD_DACLRCK     	:inout 	std_logic;
	AUD_XCK         	:buffer  std_logic;

	------------ I2C for Audio and Video-In ------------
	FPGA_I2C_SCLK   	:out   	std_logic;
	FPGA_I2C_SDAT   	:inout 	std_logic
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
	
	-- For interfacing with the scrambler
	signal in_real, out_real : std_logic_vector(15 downto 0);
	signal do_en 	  : std_logic;
	signal shift_key  : std_logic_vector(23 downto 0);
	signal sync_start : std_logic := '0';
	
	-- For interfacing with correlator
	signal corr_out_valid : std_logic;
	signal out_valid : std_logic;
	signal Aud_interface_ready : std_logic := '1';
	signal enable : std_logic := '0';
	signal dataA : std_logic_vector(15 downto 0);
	signal goertzel_enable : std_logic := '0';
	
	-- Interconnect for Goertzel_top -> top_dtmfencode
	signal goertzel_out_valid : std_logic;
	signal encoder_in_ready : std_logic;
	signal power_697  : std_logic_vector(16 downto 0);
	signal power_770  : std_logic_vector(16 downto 0);
	signal power_852  : std_logic_vector(16 downto 0);
	signal power_941  : std_logic_vector(16 downto 0);
	signal power_1209 : std_logic_vector(16 downto 0);
	signal power_1336 : std_logic_vector(16 downto 0);
	signal power_1477 : std_logic_vector(16 downto 0);
	signal dtmf_code_4bit : std_logic_vector(3 downto 0);
	signal dtmf_code_valid : std_logic;
	signal reconstructed_key_24bit : std_logic_vector(23 downto 0);
	signal shift_add_in_ready : std_logic;
	signal shift_add_out_valid : std_logic;
	
	-- For interfacing with the Tone Detection Design 
	signal in_ready  : std_logic; 
	signal anode 	  : std_logic;
	signal encode_out: std_logic_vector(23 downto 0);
	
	-- %% For interfacing with the DTMF Generator %%
	signal dtmf_lout : signed(15 downto 0);  -- intermediate; Lout driven via MUX
	signal command : std_logic;
	signal dtmf_out : signed(15 downto 0);
	signal tone_digit : std_logic_vector(9 downto 0);
	signal shift_key_24bit : std_logic_vector(23 downto 0);
	signal segment_counter : unsigned(3 downto 0) := (others => '0');
	signal current_3bit_segment : std_logic_vector(2 downto 0);
	signal dtmf_digit_to_send : std_logic_vector(9 downto 0);
	
	-- Phase 2 FSM sender control
	type state_type is (IDLE, TRANSMIT, SILENCE);
	signal current_state : state_type := IDLE;
	signal sample_counter : integer range 0 to 640 := 0;
	signal start_transmission : std_logic := '0';
	signal dtmf_tone_enable : std_logic := '0';
	constant SAMPLES_20MS : integer := 640;
	
	-- Local clock/reset alias for synchronous FSM process
	signal clk : std_logic;
	signal rst : std_logic;

	signal LED : std_logic := '0';
	-- State machine for button pressing 
	type command_state is (WAIT_FOR_PRESS, WAIT_FOR_RELEASE, RELEASE_STATE);
	signal button_state : command_state;
	
	-- Scrambler Component declaration (Verilog entity)
	component Scrambler_TOP
	port (
		clock  	  : in std_logic;
		reset      : in std_logic;
		di_en 	  : in std_logic;
		shift_key  : in std_logic_vector(23 downto 0);
		in_real	  : in std_logic_vector(15 downto 0);
		do_en	  	  : out std_logic;
		out_real   : out std_logic_vector(15 downto 0)
	);
	end component Scrambler_TOP;

begin

-- body --
	clk <= AUD_XCK;
	rst <= not KEY(0);
	start_transmission <= command;
	goertzel_enable <= enable;
	shift_key <= reconstructed_key_24bit;
	
	-- Audio interface core instantiation
	Audio_interface: entity work.Audio_interface
	generic map (
		SAMPLE_RATE => 32 --in KHz
	)
	port map (
		clk => clock_50,
		rst => not key(0),
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
	
	-- DTMF Generator instance
	DTMF_generator : entity work.generate_dtmf_signed(rtl)
	generic map (
		addr_bits => 9,
		data_bits => 16
	)
	port map (
		clk => AUD_XCK,
		rst => not KEY(0),
		command => command,
		tone_digit => tone_digit, 
		dtmf_out => dtmf_lout
	);
	
	-- Scrambler instance
	Scrambler_interface: Scrambler_TOP
	port map (
		clock => AUD_XCK,
		reset => not KEY(0),
		di_en => sync_start,
		do_en => do_en,
		shift_key => shift_key,
		in_real => in_real,
		out_real => out_real
	);
	
	-- DTMF Correlator instantiation
	DTMF_corr: entity work.toplevel_iq
	generic map (
		mult_INT_BITS   => 2,
		mult_FRAC_BITS  => 14,
		acc_INT_BITS    => 6,
		acc_FRAC_BITS   => 10,
		power_INT_BITS  => 10,
		power_FRAC_BITS => 6,
		batch_INT_BITS  => 14,
		batch_FRAC_BITS => 2
	)
	port map (
		clk		  => AUD_XCK,
		reset 	  => not KEY(0),
		in_valid  => Ldone, 
		out_ready => '1',
		-- Output port 
		in_ready  => Aud_interface_ready,
		out_valid => corr_out_valid,
		-- Data interfacing
		dataA  	  => dataA,
		enable    => enable
	);
	
	-- =========================================================
	-- Receiver Phase 4: Goertzel power bank + DTMF encoder chain
	-- =========================================================
	GOERTZEL_RX : entity work.Goertzel_top
	generic map (
		DATA_WIDTH => 16,
		BLOCK_SIZE => 640
	)
	port map (
		clk       => AUD_XCK,
		rst       => not KEY(0),
		in_ready  => in_ready,
		in_valid  => goertzel_enable,
		DTMF_sig  => std_logic_vector(Lin),
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

	DTMF_ENCODER_RX : entity work.top_dtmfencode
	port map (
		clk       => AUD_XCK,
		rst       => not KEY(0),
		in_valid  => goertzel_out_valid,
		in_ready  => encoder_in_ready,
		corr_697  => power_697,
		corr_770  => power_770,
		corr_852  => power_852,
		corr_941  => power_941,
		corr_1209 => power_1209,
		corr_1336 => power_1336,
		corr_1477 => power_1477,
		out_ready => '1',
		out_valid => out_valid,
		sevseg    => HEX0,
		anode     => anode,
		encode_out => encode_out,
		dtmf_code_4bit => dtmf_code_4bit,
		dtmf_code_valid => dtmf_code_valid
	);

	SHIFT_ADD_RX : entity work.shift_add
	port map (
		clk      => AUD_XCK,
		reset    => not KEY(0),
		in_valid => dtmf_code_valid,
		out_ready => '1',
		in_ready => shift_add_in_ready,
		out_valid => shift_add_out_valid,
		input3   => dtmf_code_4bit,
		output32 => reconstructed_key_24bit
	);
	

	-- =========================================================
	-- MUX: SW(9)='0' → Bypass (ADC loopback ke DAC, tanpa Scrambler)
	--      SW(9)='1' → Normal (keluaran Scrambler ke DAC)
	-- Catatan: pada Normal Mode, DTMF sync tone (dtmf_lout) dijumlahkan
	-- secara konseptual di luar MUX ini; jika perlu mixing, ganti
	-- signed(out_real) dengan dtmf_lout + signed(out_real).
	-- =========================================================
	Lout <= Lin                when SW(9) = '0' else signed(out_real);
	Rout <= Rin                when SW(9) = '0' else signed(out_real);

	-- Phase 1: prepare 24-bit key source for segmentation.
	shift_key_24bit <= shift_key;

	-- Combinational multiplexer: for segment 2..9 select one 3-bit key segment.
	SEGMENT_MUX : process(shift_key_24bit, segment_counter)
	begin
		case to_integer(segment_counter) is
			when 2 =>
				current_3bit_segment <= shift_key_24bit(23 downto 21);
			when 3 =>
				current_3bit_segment <= shift_key_24bit(20 downto 18);
			when 4 =>
				current_3bit_segment <= shift_key_24bit(17 downto 15);
			when 5 =>
				current_3bit_segment <= shift_key_24bit(14 downto 12);
			when 6 =>
				current_3bit_segment <= shift_key_24bit(11 downto 9);
			when 7 =>
				current_3bit_segment <= shift_key_24bit(8 downto 6);
			when 8 =>
				current_3bit_segment <= shift_key_24bit(5 downto 3);
			when 9 =>
				current_3bit_segment <= shift_key_24bit(2 downto 0);
			when others =>
				current_3bit_segment <= (others => '0');
		end case;
	end process;

	-- Combinational decoder with preamble: [0]='#', [1]='3', [2..9]=encoded key.
	SEGMENT_TO_DTMF_DECODER : process(segment_counter, current_3bit_segment)
	begin
		case to_integer(segment_counter) is
			when 0 =>
				dtmf_digit_to_send <= "1000000001"; -- DTMF '#'
			when 1 =>
				dtmf_digit_to_send <= "0000000100"; -- DTMF '3'
			when others =>
				case current_3bit_segment is
					when "000" => -- DTMF '3'
						dtmf_digit_to_send <= "0000000100";
					when "001" => -- DTMF '2'
						dtmf_digit_to_send <= "0000000010";
					when "010" => -- DTMF '4'
						dtmf_digit_to_send <= "0000001000";
					when "011" => -- DTMF '5'
						dtmf_digit_to_send <= "0000010000";
					when "100" => -- DTMF '7'
						dtmf_digit_to_send <= "0001000000";
					when "101" => -- DTMF '8'
						dtmf_digit_to_send <= "0010000000";
					when "110" => -- DTMF '0'
						dtmf_digit_to_send <= "0000000000";
					when others => -- "111" -> DTMF '*'
						dtmf_digit_to_send <= "1000000000";
				end case;
		end case;
	end process;

	-- Apply DTMF tone only during TRANSMIT state.
	tone_digit <= dtmf_digit_to_send when dtmf_tone_enable = '1' else (others => '0');

	-- Phase 2 sequential FSM for DTMF transmission timing
	FSM_DTMF_TRANSMITTER : process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				current_state <= IDLE;
				sample_counter <= 0;
				segment_counter <= (others => '0');
				dtmf_tone_enable <= '0';
			else
				case current_state is
					when IDLE =>
						dtmf_tone_enable <= '0';
						sample_counter <= 0;
						if start_transmission = '1' then
							segment_counter <= (others => '0');
							current_state <= TRANSMIT;
						end if;

					when TRANSMIT =>
						dtmf_tone_enable <= '1';
						if sample_counter = SAMPLES_20MS - 1 then
							sample_counter <= 0;
							current_state <= SILENCE;
						else
							sample_counter <= sample_counter + 1;
						end if;

					when SILENCE =>
						dtmf_tone_enable <= '0';
						if sample_counter = SAMPLES_20MS - 1 then
							sample_counter <= 0;
							if segment_counter < to_unsigned(9, segment_counter'length) then
								segment_counter <= segment_counter + 1;
								current_state <= TRANSMIT;
							else
								current_state <= IDLE;
							end if;
						else
							sample_counter <= sample_counter + 1;
						end if;
				end case;
			end if;
		end if;
	end process;

	-- FSM for issueing the "Go" command of transmitting DTMF
	FSM_COMMAND : process(AUD_XCK, KEY(0)) 
	begin 
		if(KEY(0)='0') then
			LED <= '0';
			button_state <= WAIT_FOR_PRESS;
			command <= '0';
		elsif(AUD_XCK'event and AUD_XCK='1') then
			command <= '0';
			case button_state is
				when WAIT_FOR_PRESS =>
					if(KEY(1)='0') then
						button_state <= WAIT_FOR_RELEASE;
					end if;
				when WAIT_FOR_RELEASE =>
					if(KEY(1)='1') then
						button_state <= RELEASE_STATE;
					end if;
				when RELEASE_STATE =>
					command <= '1';
					button_state <= WAIT_FOR_PRESS;
			end case;
		end if;
	end process;

end rtl;

