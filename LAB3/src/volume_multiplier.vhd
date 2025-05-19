LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY volume_multiplier IS
	GENERIC (
		TDATA_WIDTH : POSITIVE := 24;
		VOLUME_WIDTH : POSITIVE := 10;
		VOLUME_STEP_2 : POSITIVE := 6 -- i.e., volume_values_per_step = 2**VOLUME_STEP_2
	);
	PORT (
		aclk : IN STD_LOGIC;
		aresetn : IN STD_LOGIC;

		s_axis_tvalid : IN STD_LOGIC;
		s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
		s_axis_tlast : IN STD_LOGIC;
		s_axis_tready : OUT STD_LOGIC;

		m_axis_tvalid : OUT STD_LOGIC;
		m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 + 2 ** (VOLUME_WIDTH - VOLUME_STEP_2 - 1) DOWNTO 0);
		m_axis_tlast : OUT STD_LOGIC;
		m_axis_tready : IN STD_LOGIC;

		volume : IN STD_LOGIC_VECTOR(VOLUME_WIDTH - 1 DOWNTO 0)
	);
END volume_multiplier;

ARCHITECTURE Behavioral OF volume_multiplier IS

	CONSTANT VOLUME_STEPS : INTEGER := (2 ** VOLUME_WIDTH) / (2 ** (VOLUME_STEP_2 + 1));

	SIGNAL volume_exp_mult : INTEGER RANGE -VOLUME_STEPS TO VOLUME_STEPS := 0;
	signal volume_centered : SIGNED(VOLUME_WIDTH - 1 DOWNTO 0);

	SIGNAL s_axis_tready_int : STD_LOGIC;
	SIGNAL m_axis_tvalid_int : STD_LOGIC;

BEGIN
	-- Assigning the output signals
	s_axis_tready <= s_axis_tready_int;
	m_axis_tvalid <= m_axis_tvalid_int;

	-- Volume to signed and centered
	volume_centered <= signed(unsigned(volume) - to_unsigned(511, VOLUME_WIDTH));

	-- Volume to exp
	PROCESS (aclk)
	BEGIN

		IF rising_edge(aclk) THEN

			IF aresetn = '0' THEN
				volume_exp_mult <= 0;

			ELSE
				volume_exp_mult <= to_integer(volume_centered(VOLUME_WIDTH - 1 DOWNTO VOLUME_STEP_2));

			END IF;

		END IF;

	END PROCESS;

	-- Handle AXIS stream
	PROCESS (aclk)
	BEGIN

		IF rising_edge(aclk) THEN

			IF aresetn = '0' THEN
				s_axis_tready_int <= '0';
				m_axis_tvalid_int <= '0';
				m_axis_tlast <= '0';

			ELSE
				-- Clear valid flag when master interface is ready
				IF m_axis_tready = '1' THEN
					m_axis_tvalid_int <= '0';
				END IF;

				IF s_axis_tvalid = '1' AND (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
					IF volume_exp_mult >= 0 THEN
						m_axis_tdata <= STD_LOGIC_VECTOR(
							shift_left(
								resize(
									signed(s_axis_tdata),
									m_axis_tdata'LENGTH
								),
								volume_exp_mult
							)
						);
					ELSE
						m_axis_tdata <= STD_LOGIC_VECTOR(
							shift_right(
								resize(
									signed(s_axis_tdata),
									m_axis_tdata'LENGTH
								),
								-volume_exp_mult
							)
						);
					END IF;
					s_axis_tready_int <= '1';
					m_axis_tvalid_int <= '1';
					m_axis_tlast <= s_axis_tlast;

				ELSE
					s_axis_tready_int <= '0';
				END IF;

			END IF;

		END IF;

	END PROCESS;

END Behavioral;