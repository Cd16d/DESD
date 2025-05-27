LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

-- Entity: moving_average_filter
-- Purpose: Implements a finite impulse response (FIR) low-pass filter using moving average
--          Maintains separate circular buffers for left and right audio channels
--          Filter order is configurable as 2^(FILTER_ORDER_POWER) samples
ENTITY moving_average_filter IS
    GENERIC (
        -- Filter order expressed as 2^(FILTER_ORDER_POWER)
        -- Example: FILTER_ORDER_POWER = 5 means 32-sample moving average
        FILTER_ORDER_POWER : INTEGER := 5;

        TDATA_WIDTH : POSITIVE := 24  -- Width of audio data bus (24-bit audio samples)
    );
    PORT (
        -- Clock and reset signals
        aclk : IN STD_LOGIC;        -- Main clock input
        aresetn : IN STD_LOGIC;     -- Active-low asynchronous reset

        -- AXI4-Stream Slave Interface (Audio Input)
        s_axis_tvalid : IN STD_LOGIC;                                      -- Input data valid signal
        s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);    -- Audio sample input
        s_axis_tlast : IN STD_LOGIC;                                       -- Channel indicator (0=left, 1=right)
        s_axis_tready : OUT STD_LOGIC;                                     -- Ready to accept input data

        -- AXI4-Stream Master Interface (Audio Output)
        m_axis_tvalid : OUT STD_LOGIC;                                     -- Output data valid signal
        m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);   -- Filtered audio sample output
        m_axis_tlast : OUT STD_LOGIC;                                      -- Channel indicator passthrough
        m_axis_tready : IN STD_LOGIC                                       -- Downstream ready signal
    );
END moving_average_filter;

ARCHITECTURE Behavioral OF moving_average_filter IS

    -- Calculate actual filter order from power-of-2 representation
    CONSTANT FILTER_ORDER : INTEGER := 2 ** FILTER_ORDER_POWER;

    -- Array type for storing audio samples in circular buffers
    TYPE sample_array IS ARRAY (0 TO FILTER_ORDER - 1) OF signed(TDATA_WIDTH - 1 DOWNTO 0);

    -- Right channel (RX) processing signals
    SIGNAL samples_rx : sample_array := (OTHERS => (OTHERS => '0'));                        -- Circular buffer for right channel samples
    SIGNAL sum_rx : signed(TDATA_WIDTH + FILTER_ORDER_POWER - 1 DOWNTO 0) := (OTHERS => '0'); -- Running sum of right channel samples
    SIGNAL wr_ptr_rx : INTEGER RANGE 0 TO FILTER_ORDER - 1 := 0;                            -- Write pointer for right channel buffer

    -- Left channel (LX) processing signals
    SIGNAL samples_lx : sample_array := (OTHERS => (OTHERS => '0'));                        -- Circular buffer for left channel samples
    SIGNAL sum_lx : signed(TDATA_WIDTH + FILTER_ORDER_POWER - 1 DOWNTO 0) := (OTHERS => '0'); -- Running sum of left channel samples
    SIGNAL wr_ptr_lx : INTEGER RANGE 0 TO FILTER_ORDER - 1 := 0;                            -- Write pointer for left channel buffer

    -- Control and interface signals
    SIGNAL trigger : STD_LOGIC := '0';           -- Trigger signal to indicate when to output filtered data
    SIGNAL s_axis_tready_int : STD_LOGIC := '0'; -- Internal ready signal for input interface
    SIGNAL s_axis_tlast_reg : STD_LOGIC := '0';  -- Registered version of tlast for output synchronization
    SIGNAL m_axis_tvalid_int : STD_LOGIC := '0'; -- Internal valid signal for output interface

BEGIN

    -- Connect internal signals to output ports
    m_axis_tvalid <= m_axis_tvalid_int;
    s_axis_tready <= s_axis_tready_int;

    -- Main processing logic - synchronous to clock
    PROCESS (aclk)
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset all filter state and control signals
                samples_rx <= (OTHERS => (OTHERS => '0'));  -- Clear right channel sample buffer
                samples_lx <= (OTHERS => (OTHERS => '0'));  -- Clear left channel sample buffer
                sum_rx <= (OTHERS => '0');                  -- Clear right channel running sum
                sum_lx <= (OTHERS => '0');                  -- Clear left channel running sum
                wr_ptr_rx <= 0;                             -- Reset right channel write pointer
                wr_ptr_lx <= 0;                             -- Reset left channel write pointer

                -- Reset AXI4-Stream interface signals
                s_axis_tlast_reg <= '0';                    -- Clear registered tlast
                s_axis_tready_int <= '0';                   -- Not ready during reset
                m_axis_tvalid_int <= '0';                   -- No valid output during reset
                m_axis_tlast <= '0';                        -- Clear output tlast

            ELSE
                -- Normal operation

                -- Output handshake management:
                -- Clear valid flag when downstream accepts data
                IF m_axis_tready = '1' THEN
                    m_axis_tvalid_int <= '0';
                END IF;

                -- Data output logic:
                -- Output filtered data when trigger is set AND output interface is available
                IF trigger = '1' AND (m_axis_tvalid_int = '0' OR m_axis_tready = '1') THEN
                    
                    -- Select which channel's filtered data to output based on registered tlast
                    IF s_axis_tlast_reg = '1' THEN
                        -- Right channel: Output averaged right channel data
                        -- Divide sum by filter order using right shift (efficient division by power of 2)
                        m_axis_tdata <= STD_LOGIC_VECTOR(
                            resize(
                                shift_right(
                                    sum_rx,                    -- Right channel running sum
                                    FILTER_ORDER_POWER         -- Divide by 2^FILTER_ORDER_POWER
                                ),
                                m_axis_tdata'length           -- Resize to output width
                            )
                        );

                    ELSE
                        -- Left channel: Output averaged left channel data
                        -- Divide sum by filter order using right shift (efficient division by power of 2)
                        m_axis_tdata <= STD_LOGIC_VECTOR(
                            resize(
                                shift_right(
                                    sum_lx,                    -- Left channel running sum
                                    FILTER_ORDER_POWER         -- Divide by 2^FILTER_ORDER_POWER
                                ),
                                m_axis_tdata'length           -- Resize to output width
                            )
                        );

                    END IF;
                    
                    -- Set output control signals
                    m_axis_tlast <= s_axis_tlast_reg;  -- Pass through the registered channel indicator
                    m_axis_tvalid_int <= '1';          -- Mark output as valid
                    trigger <= '0';                    -- Clear trigger - data has been output

                END IF;

                -- Data input logic:
                -- Process new input samples when both valid and ready are asserted
                IF s_axis_tvalid = '1' AND s_axis_tready_int = '1' THEN	
                    
                    -- Channel identification and processing based on tlast signal
                    IF s_axis_tlast = '1' THEN
                        -- Right channel processing (tlast = '1')
                        
                        -- Store new sample in circular buffer, overwriting oldest sample
                        samples_rx(wr_ptr_rx) <= signed(s_axis_tdata);

                        -- Update write pointer with wraparound (circular buffer behavior)
                        wr_ptr_rx <= (wr_ptr_rx + 1) MOD FILTER_ORDER;

                        -- Update running sum using sliding window technique:
                        -- Remove the oldest sample (about to be overwritten) and add the new sample
                        -- This maintains the sum of the most recent FILTER_ORDER samples
                        sum_rx <= sum_rx - samples_rx(wr_ptr_rx) + signed(s_axis_tdata);

                        -- Register tlast for output synchronization
                        s_axis_tlast_reg <= s_axis_tlast;

                    ELSE
                        -- Left channel processing (tlast = '0')
                        
                        -- Store new sample in circular buffer, overwriting oldest sample
                        samples_lx(wr_ptr_lx) <= signed(s_axis_tdata);

                        -- Update write pointer with wraparound (circular buffer behavior)
                        wr_ptr_lx <= (wr_ptr_lx + 1) MOD FILTER_ORDER;

                        -- Update running sum using sliding window technique:
                        -- Remove the oldest sample (about to be overwritten) and add the new sample
                        -- This maintains the sum of the most recent FILTER_ORDER samples
                        sum_lx <= sum_lx - samples_lx(wr_ptr_lx) + signed(s_axis_tdata);

                        -- Register tlast for output synchronization
                        s_axis_tlast_reg <= s_axis_tlast;

                    END IF;

                    -- Set trigger to indicate that new filtered data is ready for output
                    trigger <= '1';

                END IF;

                -- Input ready logic:
                -- Ready to accept new input when downstream is ready OR no valid output pending
                -- This implements proper AXI4-Stream backpressure handling
                s_axis_tready_int <= m_axis_tready OR NOT m_axis_tvalid_int;

            END IF;

        END IF;

    END PROCESS;

    -- Filter Operation Summary:
    -- 1. Maintains separate circular buffers for left and right audio channels
    -- 2. Uses running sum technique for efficient moving average calculation
    -- 3. Each new sample: removes oldest from sum, adds newest to sum
    -- 4. Output = sum / FILTER_ORDER (using efficient bit shift division)
    -- 5. Provides low-pass filtering with configurable filter order

END Behavioral;