LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY volume_controller IS
	GENERIC (
		TDATA_WIDTH : POSITIVE := 24;
		VOLUME_WIDTH : POSITIVE := 10;
		VOLUME_STEP_2 : POSITIVE := 6; -- i.e., volume_values_per_step = 2**VOLUME_STEP_2
		HIGHER_BOUND : INTEGER := 2 ** 23 - 1; -- Inclusive
		LOWER_BOUND : INTEGER := - 2 ** 23 -- Inclusive
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

		volume : IN STD_LOGIC_VECTOR(VOLUME_WIDTH - 1 DOWNTO 0)
	);
END volume_controller;

ARCHITECTURE Behavioral OF volume_controller IS

	-- Component declarations
	COMPONENT volume_multiplier IS
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
	END COMPONENT;

	COMPONENT volume_saturator IS
		GENERIC (
			TDATA_WIDTH : POSITIVE := 24;
			VOLUME_WIDTH : POSITIVE := 10;
			VOLUME_STEP_2 : POSITIVE := 6; -- i.e., number_of_steps = 2**VOLUME_STEP_2
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
	END COMPONENT;

	-- Internal AXIS signals
	SIGNAL int_axis_tvalid : STD_LOGIC;
	SIGNAL int_axis_tready : STD_LOGIC;
	SIGNAL int_axis_tdata : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 + 2 ** (VOLUME_WIDTH - VOLUME_STEP_2 - 1) DOWNTO 0);
	SIGNAL int_axis_tlast : STD_LOGIC;

BEGIN

	-- Instantiate volume_multiplier
	volume_multiplier_inst : volume_multiplier
		GENERIC MAP(
			TDATA_WIDTH => TDATA_WIDTH,
			VOLUME_WIDTH => VOLUME_WIDTH,
			VOLUME_STEP_2 => VOLUME_STEP_2
		)
		PORT MAP(
			aclk => aclk,
			aresetn => aresetn,

			s_axis_tvalid => s_axis_tvalid,
			s_axis_tdata => s_axis_tdata,
			s_axis_tlast => s_axis_tlast,
			s_axis_tready => s_axis_tready,

			m_axis_tvalid => int_axis_tvalid,
			m_axis_tdata => int_axis_tdata,
			m_axis_tlast => int_axis_tlast,
			m_axis_tready => int_axis_tready,

			volume => volume
		);

	-- Instantiate volume_saturator
	volume_saturator_inst : volume_saturator
		GENERIC MAP(
			TDATA_WIDTH => TDATA_WIDTH,
			VOLUME_WIDTH => VOLUME_WIDTH,
			VOLUME_STEP_2 => VOLUME_STEP_2,
			HIGHER_BOUND => HIGHER_BOUND,
			LOWER_BOUND => LOWER_BOUND
		)
		PORT MAP(
			aclk => aclk,
			aresetn => aresetn,

			s_axis_tvalid => int_axis_tvalid,
			s_axis_tdata => int_axis_tdata,
			s_axis_tlast => int_axis_tlast,
			s_axis_tready => int_axis_tready,

			m_axis_tvalid => m_axis_tvalid,
			m_axis_tdata => m_axis_tdata,
			m_axis_tlast => m_axis_tlast,
			m_axis_tready => m_axis_tready
		);

END Behavioral;