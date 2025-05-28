LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

-- Entity: balance_controller
-- Purpose: Controls the stereo balance (left/right channel volume) of audio data
--          based on a balance control input. Implements variable attenuation
--          using bit shifting for efficient hardware implementation.
ENTITY balance_controller IS
    GENERIC (
        TDATA_WIDTH : POSITIVE := 24;     -- Width of audio data bus (24-bit audio samples)
        BALANCE_WIDTH : POSITIVE := 10;   -- Width of balance control input (10-bit = 0-1023 range)
        BALANCE_STEP_2 : POSITIVE := 6    -- Log2 of balance values per step (2^6 = 64 values per step)
    );
    PORT (
        -- Clock and reset
        aclk : IN STD_LOGIC;      -- Main clock
        aresetn : IN STD_LOGIC;   -- Active-low asynchronous reset

        -- AXI4-Stream Slave Interface (Audio Input)
        s_axis_tvalid : IN STD_LOGIC;                                      -- Input data valid
        s_axis_tdata : IN STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);    -- Audio sample data
        s_axis_tready : OUT STD_LOGIC;                                     -- Ready to accept input
        s_axis_tlast : IN STD_LOGIC;                                       -- Channel indicator (0=left, 1=right)

        -- AXI4-Stream Master Interface (Audio Output)
        m_axis_tvalid : OUT STD_LOGIC;                                     -- Output data valid
        m_axis_tdata : OUT STD_LOGIC_VECTOR(TDATA_WIDTH - 1 DOWNTO 0);   -- Balanced audio sample
        m_axis_tready : IN STD_LOGIC;                                      -- Downstream ready
        m_axis_tlast : OUT STD_LOGIC;                                      -- Channel indicator passthrough

        -- Balance Control Input
        balance : IN STD_LOGIC_VECTOR(BALANCE_WIDTH - 1 DOWNTO 0)         -- Balance position (0=full left, 1023=full right, 512=center)
    );
END balance_controller;

ARCHITECTURE Behavioral OF balance_controller IS

    -- Balance calculation constants
    CONSTANT BALANCE_STEPS : INTEGER := (2 ** (BALANCE_WIDTH - 1)) / (2 ** BALANCE_STEP_2) + 1; -- Number of attenuation steps (9 steps for 10-bit balance)
    CONSTANT BAL_MID : INTEGER := 2 ** (BALANCE_WIDTH - 1);                                      -- Center balance position (512 for 10-bit)
    CONSTANT DEAD_ZONE : INTEGER := (2 ** BALANCE_STEP_2) / 2;                                   -- Dead zone around center (32 for step size 64)

    -- Channel attenuation levels (number of bit shifts for volume reduction)
    SIGNAL left_channel : INTEGER RANGE 0 TO BALANCE_STEPS := 0;   -- Left channel attenuation (0 = no attenuation, higher = more attenuation)
    SIGNAL right_channel : INTEGER RANGE 0 TO BALANCE_STEPS := 0;  -- Right channel attenuation (0 = no attenuation, higher = more attenuation)

    -- Internal AXI signals
    SIGNAL m_axis_tvalid_int : STD_LOGIC; -- Internal valid signal for output

BEGIN
    -- Connect internal signals to output ports
    m_axis_tvalid <= m_axis_tvalid_int;
    -- Input ready logic: Ready when downstream is ready OR no valid data pending, AND not in reset
    s_axis_tready <= (m_axis_tready OR NOT m_axis_tvalid_int) AND aresetn;

    -- Balance calculation process
    -- Converts joystick x-axis position to attenuation levels for each channel
    BALANCE_CALC : PROCESS (aclk)
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset: No attenuation on either channel
                left_channel <= 0;
                right_channel <= 0;

            ELSE
                -- Balance Mapping:
                -- balance = 0-479:    Left (right channel attenuated)
                -- balance = 480-543:  Center with dead zone (no attenuation)
                -- balance = 544-1023: Right (left channel attenuated)

                -- Right-leaning balance: Attenuate left channel
                IF to_integer(unsigned(balance)) > (BAL_MID + DEAD_ZONE) THEN
                    -- Calculate left channel attenuation based on how far right of center
                    -- Subtract center+deadzone, divide by step size, add 1 for rounding
                    left_channel <= to_integer((unsigned(balance) - to_unsigned(BAL_MID + DEAD_ZONE, balance'length)) SRL BALANCE_STEP_2) + 1;
                ELSE
                    -- Balance not significantly right of center: no left attenuation
                    left_channel <= 0;
                END IF;

                -- Left-leaning balance: Attenuate right channel
                IF to_integer(unsigned(balance)) < (BAL_MID - DEAD_ZONE) THEN
                    -- Calculate right channel attenuation based on how far left of center
                    -- Subtract balance from center-deadzone, divide by step size, add 1 for rounding
                    right_channel <= to_integer((to_unsigned(BAL_MID - DEAD_ZONE, balance'length) - unsigned(balance)) SRL BALANCE_STEP_2) + 1;
                ELSE
                    -- Balance not significantly left of center: no right attenuation
                    right_channel <= 0;
                END IF;

            END IF;

        END IF;

    END PROCESS BALANCE_CALC;

    -- AXI4-Stream data processing
    -- Applies calculated attenuation to audio samples based on channel
    AXIS : PROCESS (aclk)
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset output interface
                m_axis_tvalid_int <= '0';  -- No valid output data
                m_axis_tlast <= '0';       -- Clear channel indicator

            ELSE
                -- Output handshake: Clear valid flag when downstream accepts data
                IF m_axis_tready = '1' THEN
                    m_axis_tvalid_int <= '0';
                END IF;

                -- Data processing: Apply balance when input and output are ready
                IF s_axis_tvalid = '1' AND m_axis_tready = '1' THEN
                    -- Channel identification based on tlast signal:
                    -- tlast = '0': Left channel sample
                    -- tlast = '1': Right channel sample
                    
                    IF s_axis_tlast = '0' THEN 
                        -- Left channel: Apply left channel attenuation
                        -- Arithmetic right shift preserves sign for signed audio data
                        m_axis_tdata <= STD_LOGIC_VECTOR(shift_right(signed(s_axis_tdata), left_channel));
                    ELSE 
                        -- Right channel: Apply right channel attenuation
                        -- Arithmetic right shift preserves sign for signed audio data
                        m_axis_tdata <= STD_LOGIC_VECTOR(shift_right(signed(s_axis_tdata), right_channel));
                    END IF;

                    -- Set output control signals
                    m_axis_tvalid_int <= '1';        -- Mark output as valid
                    m_axis_tlast <= s_axis_tlast;    -- Pass through channel indicator

                END IF;

            END IF;

        END IF;

    END PROCESS AXIS;

END Behavioral;