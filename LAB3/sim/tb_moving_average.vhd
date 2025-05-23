-- filepath: c:\DESD\LAB3\sim\tb_moving_average.vhd
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_moving_average IS
END tb_moving_average;

ARCHITECTURE sim OF tb_moving_average IS

    CONSTANT TDATA_WIDTH      : INTEGER := 24;
    CONSTANT FILTER_ORDER_PWR : INTEGER := 5;

    SIGNAL aclk           : STD_LOGIC := '0';
    SIGNAL aresetn        : STD_LOGIC := '0';

    SIGNAL s_axis_tvalid  : STD_LOGIC := '0';
    SIGNAL s_axis_tdata   : STD_LOGIC_VECTOR(TDATA_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axis_tlast   : STD_LOGIC := '0';
    SIGNAL s_axis_tready  : STD_LOGIC;

    SIGNAL m_axis_tvalid  : STD_LOGIC;
    SIGNAL m_axis_tdata   : STD_LOGIC_VECTOR(TDATA_WIDTH-1 DOWNTO 0);
    SIGNAL m_axis_tlast   : STD_LOGIC;
    SIGNAL m_axis_tready  : STD_LOGIC := '1';

    SIGNAL enable_filter  : STD_LOGIC := '0';

    -- DUT
    COMPONENT moving_average_filter_en
        GENERIC (
            FILTER_ORDER_POWER : INTEGER := 5;
            TDATA_WIDTH        : POSITIVE := 24
        );
        PORT (
            aclk           : IN  STD_LOGIC;
            aresetn        : IN  STD_LOGIC;
            s_axis_tvalid  : IN  STD_LOGIC;
            s_axis_tdata   : IN  STD_LOGIC_VECTOR(TDATA_WIDTH-1 DOWNTO 0);
            s_axis_tlast   : IN  STD_LOGIC;
            s_axis_tready  : OUT STD_LOGIC;
            m_axis_tvalid  : OUT STD_LOGIC;
            m_axis_tdata   : OUT STD_LOGIC_VECTOR(TDATA_WIDTH-1 DOWNTO 0);
            m_axis_tlast   : OUT STD_LOGIC;
            m_axis_tready  : IN  STD_LOGIC;
            enable_filter  : IN  STD_LOGIC
        );
    END COMPONENT;

BEGIN

    -- Clock generation
    clk_proc : PROCESS
    BEGIN
        aclk <= '0';
        WAIT FOR 5 ns;
        aclk <= '1';
        WAIT FOR 5 ns;
    END PROCESS;

    -- DUT instantiation
    dut: moving_average_filter_en
        GENERIC MAP (
            FILTER_ORDER_POWER => FILTER_ORDER_PWR,
            TDATA_WIDTH        => TDATA_WIDTH
        )
        PORT MAP (
            aclk           => aclk,
            aresetn        => aresetn,
            s_axis_tvalid  => s_axis_tvalid,
            s_axis_tdata   => s_axis_tdata,
            s_axis_tlast   => s_axis_tlast,
            s_axis_tready  => s_axis_tready,
            m_axis_tvalid  => m_axis_tvalid,
            m_axis_tdata   => m_axis_tdata,
            m_axis_tlast   => m_axis_tlast,
            m_axis_tready  => m_axis_tready,
            enable_filter  => enable_filter
        );

    -- Stimulus process
    stim_proc : PROCESS
    BEGIN
        -- Reset
        aresetn <= '0';
        WAIT FOR 20 ns;
        aresetn <= '1';
        WAIT FOR 10 ns;

        -- Test All Pass (enable_filter = '0')
        enable_filter <= '0';
        FOR i IN 0 TO 7 LOOP
            -- SX sample
            s_axis_tdata  <= std_logic_vector(to_signed(i*100, TDATA_WIDTH));
            s_axis_tvalid <= '1';
            s_axis_tlast  <= '0';
            WAIT UNTIL rising_edge(aclk);
            WHILE s_axis_tready /= '1' LOOP
                WAIT UNTIL rising_edge(aclk);
            END LOOP;
            s_axis_tvalid <= '0';

            -- DX sample (tlast high)
            s_axis_tdata  <= std_logic_vector(to_signed(i*100+50, TDATA_WIDTH));
            s_axis_tvalid <= '1';
            s_axis_tlast  <= '1';
            WAIT UNTIL rising_edge(aclk);
            WHILE s_axis_tready /= '1' LOOP
                WAIT UNTIL rising_edge(aclk);
            END LOOP;
            s_axis_tvalid <= '0';
        END LOOP;

        -- Test Moving Average (enable_filter = '1')
        enable_filter <= '1';
        FOR i IN 0 TO 7 LOOP
            -- SX sample
            s_axis_tdata  <= std_logic_vector(to_signed(i*100, TDATA_WIDTH));
            s_axis_tvalid <= '1';
            s_axis_tlast  <= '0';
            WAIT UNTIL rising_edge(aclk);
            WHILE s_axis_tready /= '1' LOOP
                WAIT UNTIL rising_edge(aclk);
            END LOOP;
            s_axis_tvalid <= '0';

            -- DX sample (tlast high)
            s_axis_tdata  <= std_logic_vector(to_signed(i*100+50, TDATA_WIDTH));
            s_axis_tvalid <= '1';
            s_axis_tlast  <= '1';
            WAIT UNTIL rising_edge(aclk);
            WHILE s_axis_tready /= '1' LOOP
                WAIT UNTIL rising_edge(aclk);
            END LOOP;
            s_axis_tvalid <= '0';
        END LOOP;

        -- End simulation
        WAIT FOR 50 ns;
    END PROCESS;

END sim;