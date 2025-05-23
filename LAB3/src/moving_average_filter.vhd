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

	-- DX
	SIGNAL samples_dx : sample_array := (OTHERS => (OTHERS => '0'));
	SIGNAL sum_dx : signed(TDATA_WIDTH + FILTER_ORDER_POWER - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL wr_ptr_dx : INTEGER RANGE 0 TO FILTER_ORDER - 1 := 0;

	-- SX
	SIGNAL samples_sx : sample_array := (OTHERS => (OTHERS => '0'));
	SIGNAL sum_sx : signed(TDATA_WIDTH + FILTER_ORDER_POWER - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL wr_ptr_sx : INTEGER RANGE 0 TO FILTER_ORDER - 1 := 0;

	SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';

BEGIN

	-- Assigning the output signals
	m_axis_tvalid <= m_axis_tvalid_int;
	s_axis_tready <= (m_axis_tready OR NOT m_axis_tvalid_int) AND aresetn;

	PROCESS (aclk)
	BEGIN

		IF rising_edge(aclk) THEN

			IF aresetn = '0' THEN
				samples_dx <= (OTHERS => (OTHERS => '0'));
				samples_sx <= (OTHERS => (OTHERS => '0'));
				sum_dx <= (OTHERS => '0');
				sum_sx <= (OTHERS => '0');
				wr_ptr_dx <= 0;
				wr_ptr_sx <= 0;

				m_axis_tvalid_int <= '0';
				m_axis_tlast <= '0';

			ELSE
				-- Clear valid flag when master interface is ready
				IF m_axis_tready = '1' THEN
					m_axis_tvalid_int <= '0';
				END IF;

				-- Get and process data
				IF s_axis_tvalid = '1' AND m_axis_tready = '1' THEN

					IF s_axis_tlast = '1' THEN 
						-- Right channel
						-- Circular buffer overwrite oldest saple with the new one from next clk cycle
						samples_dx(wr_ptr_dx) <= signed(s_axis_tdata);

						-- Update the write pointer
						wr_ptr_dx <= (wr_ptr_dx + 1) MOD FILTER_ORDER;

						-- Update the sum_dx removing the oldest sample and adding the new one
						sum_dx <= sum_dx - samples_dx(wr_ptr_dx) + signed(s_axis_tdata);

						-- Calculate the average and send it to the master interface
						m_axis_tdata <= STD_LOGIC_VECTOR(
							resize(
								shift_right(
									sum_dx - samples_dx(wr_ptr_dx) + signed(s_axis_tdata),
									FILTER_ORDER_POWER
								),
								m_axis_tdata'length
							)
						);
					ELSE
						-- Left channel
						-- Circular buffer overwrite oldest saple with the new one from next clk cycle
						samples_sx(wr_ptr_sx) <= signed(s_axis_tdata);

						-- Update the write pointer
						wr_ptr_sx <= (wr_ptr_sx + 1) MOD FILTER_ORDER;

						-- Update the sum_dx removing the oldest sample and adding the new one
						sum_sx <= sum_sx - samples_sx(wr_ptr_sx) + signed(s_axis_tdata);

						-- Calculate the average and send it to the master interface
						m_axis_tdata <= STD_LOGIC_VECTOR(
							resize(
								shift_right(
									sum_sx - samples_sx(wr_ptr_sx) + signed(s_axis_tdata),
									FILTER_ORDER_POWER
								),
								m_axis_tdata'length
							)
						);
					END IF;

					m_axis_tvalid_int <= '1';
					m_axis_tlast <= s_axis_tlast;

				END IF;

			END IF;

		END IF;

	END PROCESS;

END Behavioral;