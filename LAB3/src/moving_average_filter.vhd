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

	-- RX
	SIGNAL samples_rx : sample_array := (OTHERS => (OTHERS => '0'));
	SIGNAL sum_rx : signed(TDATA_WIDTH + FILTER_ORDER_POWER - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL wr_ptr_rx : INTEGER RANGE 0 TO FILTER_ORDER - 1 := 0;

	-- LX
	SIGNAL samples_lx : sample_array := (OTHERS => (OTHERS => '0'));
	SIGNAL sum_lx : signed(TDATA_WIDTH + FILTER_ORDER_POWER - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL wr_ptr_lx : INTEGER RANGE 0 TO FILTER_ORDER - 1 := 0;

	-- Trigger signal to indicate when to output data
	SIGNAL trigger : STD_LOGIC := '0';

	-- Output signals
	SIGNAL s_axis_tready_int : STD_LOGIC := '0';
	SIGNAL s_axis_tlast_reg : STD_LOGIC := '0';
	SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';

BEGIN

	-- Assigning the output signals
	m_axis_tvalid <= m_axis_tvalid_int;
	s_axis_tready <= s_axis_tready_int;

	PROCESS (aclk)
	BEGIN

		IF rising_edge(aclk) THEN

			IF aresetn = '0' THEN
				samples_rx <= (OTHERS => (OTHERS => '0'));
				samples_lx <= (OTHERS => (OTHERS => '0'));
				sum_rx <= (OTHERS => '0');
				sum_lx <= (OTHERS => '0');
				wr_ptr_rx <= 0;
				wr_ptr_lx <= 0;

				s_axis_tlast_reg <= '0';
				s_axis_tready_int <= '0';
				m_axis_tvalid_int <= '0';
				m_axis_tlast <= '0';

			ELSE
				-- Clear valid flag when master interface is ready
				IF m_axis_tready = '1' THEN
					m_axis_tvalid_int <= '0';
				END IF;

				-- Data output logic
				IF trigger = '1' AND (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
					IF s_axis_tlast_reg = '1' THEN
						m_axis_tdata <= STD_LOGIC_VECTOR(
							resize(
								shift_right(
									sum_rx,
									FILTER_ORDER_POWER
								),
								m_axis_tdata'length
							)
						);

					ELSE
						m_axis_tdata <= STD_LOGIC_VECTOR(
							resize(
								shift_right(
									sum_lx,
									FILTER_ORDER_POWER
								),
								m_axis_tdata'length
							)
						);

					END IF;
					
					m_axis_tlast <= s_axis_tlast_reg;

					m_axis_tvalid_int <= '1';
					trigger <= '0';
				END IF;

				-- Data input logic
				IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN	
					IF s_axis_tlast = '1' THEN
						-- Right channel
						-- Circular buffer overwrite oldest saple with the new one from next clk cycle
						samples_rx(wr_ptr_rx) <= signed(s_axis_tdata);

						-- Update the write pointer
						wr_ptr_rx <= (wr_ptr_rx + 1) MOD FILTER_ORDER;

						-- Update the sum_rx removing the oldest sample and adding the new one
						sum_rx <= sum_rx - samples_rx(wr_ptr_rx) + signed(s_axis_tdata);

						s_axis_tlast_reg <= s_axis_tlast;
					ELSE
						-- Left channel
						-- Circular buffer overwrite oldest saple with the new one from next clk cycle
						samples_lx(wr_ptr_lx) <= signed(s_axis_tdata);

						-- Update the write pointer
						wr_ptr_lx <= (wr_ptr_lx + 1) MOD FILTER_ORDER;

						-- Update the sum_rx removing the oldest sample and adding the new one
						sum_lx <= sum_lx - samples_lx(wr_ptr_lx) + signed(s_axis_tdata);

						s_axis_tlast_reg <= s_axis_tlast;
					END IF;

					trigger <= '1';

				END IF;

				s_axis_tready_int <= m_axis_tready OR NOT m_axis_tvalid_int;

			END IF;

		END IF;

	END PROCESS;

END Behavioral;