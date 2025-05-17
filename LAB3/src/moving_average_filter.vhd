LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY moving_average_filter IS
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
		m_axis_tready : IN STD_LOGIC
	);
END moving_average_filter;

ARCHITECTURE Behavioral OF moving_average_filter IS

	CONSTANT FILTER_ORDER : INTEGER := 2 ** FILTER_ORDER_POWER;

	TYPE sample_array IS ARRAY (0 TO FILTER_ORDER - 1) OF signed(TDATA_WIDTH - 1 DOWNTO 0);
	SIGNAL samples : sample_array := (OTHERS => (OTHERS => '0'));

	SIGNAL sum : signed(TDATA_WIDTH + FILTER_ORDER_POWER - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL sample_count : INTEGER RANGE 0 TO FILTER_ORDER := 0;

	SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';

BEGIN

	-- Output assignments
	m_axis_tvalid <= m_axis_tvalid_int;
	s_axis_tready <= m_axis_tready OR NOT m_axis_tvalid_int;

	PROCESS (aclk)

		VARIABLE new_sum : signed(TDATA_WIDTH + FILTER_ORDER_POWER - 1 DOWNTO 0);
		VARIABLE oldest_sample : signed(TDATA_WIDTH - 1 DOWNTO 0);
		VARIABLE avg : signed(TDATA_WIDTH - 1 DOWNTO 0);
		VARIABLE wr_ptr : INTEGER RANGE 0 TO FILTER_ORDER - 1 := 0;

	BEGIN

		IF rising_edge(aclk) THEN

			IF aresetn = '0' THEN
				samples <= (OTHERS => (OTHERS => '0'));
				sum <= (OTHERS => '0');
				sample_count <= 0;
				m_axis_tvalid_int <= '0';
				m_axis_tlast <= '0';
				m_axis_tdata <= (OTHERS => '0');
				wr_ptr := 0;

			ELSE
				m_axis_tvalid_int <= '0';
				m_axis_tlast <= '0';

				IF s_axis_tvalid = '1' AND (m_axis_tready = '1' OR m_axis_tvalid_int = '0') THEN
					-- Circular buffer
					oldest_sample := samples(wr_ptr);
					samples(wr_ptr) <= signed(s_axis_tdata);
					wr_ptr := (wr_ptr + 1) MOD FILTER_ORDER;

					-- Aggiorna la somma
					new_sum := sum - oldest_sample + signed(s_axis_tdata);
					sum <= new_sum;

					-- Aggiorna il conteggio solo fino a 32
					IF sample_count < FILTER_ORDER THEN
						sample_count <= sample_count + 1;
					END IF;

					-- Calcola la media sempre su 32 (anche se sample_count < 32)
					avg := new_sum(TDATA_WIDTH + FILTER_ORDER_POWER - 1 DOWNTO FILTER_ORDER_POWER);

					m_axis_tdata <= STD_LOGIC_VECTOR(avg);
					m_axis_tvalid_int <= '1';
					m_axis_tlast <= s_axis_tlast;

				END IF;
			END IF;

		END IF;

	END PROCESS;

END Behavioral;