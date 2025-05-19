LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY balance_controller IS
	GENERIC (
		TDATA_WIDTH : POSITIVE := 24;
		BALANCE_WIDTH : POSITIVE := 10;
		BALANCE_STEP_2 : POSITIVE := 6 -- i.e., balance_values_per_step = 2**VOLUME_STEP_2
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

	CONSTANT BAL_MID : INTEGER := 2 ** (BALANCE_WIDTH - 1); -- 512 per 10 bit
	CONSTANT DEAD_ZONE : INTEGER := 32;
	CONSTANT BLOCK_SIZE : INTEGER := 64;

	SIGNAL tvalid_reg : STD_LOGIC := '0';
	SIGNAL tdata_reg : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL tlast_reg : STD_LOGIC := '0';

	SIGNAL left_shift : INTEGER RANGE 0 TO BALANCE_WIDTH := 0;
	SIGNAL right_shift : INTEGER RANGE 0 TO BALANCE_WIDTH := 0;
	SIGNAL bal_int : INTEGER;

BEGIN

	-- Handshake & cattura dati in ingresso
	PROCESS (aclk)
	BEGIN
		IF rising_edge(aclk) THEN
			IF aresetn = '0' THEN
				tvalid_reg <= '0';
				tdata_reg <= (OTHERS => '0');
				tlast_reg <= '0';
			ELSIF s_axis_tvalid = '1' AND m_axis_tready = '1' THEN
				tvalid_reg <= '1';
				tdata_reg <= s_axis_tdata;
				tlast_reg <= s_axis_tlast;
			ELSIF m_axis_tready = '1' THEN
				tvalid_reg <= '0';
			END IF;
		END IF;
	END PROCESS;

	s_axis_tready <= m_axis_tready;

	bal_int <= to_integer(unsigned(balance));

	-- Calcolo shift esponenziale per balance con zona morta centrale e blocchi da 64
	left_shift <= ((bal_int - (BAL_MID + DEAD_ZONE)) / BLOCK_SIZE) WHEN bal_int > (BAL_MID + DEAD_ZONE) ELSE 0;
	right_shift <= (((BAL_MID - DEAD_ZONE) - bal_int) / BLOCK_SIZE) WHEN bal_int < (BAL_MID - DEAD_ZONE) ELSE 0;

	-- Applicazione gain esponenziale tramite shift (process combinatorio)
	PROCESS (tvalid_reg, tlast_reg, tdata_reg, left_shift, right_shift)
	BEGIN
		IF tvalid_reg = '1' THEN
			IF tlast_reg = '0' THEN -- left
				m_axis_tdata <= STD_LOGIC_VECTOR(shift_right(signed(tdata_reg), left_shift));
			ELSE -- right
				m_axis_tdata <= STD_LOGIC_VECTOR(shift_right(signed(tdata_reg), right_shift));
			END IF;
		ELSE
			m_axis_tdata <= (OTHERS => '0');
		END IF;
	END PROCESS;

	m_axis_tvalid <= tvalid_reg;
	m_axis_tlast <= tlast_reg;

END Behavioral;