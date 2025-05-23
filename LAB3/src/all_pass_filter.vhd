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

	SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';

BEGIN

    -- This architecture mimics the structure, handshake logic, and timing (clock cycles spent)
    -- of the moving_average_filter, but does not process or modify the samples.
    -- It simply passes input data to the output unchanged, ensuring the same latency and interface behavior.

	-- Assigning the output signals
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

				-- Handle data transfer
				IF s_axis_tvalid = '1' AND m_axis_tready = '1' THEN
					m_axis_tvalid_int <= '1';
					m_axis_tdata <= s_axis_tdata;
					m_axis_tlast <= s_axis_tlast;
					
				END IF;

			END IF;

		END IF;

	END PROCESS;

END Behavioral;