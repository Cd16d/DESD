LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY all_pass_filter IS
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
END all_pass_filter;

ARCHITECTURE Behavioral OF all_pass_filter IS

	SIGNAL trigger : STD_LOGIC := '0'; -- Used to control when to send data

	SIGNAL s_axis_tlast_reg : STD_LOGIC := '0';
	SIGNAL s_axis_tready_int : STD_LOGIC := '0';
	SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';

BEGIN

    -- This architecture mimics the structure, handshake logic, and timing (clock cycles spent)
    -- of the moving_average_filter, but does not process or modify the samples.
    -- It simply passes input data to the output unchanged, ensuring the same latency and interface behavior.

	-- Output assignments
	s_axis_tready <= s_axis_tready_int;
	m_axis_tvalid <= m_axis_tvalid_int;

	PROCESS (aclk)
	BEGIN
		IF rising_edge(aclk) THEN

			IF aresetn = '0' THEN
				s_axis_tready_int <= '0';
				m_axis_tvalid_int <= '0';

			ELSE
				-- Set the ready signal for the slave interface
				s_axis_tready_int <= m_axis_tready OR NOT m_axis_tvalid_int;

				-- Get the data from the slave interface
				IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN
					s_axis_tlast_reg <= s_axis_tlast; -- Store the last signal
					trigger <= '1'; -- Trigger the output

				END IF;

				-- Clear valid flag when master interface is ready
				IF m_axis_tready = '1' THEN
					m_axis_tvalid_int <= '0';
				END IF;

				-- Send data to the master interface
				IF trigger = '1' AND (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
					m_axis_tvalid_int <= '1'; -- Set valid flag for master interface
					m_axis_tlast <= s_axis_tlast_reg;
					m_axis_tdata <= s_axis_tdata;

					-- Reset trigger
					trigger <= '0';
				END IF;

			END IF;

		END IF;

	END PROCESS;

END Behavioral;