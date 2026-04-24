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
	signal out_valid : std_logic;
	signal Aud_interface_ready : std_logic := '1';
	signal enable : std_logic := '0';
	signal dataA : std_logic_vector(15 downto 0);
	
	-- For interfacing with the Tone Detection Design 
	signal in_ready  : std_logic; 
	signal anode 	  : std_logic;
	signal encode_out: std_logic_vector(23 downto 0);
	
	-- %% For interfacing with the DTMF Generator %%
	signal dtmf_lout : signed(15 downto 0);  -- intermediate; Lout driven via MUX
	signal command : std_logic;
	signal dtmf_out : signed(15 downto 0);
	signal counter : natural := 0;
	signal tone_digit : std_logic_vector(9 downto 0);
	signal shift_key_24bit : std_logic_vector(23 downto 0);
	signal segment_counter : unsigned(2 downto 0) := (others => '0');
	signal current_3bit_segment : std_logic_vector(2 downto 0);
	signal dtmf_digit_to_send : std_logic_vector(9 downto 0);
	signal LED : std_logic := '0';
	-- State machine for button pressing 
	type command_state is (WAIT_FOR_PRESS, WAIT_FOR_RELEASE, RELEASE_STATE);
	signal button_state : command_state;
	-- State machine for sending syncronization signal
	type sending_state is (IDLE, SEND_SYNCH_HASH_FIRST, SEND_SYNCH_3, SEND_SYNCH_HASH_FINAL, SCRAMBLE);
	signal dtmf_state : sending_state;
	
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
		out_valid => out_valid,
		-- Data interfacing
		dataA  	  => dataA,
		enable    => enable
	);
	
	-- DTMF Detection instantiation
	DTMF_Display : entity work.dtmf_system
   generic map (
        DATA_WIDTH => 16,
        BLOCK_SIZE => 640
    )
    port map (
        clk         => AUD_XCK,
        rst         => not KEY(0),
        in_valid    => Ldone,
        in_ready    => in_ready,
        dtmf_input  => std_logic_vector(Lin),
        out_ready   => '1',
        out_valid   => out_valid,
        sevseg      => HEX0,
        anode       => anode,
        encode_out  => encode_out
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

	-- Combinational multiplexer: select one 3-bit segment from 24-bit key.
	SEGMENT_MUX : process(shift_key_24bit, segment_counter)
	begin
		case to_integer(segment_counter) is
			when 0 =>
				current_3bit_segment <= shift_key_24bit(23 downto 21);
			when 1 =>
				current_3bit_segment <= shift_key_24bit(20 downto 18);
			when 2 =>
				current_3bit_segment <= shift_key_24bit(17 downto 15);
			when 3 =>
				current_3bit_segment <= shift_key_24bit(14 downto 12);
			when 4 =>
				current_3bit_segment <= shift_key_24bit(11 downto 9);
			when 5 =>
				current_3bit_segment <= shift_key_24bit(8 downto 6);
			when 6 =>
				current_3bit_segment <= shift_key_24bit(5 downto 3);
			when others =>
				current_3bit_segment <= shift_key_24bit(2 downto 0);
		end case;
	end process;

	-- Combinational decoder: map 3-bit segment into one-hot DTMF tone digit.
	SEGMENT_TO_DTMF_DECODER : process(current_3bit_segment)
	begin
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
	end process;

	-- FSM for generating ##3# DTMF sequence
	FSM_GENERATE_DTMF : process(AUD_XCK, KEY(0))
	begin 
		if(KEY(0)='0') then
			tone_digit <= (others => '0');
			dtmf_state <= IDLE;
			sync_start <= '0';
			counter <= 0;
		elsif(AUD_XCK'event and AUD_XCK='1') then
			case dtmf_state is
				when IDLE => 
					tone_digit <= (others => '0');
					if (command = '1') then 
						dtmf_state <= SEND_SYNCH_HASH_FIRST;
						tone_digit <= "1000000001"; -- set to sending #
					end if;
				when SEND_SYNCH_HASH_FIRST => 
					if (counter >= 737280) then -- Send for 40 ms
						counter <= 0;
						tone_digit <= "0000000100"; -- set to sending 3
						dtmf_state <= SEND_SYNCH_3;
					else 
						counter <= counter + 1;
					end if;
				when SEND_SYNCH_3 => 
					if (counter >= 368640) then -- Send for 20 ms
						counter <= 0;
						dtmf_state <= SEND_SYNCH_HASH_FINAL;
						tone_digit <= "1000000001"; -- Set to sending #
					else 
						counter <= counter + 1;
					end if;
				when SEND_SYNCH_HASH_FINAL =>
					if (counter >= 368640) then -- Send for 20 ms
						counter <= 0;
						dtmf_state <= SCRAMBLE;
						tone_digit <= (others => '0');
						sync_start <= '1';
					else 
						counter <= counter + 1;
					end if;
				when SCRAMBLE =>
					if sync_start = '1' then
						dtmf_state <= IDLE;
					end if;
			end case;
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
			case button_state is
				when WAIT_FOR_PRESS =>
					if (dtmf_state = SCRAMBLE) then 
						command <= '0';
					elsif(KEY(1)='0') then
						button_state <= WAIT_FOR_RELEASE;
					end if;
				when WAIT_FOR_RELEASE =>
					if(KEY(1)='1') then
						button_state <= RELEASE_STATE;
					end if;
				when RELEASE_STATE =>
					command <= not command;
					button_state <= WAIT_FOR_PRESS;
			end case;
		end if;
	end process;

end rtl;

