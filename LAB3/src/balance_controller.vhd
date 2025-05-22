LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY balance_controller IS
	GENERIC (
		TDATA_WIDTH : POSITIVE := 24;
		BALANCE_WIDTH : POSITIVE := 10;
		BALANCE_STEP_2 : POSITIVE := 6 -- i.e., balance_values_per_step = 2**BALANCE_STEP_2
	);
	PORT (
		aclk : IN STD_LOGIC;
		aresetn : IN STD_LOGIC;

		s_axis_tvalid : IN STD_LOGIC;
		s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
		s_axis_tready : OUT STD_LOGIC;
		s_axis_tlast : IN STD_LOGIC;

		m_axis_tvalid : OUT STD_LOGIC;
		m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
		m_axis_tready : IN STD_LOGIC;
		m_axis_tlast : OUT STD_LOGIC;

		balance : IN STD_LOGIC_VECTOR(BALANCE_WIDTH - 1 DOWNTO 0)
	);
END balance_controller;

ARCHITECTURE Behavioral OF balance_controller IS

	CONSTANT BALANCE_STEPS : INTEGER := (2 ** (BALANCE_WIDTH - 1)) / (2 ** BALANCE_STEP_2) + 1;
	CONSTANT BAL_MID : INTEGER := 2 ** (BALANCE_WIDTH - 1); -- 512 for 10 bit
	CONSTANT BLOCK_SIZE : INTEGER := 2 ** BALANCE_STEP_2;
	CONSTANT DEAD_ZONE : INTEGER := BLOCK_SIZE / 2;

	SIGNAL left_channel : INTEGER RANGE 0 TO BALANCE_STEPS := 0;
	SIGNAL right_channel : INTEGER RANGE 0 TO BALANCE_STEPS := 0;

	SIGNAL m_axis_tvalid_int : STD_LOGIC;

BEGIN
	-- Assigning the output signals
	m_axis_tvalid <= m_axis_tvalid_int;
	s_axis_tready <= m_axis_tready AND aresetn;

	-- Balance to exp
	PROCESS (aclk)
	BEGIN

		IF rising_edge(aclk) THEN

			IF aresetn = '0' THEN
				left_channel <= 0;
				right_channel <= 0;

			ELSE
				-- Balance left and right channels
				IF unsigned(balance) > (BAL_MID + DEAD_ZONE) THEN
					left_channel <= to_integer((unsigned(balance) - (BAL_MID + DEAD_ZONE)) SRL BALANCE_STEP_2) + 1;
				ELSE
					left_channel <= 0;
				END IF;

				IF unsigned(balance) < (BAL_MID - DEAD_ZONE) THEN
					right_channel <= to_integer(((BAL_MID - DEAD_ZONE) - unsigned(balance)) SRL BALANCE_STEP_2) + 1;
				ELSE
					right_channel <= 0;
				END IF;

			END IF;

		END IF;

	END PROCESS;

	-- Handle AXIS stream
	PROCESS (aclk)
	BEGIN

		IF rising_edge(aclk) THEN

			IF aresetn = '0' THEN
				m_axis_tvalid_int <= '0';
				m_axis_tlast <= '0';
				m_axis_tdata <= (OTHERS => '0');

			ELSE
				-- Default output signals
				m_axis_tlast <= '0';

				-- Clear valid flag when master interface is ready
				IF m_axis_tready = '1' THEN
					m_axis_tvalid_int <= '0';
				END IF;

				-- Handle the data flow
				IF s_axis_tvalid = '1' AND m_axis_tready = '1' THEN
					-- Joystick datasheet: 	(x-axis) a 0 value corresponds to the axis
					--                      being tilted fully to the left and a value of 1023
					--                      corresponds fully to the right
					IF s_axis_tlast = '0' THEN -- left
						m_axis_tdata <= STD_LOGIC_VECTOR(shift_right(signed(s_axis_tdata), left_channel));
					ELSE -- right
						m_axis_tdata <= STD_LOGIC_VECTOR(shift_right(signed(s_axis_tdata), right_channel));
					END IF;

					m_axis_tvalid_int <= '1';
					m_axis_tlast <= s_axis_tlast;

				END IF;

			END IF;

		END IF;

	END PROCESS;

END Behavioral;