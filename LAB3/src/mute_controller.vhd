LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Entity: mute_controller
-- Purpose: Controls audio muting by replacing audio samples with zeros when mute is active
--          Implements AXI4-Stream interface for seamless integration in audio processing chain
ENTITY mute_controller IS
    GENERIC (
        TDATA_WIDTH : POSITIVE := 24  -- Width of audio data bus (24-bit audio samples)
    );
    PORT (
        -- Clock and reset signals
        aclk : IN STD_LOGIC;      -- Main clock input
        aresetn : IN STD_LOGIC;   -- Active-low asynchronous reset

        -- AXI4-Stream Slave Interface (Audio Input)
        s_axis_tvalid : IN STD_LOGIC;                                      -- Input data valid signal
        s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);    -- Audio sample input
        s_axis_tlast : IN STD_LOGIC;                                       -- Channel indicator (0=left, 1=right)
        s_axis_tready : OUT STD_LOGIC;                                     -- Ready to accept input data

        -- AXI4-Stream Master Interface (Audio Output)
        m_axis_tvalid : OUT STD_LOGIC;                                     -- Output data valid signal
        m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);   -- Audio sample output (muted or passed through)
        m_axis_tlast : OUT STD_LOGIC;                                      -- Channel indicator passthrough
        m_axis_tready : IN STD_LOGIC;                                      -- Downstream ready signal

        -- Control input
        mute : IN STD_LOGIC  -- Mute control (1=mute audio, 0=pass audio through)
    );
END mute_controller;

ARCHITECTURE Behavioral OF mute_controller IS

    -- Internal signal for output valid control
    SIGNAL m_axis_tvalid_int : STD_LOGIC;

BEGIN

    -- Connect internal signals to output ports
    m_axis_tvalid <= m_axis_tvalid_int;
    
    -- Input ready logic: Ready when downstream is ready OR no valid data pending, AND not in reset
    -- This implements proper AXI4-Stream backpressure handling
    s_axis_tready <= (m_axis_tready OR NOT m_axis_tvalid_int) AND aresetn;

    -- Main mute control process
    -- Handles AXI4-Stream protocol and mute functionality
    PROCESS (aclk)
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset state: Clear all output control signals
                m_axis_tvalid_int <= '0';  -- No valid output data during reset
                m_axis_tlast <= '0';       -- Clear channel indicator

            ELSE
                -- Normal operation

                -- Output handshake management:
                -- Clear valid flag when downstream accepts data
                -- This allows new data to be output on the next cycle
                IF m_axis_tready = '1' THEN
                    m_axis_tvalid_int <= '0';
                END IF;

                -- Data processing: Handle mute control when both input and output are ready
                -- This ensures proper AXI4-Stream handshaking
                IF s_axis_tvalid = '1' AND m_axis_tready = '1' THEN
                    -- Mute control logic:
                    IF mute = '1' THEN
                        -- Mute active: Replace audio data with silence (all zeros)
                        -- This effectively removes all audio content while maintaining data flow
                        m_axis_tdata <= (OTHERS => '0');
                    ELSE
                        -- Mute inactive: Pass audio data through unchanged
                        -- Normal audio processing mode
                        m_axis_tdata <= s_axis_tdata;
                    END IF;

                    -- Set output control signals
                    m_axis_tvalid_int <= '1';        -- Mark output data as valid
                    m_axis_tlast <= s_axis_tlast;    -- Pass through channel indicator unchanged

                END IF;

            END IF;

        END IF;
        
    END PROCESS;

END Behavioral;