LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Entity: volume_multiplier
-- Purpose: First stage of volume control pipeline - multiplies audio samples by volume scaling factor
--          Uses bit-shifting multiplication for efficient hardware implementation
--          Implements exponential volume scaling for natural-feeling volume control
ENTITY volume_multiplier IS
    GENERIC (
        TDATA_WIDTH : POSITIVE := 24;    -- Width of input audio data (24-bit audio samples)
        VOLUME_WIDTH : POSITIVE := 10;   -- Width of volume control input (10-bit = 0-1023 range)
        VOLUME_STEP_2 : POSITIVE := 6    -- Log2 of volume values per step (2^6 = 64 values per step)
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

        -- AXI4-Stream Master Interface (Audio Output with extended width)
        m_axis_tvalid : OUT STD_LOGIC;                                                                         -- Output data valid signal
        m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 + 2 ** (VOLUME_WIDTH - VOLUME_STEP_2 - 1) DOWNTO 0); -- Extended width output data
        m_axis_tlast : OUT STD_LOGIC;                                                                          -- Channel indicator passthrough
        m_axis_tready : IN STD_LOGIC;                                                                          -- Downstream ready signal

        -- Volume control input
        volume : IN STD_LOGIC_VECTOR(VOLUME_WIDTH - 1 DOWNTO 0)  -- Volume level (0=minimum, 1023=maximum)
    );
END volume_multiplier;

ARCHITECTURE Behavioral OF volume_multiplier IS

    -- Calculate volume control parameters based on generics
    CONSTANT VOLUME_STEPS : INTEGER := (2 ** (VOLUME_WIDTH - 1)) / (2 ** VOLUME_STEP_2) + 1; -- Number of volume steps (9 steps for 10-bit)
    CONSTANT VOL_MID : INTEGER := 2 ** (VOLUME_WIDTH - 1);                                    -- Center volume position (512 for 10-bit)
    CONSTANT DEAD_ZONE : INTEGER := (2 ** VOLUME_STEP_2) / 2;                                 -- Dead zone around center (32 for step size 64)

    -- Volume scaling factor as exponential multiplier
    -- Positive values = amplification (left shift), negative values = attenuation (right shift)
    SIGNAL volume_exp_mult : INTEGER RANGE -VOLUME_STEPS TO VOLUME_STEPS := 0;

    -- Internal AXI4-Stream signals
    SIGNAL m_axis_tvalid_int : STD_LOGIC;  -- Internal valid signal for output

BEGIN
    -- Connect internal signals to output ports
    m_axis_tvalid <= m_axis_tvalid_int;
    
    -- Input ready logic: Ready when downstream is ready OR no valid data pending, AND not in reset
    -- This implements proper AXI4-Stream backpressure handling
    s_axis_tready <= (m_axis_tready OR NOT m_axis_tvalid_int) AND aresetn;

    -- Volume to exponent conversion process
    -- Converts joystick position to bit-shift amount for exponential volume scaling
    PROCESS (aclk)
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset: Set to unity gain (no scaling)
                volume_exp_mult <= 0;

            ELSE
                -- Volume mapping and conversion to exponential scaling factor:
                -- 1. Convert volume to signed value
                -- 2. Center around middle position (VOL_MID)
                -- 3. Apply dead zone offset for smooth center operation
                -- 4. Divide by step size to get exponential scaling factor
                --
                -- Volume Range Mapping:
                -- volume = 0-479:    Negative exponent (attenuation, right shift)
                -- volume = 480-543:  Zero exponent (unity gain, dead zone)
                -- volume = 544-1023: Positive exponent (amplification, left shift)
                volume_exp_mult <= to_integer(
                    shift_right(
                        signed('0' & volume) - to_signed(VOL_MID - DEAD_ZONE, volume'length + 1),
                        VOLUME_STEP_2
                    )
                );

            END IF;

        END IF;

    END PROCESS;

    -- AXI4-Stream data processing
    -- Applies exponential volume scaling using bit-shifting multiplication
    PROCESS (aclk)
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset output interface
                m_axis_tvalid_int <= '0';  -- No valid output data
                m_axis_tlast <= '0';       -- Clear channel indicator

            ELSE
                -- Output handshake management:
                -- Clear valid flag when downstream accepts data
                IF m_axis_tready = '1' THEN
                    m_axis_tvalid_int <= '0';
                END IF;

                -- Data processing: Apply volume scaling when both input and output are ready
                IF s_axis_tvalid = '1' AND m_axis_tready = '1' THEN
                    -- Volume scaling using bit-shifting for exponential response:
                    -- 
                    -- Joystick mapping (from datasheet):
                    -- Y-axis: 0 = tilted all the way down (minimum volume)
                    --         1023 = tilted all the way up (maximum volume)
                    --
                    -- Scaling method:
                    -- Positive exponent: Left shift = amplification (multiply by 2^n)
                    -- Negative exponent: Right shift = attenuation (divide by 2^n)
                    -- Zero exponent: No shift = unity gain (pass through)
                    
                    IF volume_exp_mult >= 0 THEN
                        -- Amplification: Left shift for volume boost
                        -- Resize to extended width first to prevent overflow
                        m_axis_tdata <= STD_LOGIC_VECTOR(
                            shift_left(
                                resize(signed(s_axis_tdata), m_axis_tdata'LENGTH), 
                                volume_exp_mult
                            )
                        );

                    ELSE
                        -- Attenuation: Right shift for volume reduction
                        -- Arithmetic right shift preserves sign for signed audio data
                        m_axis_tdata <= STD_LOGIC_VECTOR(
                            shift_right(
                                resize(signed(s_axis_tdata), m_axis_tdata'LENGTH), 
                                - volume_exp_mult  -- Convert negative to positive shift amount
                            )
                        );

                    END IF;

                    -- Set output control signals
                    m_axis_tvalid_int <= '1';        -- Mark output data as valid
                    m_axis_tlast <= s_axis_tlast;    -- Pass through channel indicator

                END IF;

            END IF;

        END IF;

    END PROCESS;

    -- Example scaling factors (VOLUME_STEP_2 = 6, 64 values per step):
    -- volume_exp_mult = -3: Divide by 8 (>>3)
    -- volume_exp_mult = -2: Divide by 4 (>>2)
    -- volume_exp_mult = -1: Divide by 2 (>>1)
    -- volume_exp_mult =  0: No change (unity)
    -- volume_exp_mult = +1: Multiply by 2 (<<1)
    -- volume_exp_mult = +2: Multiply by 4 (<<2)
    -- volume_exp_mult = +3: Multiply by 8 (<<3)

END Behavioral;