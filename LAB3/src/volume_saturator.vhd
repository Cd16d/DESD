LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Entity: volume_saturator
-- Purpose: Second stage of volume control pipeline - clips multiplication results to prevent overflow
--          Reduces bit width from extended multiplier output back to original audio format
--          Implements saturation (clipping) to prevent audio distortion from mathematical overflow
ENTITY volume_saturator IS
    GENERIC (
        TDATA_WIDTH : POSITIVE := 24;       -- Width of final audio data output (24-bit audio samples)
        VOLUME_WIDTH : POSITIVE := 10;      -- Width of volume control input (10-bit = 0-1023 range)
        VOLUME_STEP_2 : POSITIVE := 6;      -- Log2 of volume values per step (2^6 = 64 values per step)
        HIGHER_BOUND : INTEGER := 2 ** 15 - 1; -- Maximum positive value for saturation (inclusive)
        LOWER_BOUND : INTEGER := - 2 ** 15     -- Maximum negative value for saturation (inclusive)
    );
    PORT (
        -- Clock and reset signals
        aclk : IN STD_LOGIC;        -- Main clock input
        aresetn : IN STD_LOGIC;     -- Active-low asynchronous reset

        -- AXI4-Stream Slave Interface (Extended width input from multiplier)
        s_axis_tvalid : IN STD_LOGIC;                                                                         -- Input data valid signal
        s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 + 2 ** (VOLUME_WIDTH - VOLUME_STEP_2 - 1) DOWNTO 0); -- Wide input data from multiplier
        s_axis_tlast : IN STD_LOGIC;                                                                          -- Channel indicator (0=left, 1=right)
        s_axis_tready : OUT STD_LOGIC;                                                                        -- Ready to accept input data

        -- AXI4-Stream Master Interface (Original width output for audio)
        m_axis_tvalid : OUT STD_LOGIC;                                     -- Output data valid signal
        m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);   -- Saturated audio sample output
        m_axis_tlast : OUT STD_LOGIC;                                      -- Channel indicator passthrough
        m_axis_tready : IN STD_LOGIC                                       -- Downstream ready signal
    );
END volume_saturator;

ARCHITECTURE Behavioral OF volume_saturator IS

    -- Pre-calculated saturation bounds as STD_LOGIC_VECTORS for efficient comparison
    -- These constants define the valid range for audio samples after volume processing
    CONSTANT HIGHER_BOUND_VEC : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0) := STD_LOGIC_VECTOR(to_signed(HIGHER_BOUND, TDATA_WIDTH));
    CONSTANT LOWER_BOUND_VEC : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0) := STD_LOGIC_VECTOR(to_signed(LOWER_BOUND, TDATA_WIDTH));

    -- Internal AXI4-Stream control signal
    SIGNAL m_axis_tvalid_int : STD_LOGIC;

BEGIN

    -- Connect internal signals to output ports
    m_axis_tvalid <= m_axis_tvalid_int;
    
    -- Input ready logic: Ready when downstream is ready OR no valid data pending, AND not in reset
    -- This implements proper AXI4-Stream backpressure handling
    s_axis_tready <= (m_axis_tready OR NOT m_axis_tvalid_int) AND aresetn;

    -- Main saturation and data processing logic
    PROCESS (aclk)
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset output interface
                m_axis_tvalid_int <= '0';  -- No valid output data during reset
                m_axis_tlast <= '0';       -- Clear channel indicator

            ELSE
                -- Normal operation

                -- Output handshake management:
                -- Clear valid flag when downstream accepts data
                IF m_axis_tready = '1' THEN
                    m_axis_tvalid_int <= '0';
                END IF;

                -- Data processing: Apply saturation when both input and output are ready
                IF s_axis_tvalid = '1' AND m_axis_tready = '1' THEN
                    
                    -- Saturation Logic:
                    -- Check if the wide input data exceeds the valid audio range
                    -- If so, clip (saturate) to the nearest valid value
                    -- This prevents overflow distortion while preserving audio quality
                    
                    IF signed(s_axis_tdata) > signed(HIGHER_BOUND_VEC) THEN
                        -- Positive overflow: Clip to maximum positive value
                        -- This prevents "wraparound" distortion from mathematical overflow
                        m_axis_tdata <= HIGHER_BOUND_VEC;

                    ELSIF signed(s_axis_tdata) < signed(LOWER_BOUND_VEC) THEN
                        -- Negative overflow: Clip to maximum negative value
                        -- This prevents "wraparound" distortion from mathematical underflow
                        m_axis_tdata <= LOWER_BOUND_VEC;

                    ELSE
                        -- Value within valid range: Resize to output width without clipping
                        -- This preserves the original audio quality when no overflow occurs
                        m_axis_tdata <= STD_LOGIC_VECTOR(resize(signed(s_axis_tdata), TDATA_WIDTH));
                        
                    END IF;

                    -- Set output control signals
                    m_axis_tvalid_int <= '1';        -- Mark output data as valid
                    m_axis_tlast <= s_axis_tlast;    -- Pass through channel indicator

                END IF;

            END IF;

        END IF;

    END PROCESS;

    -- Saturation Purpose and Benefits:
    -- 1. Prevents audio distortion from mathematical overflow
    -- 2. Maintains audio dynamic range within valid bit representation
    -- 3. Reduces wide multiplication results back to standard audio format
    -- 4. Provides "soft limiting" behavior for volume control
    -- 5. Ensures compatibility with downstream audio processing blocks

END Behavioral;