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

	SIGNAL trigger : STD_LOGIC := '0';

	SIGNAL s_axis_tready_int : STD_LOGIC := '0';
	SIGNAL s_axis_tlast_reg : STD_LOGIC := '0';
    SIGNAL m_axis_tdata_temp : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';

BEGIN

    -- This architecture mimics the structure, handshake logic, and timing (clock cycles spent)
    -- of the moving_average_filter, but does not process or modify the samples.
    -- It simply passes input data to the output unchanged, ensuring the same latency and interface behavior.

	-- Assigning the output signals
	m_axis_tvalid <= m_axis_tvalid_int;
	s_axis_tready <= s_axis_tready_int;

	PROCESS (aclk)
	BEGIN
		IF rising_edge(aclk) THEN

			IF aresetn = '0' THEN
				-- Reset all internal signals
				trigger <= '0';

				s_axis_tlast_reg <= '0';
				s_axis_tready_int <= '0';
				m_axis_tdata_temp <= (OTHERS => '0');
				m_axis_tvalid_int <= '0';
				m_axis_tlast <= '0';

			ELSE
				-- Clear valid flag when master interface is ready
				IF m_axis_tready = '1' THEN
					m_axis_tvalid_int <= '0';
				END IF;

				-- Data output logic
				IF trigger = '1' AND (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
					m_axis_tdata <= m_axis_tdata_temp;
					m_axis_tlast <= s_axis_tlast_reg;

					m_axis_tvalid_int <= '1';
					trigger <= '0';
					
				END IF;

				-- Data input logic
				IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN				
					s_axis_tlast_reg <= s_axis_tlast;
					m_axis_tdata_temp <= s_axis_tdata;
					
					trigger <= '1';

				END IF;

				s_axis_tready_int <= m_axis_tready OR NOT m_axis_tvalid_int;

			END IF;

		END IF;

	END PROCESS;

END Behavioral;