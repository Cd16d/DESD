LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
USE IEEE.NUMERIC_STD.ALL;

ENTITY LFO IS
    GENERIC (
        CHANNEL_LENGHT : INTEGER := 24;
        JOYSTICK_LENGHT : INTEGER := 10;
        CLK_PERIOD_NS : INTEGER := 10;
        TRIANGULAR_COUNTER_LENGHT : INTEGER := 10 -- Triangular wave period length
    );
    PORT (

        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;

        lfo_period : IN STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);

        lfo_enable : IN STD_LOGIC;

        s_axis_tvalid : IN STD_LOGIC;
        s_axis_tdata : IN STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0);
        s_axis_tlast : IN STD_LOGIC;
        s_axis_tready : OUT STD_LOGIC;

        m_axis_tvalid : OUT STD_LOGIC;
        m_axis_tdata : OUT STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0);
        m_axis_tlast : OUT STD_LOGIC;
        m_axis_tready : IN STD_LOGIC
    );
END ENTITY LFO;

ARCHITECTURE Behavioral OF LFO IS

    CONSTANT LFO_COUNTER_BASE_PERIOD_US : INTEGER := 1000; -- 1ms
    CONSTANT ADJUSTMENT_FACTOR : INTEGER := 90;
    CONSTANT JSTK_CENTER_VALUE : INTEGER := 2 ** (JOYSTICK_LENGHT - 1); -- 512 for 10 bits
    CONSTANT LFO_COUNTER_BASE_CLK_CYCLES : INTEGER := LFO_COUNTER_BASE_PERIOD_US * 1000 / CLK_PERIOD_NS; -- 1ms = 100_000 clk cycles
    CONSTANT LFO_CLK_CYCLES_MIN : INTEGER := LFO_COUNTER_BASE_CLK_CYCLES - ADJUSTMENT_FACTOR * (2 ** (JOYSTICK_LENGHT - 1)); -- 53_920 clk cycles
    CONSTANT LFO_CLK_CYCLES_MAX : INTEGER := LFO_COUNTER_BASE_CLK_CYCLES + ADJUSTMENT_FACTOR * (2 ** (JOYSTICK_LENGHT - 1) - 1); -- 145_990 clk cycles

    SIGNAL step_clk_cycles_delta : INTEGER RANGE - 2 ** (JOYSTICK_LENGHT - 1) * ADJUSTMENT_FACTOR TO (2 ** (JOYSTICK_LENGHT - 1) - 1) * ADJUSTMENT_FACTOR := 0;
    SIGNAL step_clk_cycles : INTEGER RANGE LFO_CLK_CYCLES_MIN TO LFO_CLK_CYCLES_MAX := LFO_COUNTER_BASE_CLK_CYCLES;
    SIGNAL step_counter : INTEGER RANGE 0 TO LFO_CLK_CYCLES_MAX := 0;
    SIGNAL tri_counter : SIGNED(TRIANGULAR_COUNTER_LENGHT DOWNTO 0) := (OTHERS => '0');
    SIGNAL direction_up : STD_LOGIC := '1';

    SIGNAL trigger : STD_LOGIC := '0';

	SIGNAL s_axis_tready_int : STD_LOGIC := '0';
    SIGNAL s_axis_tlast_reg : STD_LOGIC := '0';
    SIGNAL m_axis_tdata_temp : SIGNED(CHANNEL_LENGHT + TRIANGULAR_COUNTER_LENGHT DOWNTO 0) := (OTHERS => '0');
    SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';

BEGIN

    -- Assigning the output signals
	m_axis_tvalid <= m_axis_tvalid_int;
	s_axis_tready <= s_axis_tready_int;

    -- Optimized single process for LFO step and triangular waveform generation
    PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                step_clk_cycles <= LFO_COUNTER_BASE_CLK_CYCLES;
                step_counter <= 0;
                tri_counter <= (OTHERS => '0');
                direction_up <= '1';

            ELSE
                -- Set the step_clk_cycles based on the joystick input
                step_clk_cycles_delta <= (to_integer(unsigned(lfo_period)) - JSTK_CENTER_VALUE) * ADJUSTMENT_FACTOR;
                step_clk_cycles <= LFO_COUNTER_BASE_CLK_CYCLES - step_clk_cycles_delta;

                IF lfo_enable = '1' THEN

                    IF step_counter >= step_clk_cycles THEN
                        step_counter <= 0;

                        IF tri_counter = (2 ** TRIANGULAR_COUNTER_LENGHT) - 2 THEN
                            direction_up <= '0';

                        ELSIF tri_counter = 1 THEN
                            direction_up <= '1';

                        END IF;

                        IF direction_up = '1' THEN
                            tri_counter <= tri_counter + 1;

                        ELSE
                            tri_counter <= tri_counter - 1;

                        END IF;

                    ELSE
                        step_counter <= step_counter + 1;

                    END IF;

                END IF;

            END IF;

        END IF;

    END PROCESS;

    -- Handshake logic for the AXIS interface
    AXIS: PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
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
					m_axis_tdata <= STD_LOGIC_VECTOR(
                        resize(
                            shift_right(
                                m_axis_tdata_temp,
                                TRIANGULAR_COUNTER_LENGHT
                            ),
                            CHANNEL_LENGHT
                        )
                    );
					m_axis_tlast <= s_axis_tlast_reg;

					m_axis_tvalid_int <= '1';
					trigger <= '0';
					
				END IF;

                -- Data input logic
				IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN	
                    IF lfo_enable = '1' THEN
                        m_axis_tdata_temp <= signed(s_axis_tdata) * tri_counter;
                        s_axis_tlast_reg <= s_axis_tlast;

                    ELSE
                        m_axis_tdata_temp <= shift_left(
                            resize(
                                signed(s_axis_tdata),
                                m_axis_tdata_temp'length
                            ),
                            TRIANGULAR_COUNTER_LENGHT
                        );
                        s_axis_tlast_reg <= s_axis_tlast;

                    END IF;

                    trigger <= '1';

                END IF;

                s_axis_tready_int <= m_axis_tready OR NOT m_axis_tvalid_int;

            END IF;

        END IF;

    END PROCESS AXIS;

END ARCHITECTURE Behavioral;