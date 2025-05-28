LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

-- Entity: all_pass_filter
-- Purpose: A pass-through filter that maintains the same interface and timing
--          characteristics as a moving average filter but passes data unchanged.
ENTITY all_pass_filter IS
    GENERIC (
        TDATA_WIDTH : POSITIVE := 24  -- Width of the data bus in bits
    );
    PORT (
        -- Clock and reset signals
        aclk : IN STD_LOGIC;        -- Main clock input
        aresetn : IN STD_LOGIC;     -- Active-low asynchronous reset

        -- AXI4-Stream Slave Interface (Input)
        s_axis_tvalid : IN STD_LOGIC;                                      -- Input data valid signal
        s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);    -- Input data
        s_axis_tlast : IN STD_LOGIC;                                       -- Input end-of-packet signal
        s_axis_tready : OUT STD_LOGIC;                                     -- Ready to accept input data

        -- AXI4-Stream Master Interface (Output)
        m_axis_tvalid : OUT STD_LOGIC;                                     -- Output data valid signal
        m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);   -- Output data
        m_axis_tlast : OUT STD_LOGIC;                                      -- Output end-of-packet signal
        m_axis_tready : IN STD_LOGIC                                       -- Downstream ready signal
    );
END all_pass_filter;

ARCHITECTURE Behavioral OF all_pass_filter IS

    -- Internal control signal to trigger data output after input processing
    SIGNAL trigger : STD_LOGIC := '0';

    -- Internal slave interface signals
    SIGNAL s_axis_tready_int : STD_LOGIC := '0';   -- Internal ready signal for input
    SIGNAL s_axis_tlast_reg : STD_LOGIC := '0';    -- Registered version of input tlast
    
    -- Internal data storage and master interface signals
    SIGNAL m_axis_tdata_temp : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0) := (OTHERS => '0'); -- Temporary storage for input data
    SIGNAL m_axis_tvalid_int : STD_LOGIC := '0';   -- Internal valid signal for output

BEGIN

    -- Architecture Overview:
    -- This design mimics the structure, handshake logic, and timing (clock cycles spent)
    -- of the moving_average_filter, but does not process or modify the samples.
    -- It simply passes input data to the output unchanged, ensuring the same latency and interface behavior.

    -- Data Flow:
    -- 1. Input data is captured when s_axis_tvalid and s_axis_tready are both high
    -- 2. Data is stored in temporary registers and a trigger is set
    -- 3. On the next clock cycle, if output interface is ready, data is output
    -- 4. This creates a 1-clock cycle latency matching the moving average filter

    -- Connect internal signals to output ports
    m_axis_tvalid <= m_axis_tvalid_int;  -- Drive output valid with internal signal
    s_axis_tready <= s_axis_tready_int;  -- Drive input ready with internal signal

    -- Main processing logic - synchronous to clock
    PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN

            -- Asynchronous reset logic (active low)
            IF aresetn = '0' THEN
                -- Reset all internal signals to known states
                trigger <= '0';                        -- Clear data processing trigger
                s_axis_tlast_reg <= '0';              -- Clear registered tlast
                s_axis_tready_int <= '0';             -- Not ready to accept data during reset
                m_axis_tdata_temp <= (OTHERS => '0'); -- Clear temporary data storage
                m_axis_tvalid_int <= '0';             -- No valid data on output during reset
                m_axis_tlast <= '0';                  -- Clear output tlast

            ELSE
                -- Normal operation logic

                -- Output handshake management:
                -- Clear the output valid flag when downstream is ready to accept data
                -- This allows new data to be output on the next cycle
                IF m_axis_tready = '1' THEN
                    m_axis_tvalid_int <= '0';
                END IF;

                -- Data output logic:
                -- Output data when trigger is set AND output interface is available
                -- (either no valid data pending OR downstream is ready)
                IF trigger = '1' AND (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
                    -- Transfer stored data to output
                    m_axis_tdata <= m_axis_tdata_temp;  -- Output the stored input data unchanged
                    m_axis_tlast <= s_axis_tlast_reg;   -- Output the registered tlast signal
                    
                    -- Set output control signals
                    m_axis_tvalid_int <= '1';           -- Mark output data as valid
                    trigger <= '0';                     -- Clear trigger - data has been output
                END IF;

                -- Data input logic:
                -- Capture input data when both valid and ready are asserted (AXI handshake)
                IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN				
                    -- Store input signals for later output
                    s_axis_tlast_reg <= s_axis_tlast;   -- Register the tlast signal
                    m_axis_tdata_temp <= s_axis_tdata;  -- Store input data (pass-through, no processing)
                    
                    -- Set trigger to indicate data is ready for output
                    trigger <= '1';
                END IF;

                -- Input ready logic:
                -- Ready to accept new input when:
                -- - Downstream is ready (can immediately pass data through), OR
                -- - No valid data is pending on output (have buffer space)
                -- This implements backpressure - if output is blocked, input will be blocked
                s_axis_tready_int <= m_axis_tready OR NOT m_axis_tvalid_int;

            END IF;

        END IF;

    END PROCESS;

END Behavioral;