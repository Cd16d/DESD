LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY digilent_jstk2 IS
	GENERIC (
		DELAY_US : INTEGER := 25; -- Delay (in us) between two packets
		CLKFREQ : INTEGER := 100_000_000; -- Frequency of the aclk signal (in Hz)
		SPI_SCLKFREQ : INTEGER := 66_666 -- Frequency of the SPI SCLK clock signal (in Hz)
	);
	PORT (
		aclk : IN STD_LOGIC;
		aresetn : IN STD_LOGIC;

		-- Data going TO the SPI IP-Core (and so, to the JSTK2 module)
		m_axis_tvalid : OUT STD_LOGIC;
		m_axis_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		m_axis_tready : IN STD_LOGIC;

		-- Data coming FROM the SPI IP-Core (and so, from the JSTK2 module)
		-- There is no tready signal, so you must be always ready to accept and use the incoming data, or it will be lost!
		s_axis_tvalid : IN STD_LOGIC;
		s_axis_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);

		-- Joystick and button values read from the module
		jstk_x : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
		jstk_y : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
		btn_jstk : OUT STD_LOGIC;
		btn_trigger : OUT STD_LOGIC;

		-- LED color to send to the module
		led_r : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		led_g : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		led_b : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
END digilent_jstk2;

ARCHITECTURE Behavioral OF digilent_jstk2 IS

	-- Code for the SetLEDRGB command, see the JSTK2 datasheet.
	CONSTANT CMDSETLEDRGB : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"84";

	-- Do not forget that you MUST wait a bit between two packets. See the JSTK2 datasheet (and the SPI IP-Core README).
	------------------------------------------------------------

	CONSTANT DELAY_CLK_CYCLES : INTEGER := DELAY_US * (CLKFREQ / 1_000_000) - 1;

	-- State machine states
	TYPE tx_state_type IS (DELAY, SEND_CMD, SEND_RED, SEND_GREEN, SEND_BLUE, SEND_DUMMY);
	TYPE rx_state_type IS (JSTK_X_LOW, JSTK_X_HIGH, JSTK_Y_LOW, JSTK_Y_HIGH, BUTTONS);

	SIGNAL tx_state : tx_state_type;
	SIGNAL rx_state : rx_state_type;

	SIGNAL rx_cache : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL tx_delay_counter : INTEGER := 0;

	SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';

BEGIN

	m_axis_tvalid <= m_axis_tvalid_int;

	-- Send the data to the SPI IP-Core
	TX : PROCESS (aclk)
	BEGIN
		IF rising_edge(aclk) THEN
			IF aresetn = '0' THEN
				-- Reset the state machine
				tx_state <= DELAY;

				m_axis_tvalid_int <= '0';
				m_axis_tdata <= (OTHERS => '0');

				tx_delay_counter <= 0;

			ELSE
				-- Clear valid flag when master interface is ready
                IF m_axis_tready = '1' THEN
                    m_axis_tvalid_int <= '0';
                END IF;

				-- State machine for sending data to the SPI IP-Core
				CASE tx_state IS

					WHEN DELAY =>
						m_axis_tvalid_int <= '0';
						m_axis_tdata <= (OTHERS => '0');

						IF tx_delay_counter >= DELAY_CLK_CYCLES THEN
							tx_delay_counter <= 0;
							tx_state <= SEND_CMD;
						ELSE
							tx_delay_counter <= tx_delay_counter + 1;
						END IF;

					WHEN SEND_CMD =>
						IF (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
							m_axis_tdata <= CMDSETLEDRGB;
							m_axis_tvalid_int <= '1';
							tx_state <= SEND_RED;
						END IF;

					WHEN SEND_RED =>
						IF (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
							m_axis_tdata <= led_r;
							m_axis_tvalid_int <= '1';
							tx_state <= SEND_GREEN;
						END IF;

					WHEN SEND_GREEN =>
						IF (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
							m_axis_tdata <= led_g;
							m_axis_tvalid_int <= '1';
							tx_state <= SEND_BLUE;
						END IF;

					WHEN SEND_BLUE =>
						IF (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
							m_axis_tdata <= led_b;
							m_axis_tvalid_int <= '1';
							tx_state <= SEND_DUMMY;
						END IF;

					WHEN SEND_DUMMY =>
						IF (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
							m_axis_tdata <= (OTHERS => '0');
							m_axis_tvalid_int <= '1';
							tx_state <= DELAY;
						END IF;

				END CASE;

			END IF;
		END IF;

	END PROCESS TX;

	-- Receive the data from the SPI IP-Core
	RX : PROCESS (aclk)
	BEGIN
		IF rising_edge(aclk) THEN
			IF aresetn = '0' THEN
				-- Reset the state machine
				rx_state <= JSTK_X_LOW;

				-- jstk_x <= (others => '0');
				-- jstk_y <= (others => '0');
				btn_jstk <= '0';
				btn_trigger <= '0';

				rx_cache <= (OTHERS => '0');
			ELSE
				-- State machine for receiving data from the SPI IP-Core
				CASE rx_state IS

					WHEN JSTK_X_LOW =>
						IF s_axis_tvalid = '1' THEN
							rx_cache(7 DOWNTO 0) <= s_axis_tdata;
							rx_state <= JSTK_X_HIGH;
						END IF;

					WHEN JSTK_X_HIGH =>
						IF s_axis_tvalid = '1' THEN
							jstk_x(9 DOWNTO 0) <= s_axis_tdata(1 DOWNTO 0) & rx_cache(7 DOWNTO 0);
							rx_state <= JSTK_Y_LOW;
						END IF;

					WHEN JSTK_Y_LOW =>
						IF s_axis_tvalid = '1' THEN
							rx_cache(7 DOWNTO 0) <= s_axis_tdata;
							rx_state <= JSTK_Y_HIGH;
						END IF;

					WHEN JSTK_Y_HIGH =>
						IF s_axis_tvalid = '1' THEN
							jstk_y(9 DOWNTO 0) <= s_axis_tdata(1 DOWNTO 0) & rx_cache(7 DOWNTO 0);
							rx_state <= BUTTONS;
						END IF;

					WHEN BUTTONS =>
						IF s_axis_tvalid = '1' THEN
							btn_jstk <= s_axis_tdata(0);
							btn_trigger <= s_axis_tdata(1);
							rx_state <= JSTK_X_LOW;
						END IF;

				END CASE;
			END IF;
		END IF;

	END PROCESS RX;

END ARCHITECTURE;