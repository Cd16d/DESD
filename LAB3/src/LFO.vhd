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
    CONSTANT JSTK_CENTER_VALUE : INTEGER := 2 ** (JOYSTICK_LENGHT - 1);
    CONSTANT LFO_COUNTER_BASE_CLK_CYCLES : INTEGER := LFO_COUNTER_BASE_PERIOD_US * 1000 / CLK_PERIOD_NS;

    SIGNAL step_clk_cycles : INTEGER := LFO_COUNTER_BASE_CLK_CYCLES;
    SIGNAL step_counter : INTEGER RANGE 0 TO 2 ** TRIANGULAR_COUNTER_LENGHT - 1 := 0;
    SIGNAL tri_counter : signed(TRIANGULAR_COUNTER_LENGHT - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL direction_up : STD_LOGIC := '1';

    SIGNAL s_axis_tready_int : STD_LOGIC := '0';
    SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';

BEGIN

    -- Output assignments
    s_axis_tready <= s_axis_tready_int;
    m_axis_tvalid <= m_axis_tvalid_int;

    -- Optimized single process for LFO step and triangular waveform generation
    PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                step_counter <= 0;
                tri_counter <= (OTHERS => '0');
                direction_up <= '1';

            ELSE
                -- Clamp step_clk_cycles to a minimum of 1 to avoid negative or zero values
                IF (LFO_COUNTER_BASE_CLK_CYCLES - ADJUSTMENT_FACTOR * to_integer(JSTK_CENTER_VALUE - unsigned(lfo_period))) < 1 THEN
                    step_clk_cycles <= 1;
                ELSE
                    step_clk_cycles <= LFO_COUNTER_BASE_CLK_CYCLES - ADJUSTMENT_FACTOR * to_integer(JSTK_CENTER_VALUE - unsigned(lfo_period));
                END IF;

                IF lfo_enable = '1' THEN

                    IF step_counter >= step_clk_cycles THEN
                        step_counter <= 0;

                        IF tri_counter = 2 ** TRIANGULAR_COUNTER_LENGHT - 2 THEN
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
    PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                s_axis_tready_int <= '0';
                m_axis_tvalid_int <= '0';
                m_axis_tdata <= (OTHERS => '0');
                m_axis_tlast <= '0';

            ELSE
                -- Clear valid flag when master interface is ready
                IF m_axis_tready = '1' THEN
                    m_axis_tvalid_int <= '0';
                END IF;

                IF s_axis_tvalid = '1' AND (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
                    IF lfo_enable = '1' THEN
                        m_axis_tdata <= STD_LOGIC_VECTOR(
                            resize(
                                signed(s_axis_tdata) * tri_counter,
                                m_axis_tdata'LENGTH
                            )
                        );

                    ELSE
                        m_axis_tdata <= s_axis_tdata;

                    END IF;
                    s_axis_tready_int <= '1';
                    m_axis_tvalid_int <= '1';
                    m_axis_tlast <= s_axis_tlast;

                ELSE
                    s_axis_tready_int <= '0';

                END IF;

            END IF;

        END IF;

    END PROCESS;

END ARCHITECTURE Behavioral;