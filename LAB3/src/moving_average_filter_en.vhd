LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY moving_average_filter_en IS
	GENERIC (
		-- Filter order expressed as 2^(FILTER_ORDER_POWER)
		FILTER_ORDER_POWER : INTEGER := 5;

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

		enable_filter : IN STD_LOGIC
	);
END moving_average_filter_en;

ARCHITECTURE Behavioral OF moving_average_filter_en IS

	-- Component declarations
	COMPONENT all_pass_filter IS
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
			m_axis_tready : IN STD_LOGIC
		);
	END COMPONENT;

	COMPONENT moving_average_filter IS
		GENERIC (
			FILTER_ORDER_POWER : INTEGER := 5;
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
			m_axis_tready : IN STD_LOGIC
		);
	END COMPONENT;

	-- Internal signals for the all-pass filter
	SIGNAL all_pass_s_tvalid : STD_LOGIC;
	SIGNAL all_pass_s_tready : STD_LOGIC;

	SIGNAL all_pass_m_tvalid : STD_LOGIC;
	SIGNAL all_pass_m_tdata : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
	SIGNAL all_pass_m_tlast : STD_LOGIC;
	SIGNAL all_pass_m_tready : STD_LOGIC;

	-- Internal signals for the moving average filter
	SIGNAL moving_avg_s_tvalid : STD_LOGIC;
	SIGNAL moving_avg_s_tready : STD_LOGIC;
	
	SIGNAL moving_avg_m_tvalid : STD_LOGIC;
	SIGNAL moving_avg_m_tdata : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
	SIGNAL moving_avg_m_tlast : STD_LOGIC;
	SIGNAL moving_avg_m_tready : STD_LOGIC;

BEGIN

	-- Instantiate the all-pass filter
	all_pass_inst : all_pass_filter
	GENERIC MAP(
		TDATA_WIDTH => TDATA_WIDTH
	)
	PORT MAP(
		aclk => aclk,
		aresetn => aresetn,

		s_axis_tvalid => all_pass_s_tvalid,
		s_axis_tdata => s_axis_tdata,
		s_axis_tlast => s_axis_tlast,
		s_axis_tready => all_pass_s_tready,

		m_axis_tvalid => all_pass_m_tvalid,
		m_axis_tdata => all_pass_m_tdata,
		m_axis_tlast => all_pass_m_tlast,
		m_axis_tready => all_pass_m_tready
	);

	-- Instantiate the moving average filter
	moving_avg_inst : moving_average_filter
	GENERIC MAP(
		FILTER_ORDER_POWER => FILTER_ORDER_POWER,
		TDATA_WIDTH => TDATA_WIDTH
	)
	PORT MAP(
		aclk => aclk,
		aresetn => aresetn,

		s_axis_tvalid => moving_avg_s_tvalid,
		s_axis_tdata => s_axis_tdata,
		s_axis_tlast => s_axis_tlast,
		s_axis_tready => moving_avg_s_tready,

		m_axis_tvalid => moving_avg_m_tvalid,
		m_axis_tdata => moving_avg_m_tdata,
		m_axis_tlast => moving_avg_m_tlast,
		m_axis_tready => moving_avg_m_tready
	);

	-- Assign filter control signals based on enable_filter
	all_pass_s_tvalid    <= s_axis_tvalid WHEN enable_filter = '0' ELSE '0';
	moving_avg_s_tvalid  <= s_axis_tvalid WHEN enable_filter = '1' ELSE '0';

	all_pass_m_tready    <= m_axis_tready WHEN enable_filter = '0' ELSE '0';
	moving_avg_m_tready  <= m_axis_tready WHEN enable_filter = '1' ELSE '0';

	-- Main AXIS assignments based on enable_filter
	s_axis_tready        <= all_pass_s_tready   WHEN enable_filter = '0' ELSE moving_avg_s_tready;
	m_axis_tvalid        <= all_pass_m_tvalid   WHEN enable_filter = '0' ELSE moving_avg_m_tvalid;
	m_axis_tdata         <= all_pass_m_tdata    WHEN enable_filter = '0' ELSE moving_avg_m_tdata;
	m_axis_tlast         <= all_pass_m_tlast    WHEN enable_filter = '0' ELSE moving_avg_m_tlast;

END Behavioral;