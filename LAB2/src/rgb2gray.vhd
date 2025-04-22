LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY rgb2gray IS
	PORT (
		clk : IN STD_LOGIC;
		resetn : IN STD_LOGIC;

		m_axis_tvalid : OUT STD_LOGIC;
		m_axis_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		m_axis_tready : IN STD_LOGIC;
		m_axis_tlast : OUT STD_LOGIC;

		s_axis_tvalid : IN STD_LOGIC;
		s_axis_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		s_axis_tready : OUT STD_LOGIC;
		s_axis_tlast : IN STD_LOGIC
	);
END rgb2gray;

ARCHITECTURE Behavioral OF rgb2gray IS

	COMPONENT divider_by_3
		GENERIC (
			BIT_DEPTH : INTEGER := 7
		);
		PORT (
			dividend : IN UNSIGNED(BIT_DEPTH + 1 DOWNTO 0);
			result : OUT UNSIGNED(BIT_DEPTH - 1 DOWNTO 0)
		);
	END COMPONENT;

	TYPE state_type IS (WAIT_R, WAIT_G, WAIT_B);
	SIGNAL state : state_type := WAIT_R;

	SIGNAL r_val, g_val : UNSIGNED(7 DOWNTO 0);
	SIGNAL sum : UNSIGNED(8 DOWNTO 0);
	SIGNAL gray : UNSIGNED(6 DOWNTO 0);

	SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';
	SIGNAL s_axis_tready_int : STD_LOGIC := '0';

	SIGNAL trigger : STD_LOGIC := '0';
	SIGNAL last_seen : STD_LOGIC := '0';

BEGIN

	s_axis_tready <= s_axis_tready_int;
	m_axis_tvalid <= m_axis_tvalid_int;

	-- Divider instance
	DIVIDER : divider_by_3
	GENERIC MAP(
		BIT_DEPTH => 7
	)
	PORT MAP(
		dividend => sum,
		result => gray
	);

	PROCESS (clk)
	BEGIN
		IF rising_edge(clk) THEN
			IF resetn = '0' THEN
				-- Reset all signals
				state <= WAIT_R;

				s_axis_tready_int <= '0';
				m_axis_tvalid_int <= '0';

				m_axis_tdata <= (OTHERS => '0');
				m_axis_tlast <= '0';

				r_val <= (OTHERS => '0');
				g_val <= (OTHERS => '0');

				sum <= (OTHERS => '0');

				trigger <= '0';

			ELSE

				-- Input data - slave
				s_axis_tready_int <= m_axis_tready;

				IF s_axis_tlast = '1' THEN
					last_seen <= '1';
				ELSE
				    m_axis_tlast <= '0';
				END IF;

				-- Output data - master
				IF m_axis_tready = '1' THEN
					m_axis_tvalid_int <= '0';
				END IF;

				IF trigger = '1' AND (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
					m_axis_tvalid_int <= '1';
					m_axis_tdata <= '0' & STD_LOGIC_VECTOR(gray); -- MSB zero + 7bit gray

					IF last_seen = '1' THEN
						m_axis_tlast <= '1';
						last_seen <= '0';
					END IF;

					trigger <= '0';
				END IF;

				-- State machine for R, G, B values buffering
				CASE state IS
					WHEN WAIT_R =>
						IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
							r_val <= unsigned(s_axis_tdata);

							state <= WAIT_G;
						END IF;

					WHEN WAIT_G =>
						IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
							g_val <= unsigned(s_axis_tdata);

							state <= WAIT_B;
						END IF;

					WHEN WAIT_B =>
						IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
							sum <= RESIZE(r_val + g_val + unsigned(s_axis_tdata), sum'length);
							trigger <= '1';

							state <= WAIT_R;
						END IF;
				END CASE;
			END IF;
		END IF;
	END PROCESS;

END ARCHITECTURE;