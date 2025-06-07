LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

-- Entity: moving_average_filter_en
-- Purpose: Switchable audio filter that can be enabled or disabled at runtime
--          When enabled: applies moving average low-pass filtering
--          When disabled: passes audio through unchanged (all-pass filter)
--          This allows real-time comparison between filtered and unfiltered audio
ENTITY moving_average_filter_en IS
    GENERIC (
        -- Filter order expressed as 2^(FILTER_ORDER_POWER)
        -- Example: FILTER_ORDER_POWER = 5 means filter order = 32 samples
        FILTER_ORDER_POWER : INTEGER := 5;

        TDATA_WIDTH : POSITIVE := 24  -- Width of audio data bus (24-bit audio samples)
    );
    PORT (
        -- Clock and reset signals
        aclk : IN STD_LOGIC;        -- Main clock input
        aresetn : IN STD_LOGIC;     -- Active-low asynchronous reset

        -- AXI4-Stream Slave Interface (Audio Input)
        s_axis_tvalid : IN STD_LOGIC;                                      -- Input data valid signal
        s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);      -- Audio sample input
        s_axis_tlast : IN STD_LOGIC;                                       -- Channel indicator (0=left, 1=right)
        s_axis_tready : OUT STD_LOGIC;                                     -- Ready to accept input data

        -- AXI4-Stream Master Interface (Audio Output)
        m_axis_tvalid : OUT STD_LOGIC;                                     -- Output data valid signal
        m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);     -- Audio sample output (filtered or unfiltered)
        m_axis_tlast : OUT STD_LOGIC;                                      -- Channel indicator passthrough
        m_axis_tready : IN STD_LOGIC;                                      -- Downstream ready signal

        -- Filter control input
        enable_filter : IN STD_LOGIC  -- Filter enable control (1=moving average filter, 0=all-pass filter)
    );
END moving_average_filter_en;

ARCHITECTURE Behavioral OF moving_average_filter_en IS

    -- Component declaration for all-pass filter
    -- This filter passes audio unchanged but maintains the same latency as the moving average filter
    COMPONENT all_pass_filter IS
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
    END COMPONENT;

    -- Component declaration for moving average filter
    -- This filter applies low-pass filtering by averaging multiple audio samples
    COMPONENT moving_average_filter IS
        GENERIC (
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
    END COMPONENT;

    -- Internal signals for the all-pass filter path
    -- These signals carry data when filtering is disabled
    SIGNAL all_pass_m_tvalid : STD_LOGIC;                                  -- All-pass filter output valid
    SIGNAL all_pass_m_tdata : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0); -- All-pass filter output data
    SIGNAL all_pass_m_tlast : STD_LOGIC;                                   -- All-pass filter output tlast
    SIGNAL all_pass_s_tready : STD_LOGIC;                                  -- All-pass filter input ready

    -- Internal signals for the moving average filter path
    -- These signals carry data when filtering is enabled
    SIGNAL moving_avg_m_tvalid : STD_LOGIC;                                  -- Moving average filter output valid
    SIGNAL moving_avg_m_tdata : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0); -- Moving average filter output data
    SIGNAL moving_avg_m_tlast : STD_LOGIC;                                   -- Moving average filter output tlast
    SIGNAL moving_avg_s_tready : STD_LOGIC;                                  -- Moving average filter input ready

BEGIN

    -- Instantiate the all-pass filter (bypass path)
    -- This provides unfiltered audio with matched latency for seamless switching
    all_pass_inst : all_pass_filter
    GENERIC MAP(
        TDATA_WIDTH => TDATA_WIDTH
    )
    PORT MAP(
        aclk => aclk,
        aresetn => aresetn,

        -- Connect input directly to all-pass filter
        s_axis_tvalid => s_axis_tvalid,
        s_axis_tdata => s_axis_tdata,
        s_axis_tlast => s_axis_tlast,
        s_axis_tready => all_pass_s_tready,

        -- All-pass filter outputs (used when enable_filter = '0')
        m_axis_tvalid => all_pass_m_tvalid,
        m_axis_tdata => all_pass_m_tdata,
        m_axis_tlast => all_pass_m_tlast,
        m_axis_tready => m_axis_tready
    );

    -- Instantiate the moving average filter (filtering path)
    -- This provides low-pass filtered audio for noise reduction
    moving_avg_inst : moving_average_filter
    GENERIC MAP(
        FILTER_ORDER_POWER => FILTER_ORDER_POWER,
        TDATA_WIDTH => TDATA_WIDTH
    )
    PORT MAP(
        aclk => aclk,
        aresetn => aresetn,

        -- Connect input directly to moving average filter
        s_axis_tvalid => s_axis_tvalid,
        s_axis_tdata => s_axis_tdata,
        s_axis_tlast => s_axis_tlast,
        s_axis_tready => moving_avg_s_tready,

        -- Moving average filter outputs (used when enable_filter = '1')
        m_axis_tvalid => moving_avg_m_tvalid,
        m_axis_tdata => moving_avg_m_tdata,
        m_axis_tlast => moving_avg_m_tlast,
        m_axis_tready => m_axis_tready
    );

    -- Output multiplexer: Select between filtered and unfiltered audio paths
    -- This switching is controlled by the enable_filter signal
    
    -- Input ready selection: Route backpressure to the active filter
    s_axis_tready <= all_pass_s_tready   WHEN enable_filter = '0' ELSE moving_avg_s_tready;
    
    -- Output data selection: Route output from the active filter
    m_axis_tvalid <= all_pass_m_tvalid   WHEN enable_filter = '0' ELSE moving_avg_m_tvalid;
    m_axis_tdata  <= all_pass_m_tdata    WHEN enable_filter = '0' ELSE moving_avg_m_tdata;
    m_axis_tlast  <= all_pass_m_tlast    WHEN enable_filter = '0' ELSE moving_avg_m_tlast;

    -- Filter Path Selection Logic:
    -- enable_filter = '0': All-pass path (unfiltered audio with matched latency)
    -- enable_filter = '1': Moving average path (low-pass filtered audio)
    -- 
    -- Both filters run continuously but only the selected path is routed to output
    -- This allows for glitch-free switching between filtered and unfiltered audio

END Behavioral;