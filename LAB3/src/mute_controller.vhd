LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY mute_controller IS
	GENERIC (
		TDATA_WIDTH : POSITIVE := 24
	);
	PORT (
		aclk : IN STD_LOGIC;
		aresetn : IN STD_LOGIC;

		s_axis_tvalid : IN STD_LOGIC;
		s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
		s_axis_tlast : IN STD_LOGIC;
		s_axis_tready : OUT STD_LOGIC;

		m_axis_tvalid : OUT STD_LOGIC;
		m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
		m_axis_tlast : OUT STD_LOGIC;
		m_axis_tready : IN STD_LOGIC;

		mute : IN STD_LOGIC
	);
END mute_controller;

ARCHITECTURE Behavioral OF mute_controller IS
BEGIN

	PROCESS (aclk)
	BEGIN

		IF rising_edge(aclk) THEN

			IF aresetn = '0' THEN
				m_axis_tvalid <= '0';
				m_axis_tdata <= (OTHERS => '0');
				m_axis_tlast <= '0';
				s_axis_tready <= '0';

			ELSE
				IF s_axis_tvalid = '1' AND m_axis_tready = '1' THEN
					-- Accept input data
					s_axis_tready <= '1';
					m_axis_tvalid <= '1';
					m_axis_tlast <= s_axis_tlast;

					IF mute = '1' THEN
						m_axis_tdata <= (OTHERS => '0');
					ELSE
						m_axis_tdata <= s_axis_tdata;
					END IF;

				ELSE
					-- Do not accept new data
					s_axis_tready <= '0';
					m_axis_tvalid <= '0';
					m_axis_tlast <= '0';

				END IF;

			END IF;

		END IF;
		
	END PROCESS;

END Behavioral;