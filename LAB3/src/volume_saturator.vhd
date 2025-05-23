LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY volume_saturator IS
	GENERIC (
		TDATA_WIDTH : POSITIVE := 24;
		VOLUME_WIDTH : POSITIVE := 10;
		VOLUME_STEP_2 : POSITIVE := 6; -- i.e., number_of_steps = 2**(VOLUME_STEP_2)
		HIGHER_BOUND : INTEGER := 2 ** 15 - 1; -- Inclusive
		LOWER_BOUND : INTEGER := - 2 ** 15 -- Inclusive
	);
	PORT (
		aclk : IN STD_LOGIC;
		aresetn : IN STD_LOGIC;

		s_axis_tvalid : IN STD_LOGIC;
		s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 + 2 ** (VOLUME_WIDTH - VOLUME_STEP_2 - 1) DOWNTO 0);
		s_axis_tlast : IN STD_LOGIC;
		s_axis_tready : OUT STD_LOGIC;

		m_axis_tvalid : OUT STD_LOGIC;
		m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
		m_axis_tlast : OUT STD_LOGIC;
		m_axis_tready : IN STD_LOGIC
	);
END volume_saturator;

ARCHITECTURE Behavioral OF volume_saturator IS

	CONSTANT HIGHER_BOUND_VEC : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0) := STD_LOGIC_VECTOR(to_signed(HIGHER_BOUND, TDATA_WIDTH));
	CONSTANT LOWER_BOUND_VEC : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0) := STD_LOGIC_VECTOR(to_signed(LOWER_BOUND, TDATA_WIDTH));

	SIGNAL m_axis_tvalid_int : STD_LOGIC;

BEGIN
	-- Output assignments
	m_axis_tvalid <= m_axis_tvalid_int;
	s_axis_tready <= (m_axis_tready OR NOT m_axis_tvalid_int) AND aresetn;

	PROCESS (aclk)
	BEGIN

		IF rising_edge(aclk) THEN

			IF aresetn = '0' THEN
				m_axis_tvalid_int <= '0';
				m_axis_tlast <= '0';

			ELSE				
				-- Clear valid flag when master interface is ready
				IF m_axis_tready = '1' THEN
					m_axis_tvalid_int <= '0';
				END IF;

				-- Handle the data flow
				IF s_axis_tvalid = '1' AND m_axis_tready = '1' THEN
					-- Check if the input data is within the bounds else saturate
					IF signed(s_axis_tdata) > signed(HIGHER_BOUND_VEC) THEN
						m_axis_tdata <= HIGHER_BOUND_VEC;

					ELSIF signed(s_axis_tdata) < signed(LOWER_BOUND_VEC) THEN
						m_axis_tdata <= LOWER_BOUND_VEC;

					ELSE
						m_axis_tdata <= STD_LOGIC_VECTOR(resize(signed(s_axis_tdata), TDATA_WIDTH));
						
					END IF;

					m_axis_tvalid_int <= '1';
					m_axis_tlast <= s_axis_tlast;

				END IF;

			END IF;

		END IF;

	END PROCESS;

END Behavioral;