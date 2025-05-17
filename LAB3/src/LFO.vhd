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

    CONSTANT LFO_COUNTER_BASE_PERIOD_NS : INTEGER := 100000;
    CONSTANT ADJUSTMENT_FACTOR : INTEGER := 90;

    SIGNAL step_counter : INTEGER := 1;
    SIGNAL tri_counter : signed(CHANNEL_LENGHT - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL direction_up : STD_LOGIC := '1';
    SIGNAL lfo_tick : STD_LOGIC := '0';

    SIGNAL lfo_period_int : INTEGER := LFO_COUNTER_BASE_PERIOD_NS;
    SIGNAL m_axis_tvalid_i : STD_LOGIC := '0';
    SIGNAL m_axis_tdata_i : STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL m_axis_tlast_i : STD_LOGIC := '0';
    SIGNAL s_axis_tready_i : STD_LOGIC := '1';
    SIGNAL temp : STD_LOGIC_VECTOR(CHANNEL_LENGHT + TRIANGULAR_COUNTER_LENGHT - 1 DOWNTO 0) := (OTHERS => '0');

BEGIN

    PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN
            lfo_period_int <= LFO_COUNTER_BASE_PERIOD_NS - ADJUSTMENT_FACTOR * to_integer(unsigned(lfo_period));
        END IF;
    END PROCESS;

    -- Optimized single process for LFO step and triangular waveform generation
    PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                step_counter <= 0;
                tri_counter <= (OTHERS => '0');
                direction_up <= '1';
                lfo_tick <= '0';
            ELSIF lfo_enable = '1' THEN
                IF step_counter < lfo_period_int THEN
                    step_counter <= step_counter + 1;
                    lfo_tick <= '0';
                ELSE
                    step_counter <= 0;
                    lfo_tick <= '1';

                    IF direction_up = '1' THEN
                        IF tri_counter = 2 ** TRIANGULAR_COUNTER_LENGHT - 1 THEN
                            direction_up <= '0';
                            tri_counter <= tri_counter - 1;
                        ELSE
                            tri_counter <= tri_counter + 1;
                        END IF;
                    ELSE
                        IF tri_counter = 0 THEN
                            direction_up <= '1';
                            tri_counter <= tri_counter + 1;
                        ELSE
                            tri_counter <= tri_counter - 1;
                        END IF;
                    END IF;
                END IF;
            ELSE
                lfo_tick <= '0';
                direction_up <= '1';
                tri_counter <= (OTHERS => '0');
                step_counter <= 0;
            END IF;
        END IF;
    END PROCESS;
    PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                temp <= (OTHERS => '0');
            ELSIF s_axis_tvalid = '1' AND m_axis_tready = '1' AND lfo_enable = '1' THEN
                temp <= STD_LOGIC_VECTOR(
                    resize(
                    signed(s_axis_tdata) * signed(resize(tri_counter, s_axis_tdata'length)),
                    temp'length
                    )
                    );
            END IF;
        END IF;
    END PROCESS;

    PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                m_axis_tvalid_i <= '0';
                m_axis_tdata_i <= (OTHERS => '0');
                m_axis_tlast_i <= '0';
            ELSE
                IF s_axis_tvalid = '1' AND m_axis_tready = '1' THEN
                    IF lfo_enable = '1' THEN
                        m_axis_tdata_i <= temp(temp'high DOWNTO temp'high - (CHANNEL_LENGHT - 1));
                    ELSE
                        m_axis_tdata_i <= s_axis_tdata;
                    END IF;
                    s_axis_tready_i <= '0';
                    m_axis_tvalid_i <= '1';
                    m_axis_tlast_i <= s_axis_tlast;
                END IF;
                IF m_axis_tvalid_i = '1' THEN
                    IF m_axis_tready = '0' THEN
                        s_axis_tready_i <= '0';
                    ELSE
                        s_axis_tready_i <= '1';
                    END IF;
                    m_axis_tvalid_i <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    s_axis_tready <= s_axis_tready_i;
    m_axis_tdata <= m_axis_tdata_i;
    m_axis_tvalid <= m_axis_tvalid_i;
    m_axis_tlast <= m_axis_tlast_i;

END ARCHITECTURE Behavioral;