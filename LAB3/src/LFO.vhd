LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY LFO IS
    GENERIC (
        CHANNEL_LENGHT : INTEGER := 24;
        JOYSTICK_LENGHT : INTEGER := 10;
        CLK_PERIOD_NS : INTEGER := 10;
        TRIANGULAR_COUNTER_LENGHT : INTEGER := 10
    );
    PORT (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        lfo_period : IN STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);
        lfo_enable : IN STD_LOGIC;
        -- Slave AXI Stream interface
        s_axis_tvalid : IN STD_LOGIC;
        s_axis_tdata : IN STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0);
        s_axis_tlast : IN STD_LOGIC;
        s_axis_tready : OUT STD_LOGIC;
        -- Master AXI Stream interface
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

    -- Signals for LFO operation
    SIGNAL step_clk_cycles_delta : INTEGER RANGE - 2 ** (JOYSTICK_LENGHT - 1) * ADJUSTMENT_FACTOR TO (2 ** (JOYSTICK_LENGHT - 1) - 1) * ADJUSTMENT_FACTOR := 0;
    SIGNAL step_clk_cycles : INTEGER RANGE LFO_CLK_CYCLES_MIN TO LFO_CLK_CYCLES_MAX := LFO_COUNTER_BASE_CLK_CYCLES;

    -- Pipeline stage registers
    SIGNAL s_axis_tdata_r1 : STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL lfo_enable_r1 : STD_LOGIC := '0';
    SIGNAL s_axis_tvalid_r1 : STD_LOGIC := '0';
    SIGNAL s_axis_tlast_r1 : STD_LOGIC := '0';

    SIGNAL tri_counter_r2 : unsigned(TRIANGULAR_COUNTER_LENGHT - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL direction_up_r2 : STD_LOGIC := '1';
    SIGNAL step_counter_r2 : NATURAL RANGE 0 TO LFO_CLK_CYCLES_MAX := 0;
    SIGNAL lfo_enable_r2 : STD_LOGIC := '0';
    SIGNAL s_axis_tvalid_r2 : STD_LOGIC := '0';
    SIGNAL s_axis_tlast_r2 : STD_LOGIC := '0';
    SIGNAL s_axis_tdata_r2 : STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0) := (OTHERS => '0');

    SIGNAL temp_r3 : STD_LOGIC_VECTOR(CHANNEL_LENGHT + TRIANGULAR_COUNTER_LENGHT - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL m_axis_tvalid_i : STD_LOGIC := '0';
    SIGNAL s_axis_tready_i : STD_LOGIC := '1';

BEGIN

    m_axis_tlast <= s_axis_tlast_r1;

    -- Stage 1: Input registration and LFO period calculation
    PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                s_axis_tdata_r1 <= (OTHERS => '0');
                step_clk_cycles <= LFO_COUNTER_BASE_CLK_CYCLES;
                lfo_enable_r1 <= '0';
                s_axis_tvalid_r1 <= '0';
                s_axis_tlast_r1 <= '0';
            ELSE
                -- Set the step_clk_cycles based on the joystick input
                step_clk_cycles_delta <= (to_integer(unsigned(lfo_period)) - JSTK_CENTER_VALUE) * ADJUSTMENT_FACTOR;
                step_clk_cycles <= LFO_COUNTER_BASE_CLK_CYCLES - step_clk_cycles_delta;

                IF s_axis_tvalid = '1' AND s_axis_tready_i = '1' THEN
                    s_axis_tdata_r1 <= s_axis_tdata;
                    lfo_enable_r1 <= lfo_enable;
                    s_axis_tvalid_r1 <= '1';
                    s_axis_tlast_r1 <= s_axis_tlast;
                ELSE
                    s_axis_tvalid_r1 <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- Stage 2: Triangular counter control
    PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                step_counter_r2 <= 0;
                tri_counter_r2 <= (OTHERS => '0');
                direction_up_r2 <= '1';
                lfo_enable_r2 <= '0';
                s_axis_tvalid_r2 <= '0';
                s_axis_tlast_r2 <= '0';
                s_axis_tdata_r2 <= (OTHERS => '0');
            ELSE
                lfo_enable_r2 <= lfo_enable_r1;
                s_axis_tvalid_r2 <= s_axis_tvalid_r1;
                s_axis_tlast_r2 <= s_axis_tlast_r1;
                s_axis_tdata_r2 <= s_axis_tdata_r1;

                IF lfo_enable_r1 = '1' THEN
                    IF step_counter_r2 < step_clk_cycles THEN
                        step_counter_r2 <= step_counter_r2 + 1;
                    ELSE
                        step_counter_r2 <= 0;
                        IF direction_up_r2 = '1' THEN
                            IF tri_counter_r2 = (2 ** TRIANGULAR_COUNTER_LENGHT) - 1 THEN
                                direction_up_r2 <= '0';
                                tri_counter_r2 <= tri_counter_r2 - 1;
                            ELSE
                                tri_counter_r2 <= tri_counter_r2 + 1;
                            END IF;
                        ELSE
                            IF tri_counter_r2 = 0 THEN
                                direction_up_r2 <= '1';
                                tri_counter_r2 <= tri_counter_r2 + 1;
                            ELSE
                                tri_counter_r2 <= tri_counter_r2 - 1;
                            END IF;
                        END IF;
                    END IF;
                ELSE
                    step_counter_r2 <= 0;
                    tri_counter_r2 <= (OTHERS => '0');
                    direction_up_r2 <= '1';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- Stage 3: Optimized modulation and output handling
    PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                m_axis_tdata <= (OTHERS => '0');
                m_axis_tvalid_i <= '0';
                s_axis_tready_i <= '1';
            ELSE
                IF m_axis_tvalid_i = '1' AND m_axis_tready = '0' THEN
                    m_axis_tvalid_i <= '1';
                ELSIF s_axis_tvalid_r2 = '1' THEN
                    IF lfo_enable_r2 = '1' THEN
                        temp_r3 <= STD_LOGIC_VECTOR(
                            resize(
                            signed(s_axis_tdata_r2) * signed('0' & tri_counter_r2),
                            temp_r3'length
                            )
                            );
                        m_axis_tdata <= temp_r3(temp_r3'high DOWNTO TRIANGULAR_COUNTER_LENGHT);
                    ELSE
                        m_axis_tdata <= s_axis_tdata_r2;
                    END IF;
                    m_axis_tvalid_i <= '1';
                ELSE
                    m_axis_tvalid_i <= '0';
                END IF;

                -- Ready signal management
                IF m_axis_tvalid_i = '1' AND m_axis_tready = '1' THEN
                    s_axis_tready_i <= '1';
                ELSIF s_axis_tvalid = '1' AND s_axis_tready_i = '1' THEN
                    s_axis_tready_i <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    s_axis_tready <= s_axis_tready_i;
    m_axis_tvalid <= m_axis_tvalid_i;

END ARCHITECTURE Behavioral;