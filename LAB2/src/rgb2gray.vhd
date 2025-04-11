---------- DEFAULT LIBRARIES -------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.MATH_REAL.ALL; -- For logarithmic calculations (used for a constant)
------------------------------------

---------- OTHER LIBRARIES ---------
-- NONE
------------------------------------

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
			BIT_DEPTH : INTEGER := 8
		);
		PORT (
			dividend : IN UNSIGNED(BIT_DEPTH + 1 DOWNTO 0);
			gray : OUT UNSIGNED(BIT_DEPTH - 1 DOWNTO 0));
	END COMPONENT divider_by_3;

	TYPE state_type IS (WAIT_R, WAIT_G, WAIT_B);
	SIGNAL state : state_type := WAIT_R;

	SIGNAL r_val, g_val : unsigned(7 DOWNTO 0);
	SIGNAL sum : unsigned(9 DOWNTO 0);
	SIGNAL gray : UNSIGNED(7 DOWNTO 0);

BEGIN

	DIVIDER : divider_by_3
	GENERIC MAP(
		BIT_DEPTH => 8
	)
	PORT MAP(
		dividend => sum,
		gray => gray
	);

	PROCESS (clk)
	BEGIN
		IF rising_edge(clk) THEN
			IF resetn = '0' THEN
				-- Reset all signals
				state <= WAIT_R;
				s_axis_tready <= '1';
				m_axis_tvalid <= '0';
				m_axis_tlast <= '0';
				m_axis_tdata <= (OTHERS => '0');
				r_val <= (OTHERS => '0');
				g_val <= (OTHERS => '0');
				sum <= (OTHERS => '0');
			ELSE
				-- Default control signals
				s_axis_tready <= '1';
				m_axis_tlast <= '0';

				-- If downstream is ready, send the grayscale pixel
				IF m_axis_tready = '1' THEN
					m_axis_tdata <= STD_LOGIC_VECTOR(gray);
					m_axis_tlast <= s_axis_tlast;
				END IF;

				CASE state IS
					WHEN WAIT_R =>
						IF s_axis_tvalid = '1' THEN
							r_val <= unsigned(s_axis_tdata);
							state <= WAIT_G;
						END IF;

					WHEN WAIT_G =>
						IF s_axis_tvalid = '1' THEN
							g_val <= unsigned(s_axis_tdata);
							state <= WAIT_B;
						END IF;

					WHEN WAIT_B =>
						IF s_axis_tvalid = '1' THEN
							sum <= ('0' & '0' & r_val) + ('0' & '0' & g_val) + ('0' & '0' & unsigned(s_axis_tdata));
							m_axis_tvalid <= '1';
							state <= WAIT_R;
						END IF;

				END CASE;
			END IF;
		END IF;
	END PROCESS;

END ARCHITECTURE;