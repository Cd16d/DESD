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
	SIGNAL wr_ptr : INTEGER RANGE 0 TO FILTER_ORDER - 1 := 0;

	SIGNAL trigger : STD_LOGIC := '0'; -- Used to control when to send data

	SIGNAL s_axis_tready_int : STD_LOGIC := '0';
	SIGNAL s_axis_tlast_reg : STD_LOGIC := '0';
	SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';

BEGIN

	-- Output assignments
	m_axis_tvalid <= m_axis_tvalid_int;
	s_axis_tready <= s_axis_tready_int;

	PROCESS (aclk)
	BEGIN

		IF rising_edge(aclk) THEN

			IF aresetn = '0' THEN
				samples <= (OTHERS => (OTHERS => '0'));
				sum <= (OTHERS => '0');
				wr_ptr <= 0;

				trigger <= '0';

				s_axis_tready_int <= '0';
				m_axis_tvalid_int <= '0';

				m_axis_tlast <= '0';
				m_axis_tdata <= (OTHERS => '0');

			ELSE
				-- Set the ready signal for the slave interface
				s_axis_tready_int <= m_axis_tready OR NOT m_axis_tvalid_int;

				-- Get and process input data
				IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
					-- Circular buffer overwrite oldest saple with the new one from next clk cycle
					samples(wr_ptr) <= signed(s_axis_tdata);

					-- Update the write pointer
					wr_ptr <= (wr_ptr + 1) MOD FILTER_ORDER;

					-- Update the sum removing the oldest sample and adding the new one
					sum <= sum - samples(wr_ptr) + signed(s_axis_tdata);

					s_axis_tlast_reg <= s_axis_tlast; -- Store the last signal
					trigger <= '1'; -- Trigger the output

				END IF;

				-- Clear valid flag when master interface is ready
				IF m_axis_tready = '1' THEN
					m_axis_tvalid_int <= '0';
				END IF;

				-- Send data when triggered and receiver is ready 
				IF trigger = '1' AND (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
						m_axis_tvalid_int <= '1';
						m_axis_tlast <= s_axis_tlast_reg;
						m_axis_tdata <= STD_LOGIC_VECTOR(sum(sum'high DOWNTO FILTER_ORDER_POWER)); -- Average value
						
						-- Reset trigger
						trigger <= '0';
						
				END IF;

			END IF;

		END IF;

	END PROCESS;

END Behavioral;