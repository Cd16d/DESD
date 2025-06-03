LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Entity: volume_controller
-- Purpose: Controls audio volume by scaling audio samples according to volume control input
--          Implements a two-stage processing pipeline: multiplication followed by saturation
--          This approach prevents overflow and distortion in the audio signal
ENTITY volume_controller IS
    GENERIC (
        TDATA_WIDTH : POSITIVE := 24;       -- Width of audio data bus (24-bit audio samples)
        VOLUME_WIDTH : POSITIVE := 10;      -- Width of volume control input (10-bit = 0-1023 range)
        VOLUME_STEP_2 : POSITIVE := 6;      -- Log2 of volume values per step (2^6 = 64 values per step)
        HIGHER_BOUND : INTEGER := 2 ** 23 - 1; -- Maximum positive value for saturation (inclusive)
        LOWER_BOUND : INTEGER := - 2 ** 23     -- Maximum negative value for saturation (inclusive)
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
        m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);     -- Audio sample output (volume adjusted)
        m_axis_tlast : OUT STD_LOGIC;                                      -- Channel indicator passthrough
        m_axis_tready : IN STD_LOGIC;                                      -- Downstream ready signal

        -- Volume control input
        volume : IN STD_LOGIC_VECTOR(VOLUME_WIDTH - 1 DOWNTO 0)          -- Volume level (0=minimum, 1023=maximum)
    );
END volume_controller;

ARCHITECTURE Behavioral OF volume_controller IS

    -- Component declaration for volume multiplier
    -- First stage: multiplies audio samples by volume scaling factor
    -- Output has wider bit width to accommodate multiplication results
    COMPONENT volume_multiplier IS
        GENERIC (
            TDATA_WIDTH : POSITIVE := 24;     -- Input audio data width
            VOLUME_WIDTH : POSITIVE := 10;    -- Volume control width
            VOLUME_STEP_2 : POSITIVE := 6     -- Step size for volume control
        );
        PORT (
            aclk : IN STD_LOGIC;
            aresetn : IN STD_LOGIC;

            -- Input AXI4-Stream interface
            s_axis_tvalid : IN STD_LOGIC;
            s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
            s_axis_tlast : IN STD_LOGIC;
            s_axis_tready : OUT STD_LOGIC;

            -- Output AXI4-Stream interface (wider data width due to multiplication)
            m_axis_tvalid : OUT STD_LOGIC;
            m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 + 2 ** (VOLUME_WIDTH - VOLUME_STEP_2 - 1) DOWNTO 0);
            m_axis_tlast : OUT STD_LOGIC;
            m_axis_tready : IN STD_LOGIC;

            volume : IN STD_LOGIC_VECTOR(VOLUME_WIDTH - 1 DOWNTO 0)
        );
    END COMPONENT;

    -- Component declaration for volume saturator
    -- Second stage: clips multiplication results to prevent overflow and distortion
    -- Reduces bit width back to original audio format
    COMPONENT volume_saturator IS
        GENERIC (
            TDATA_WIDTH : POSITIVE := 24;     -- Final audio data width
            VOLUME_WIDTH : POSITIVE := 10;    -- Volume control width
            VOLUME_STEP_2 : POSITIVE := 6;    -- Step size for volume control
            HIGHER_BOUND : INTEGER := 2 ** 15 - 1; -- Upper saturation limit (inclusive)
            LOWER_BOUND : INTEGER := - 2 ** 15     -- Lower saturation limit (inclusive)
        );
        PORT (
            aclk : IN STD_LOGIC;
            aresetn : IN STD_LOGIC;

            -- Input AXI4-Stream interface (wide data from multiplier)
            s_axis_tvalid : IN STD_LOGIC;
            s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 + 2 ** (VOLUME_WIDTH - VOLUME_STEP_2 - 1) DOWNTO 0);
            s_axis_tlast : IN STD_LOGIC;
            s_axis_tready : OUT STD_LOGIC;

            -- Output AXI4-Stream interface (original audio data width)
            m_axis_tvalid : OUT STD_LOGIC;
            m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);
            m_axis_tlast : OUT STD_LOGIC;
            m_axis_tready : IN STD_LOGIC
        );
    END COMPONENT;

    -- Internal AXI4-Stream signals between multiplier and saturator
    -- These signals carry the wide multiplication results before saturation
    SIGNAL int_axis_tvalid : STD_LOGIC;                                                                           -- Valid signal between stages
    SIGNAL int_axis_tready : STD_LOGIC;                                                                           -- Ready signal between stages
    SIGNAL int_axis_tdata : STD_LOGIC_VECTOR(TDATA_WIDTH - 1 + 2 ** (VOLUME_WIDTH - VOLUME_STEP_2 - 1) DOWNTO 0); -- Wide data between stages
    SIGNAL int_axis_tlast : STD_LOGIC;                                                                            -- Channel indicator between stages

BEGIN

    -- Instantiate volume_multiplier (First Stage)
    -- Multiplies incoming audio samples by volume scaling factor
    -- Output has extended bit width to prevent loss of precision
    volume_multiplier_inst : volume_multiplier
        GENERIC MAP(
            TDATA_WIDTH => TDATA_WIDTH,     -- Input audio sample width
            VOLUME_WIDTH => VOLUME_WIDTH,   -- Volume control resolution
            VOLUME_STEP_2 => VOLUME_STEP_2  -- Volume step size
        )
        PORT MAP(
            aclk => aclk,
            aresetn => aresetn,

            -- Connect to external input interface
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tdata => s_axis_tdata,
            s_axis_tlast => s_axis_tlast,
            s_axis_tready => s_axis_tready,

            -- Connect to internal interface (wide data)
            m_axis_tvalid => int_axis_tvalid,
            m_axis_tdata => int_axis_tdata,
            m_axis_tlast => int_axis_tlast,
            m_axis_tready => int_axis_tready,

            volume => volume
        );

    -- Instantiate volume_saturator (Second Stage)
    -- Clips multiplication results to prevent overflow and distortion
    -- Reduces bit width back to original audio format for output
    volume_saturator_inst : volume_saturator
        GENERIC MAP(
            TDATA_WIDTH => TDATA_WIDTH,     -- Final audio sample width
            VOLUME_WIDTH => VOLUME_WIDTH,   -- Volume control resolution
            VOLUME_STEP_2 => VOLUME_STEP_2, -- Volume step size
            HIGHER_BOUND => HIGHER_BOUND,   -- Upper saturation limit
            LOWER_BOUND => LOWER_BOUND      -- Lower saturation limit
        )
        PORT MAP(
            aclk => aclk,
            aresetn => aresetn,

            -- Connect to internal interface (wide data from multiplier)
            s_axis_tvalid => int_axis_tvalid,
            s_axis_tdata => int_axis_tdata,
            s_axis_tlast => int_axis_tlast,
            s_axis_tready => int_axis_tready,

            -- Connect to external output interface
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tdata => m_axis_tdata,
            m_axis_tlast => m_axis_tlast,
            m_axis_tready => m_axis_tready
        );

    -- Pipeline Operation:
    -- 1. Audio samples enter volume_multiplier with original bit width
    -- 2. Multiplier scales samples by volume factor, output has extended bit width
    -- 3. Saturator clips results to prevent overflow, reduces to original bit width
    -- 4. Final audio samples has adjusted volume and bit width, ready for downstream processing

END Behavioral;