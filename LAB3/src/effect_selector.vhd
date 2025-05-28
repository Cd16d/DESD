LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Entity: effect_selector
-- Purpose: Routes joystick input to different audio control parameters based on effect mode
--          Acts as a multiplexer/router for joystick control signals
ENTITY effect_selector IS
    GENERIC (
        JOYSTICK_LENGHT : INTEGER := 10  -- Width of joystick position data (10-bit = 0-1023 range)
    );
    PORT (
        -- Clock and reset signals
        aclk : IN STD_LOGIC;      -- Main clock input
        aresetn : IN STD_LOGIC;   -- Active-low asynchronous reset

        -- Control and input signals
        effect : IN STD_LOGIC;    -- Effect mode selector (0=volume/balance mode, 1=LFO/balance mode)
        jstck_x : IN STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);  -- X-axis joystick position
        jstck_y : IN STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);  -- Y-axis joystick position

        -- Output control parameters
        volume : OUT STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);     -- Volume control output
        balance : OUT STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);    -- Balance control output
        lfo_period : OUT STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0)  -- LFO period control output
    );
END effect_selector;

ARCHITECTURE Behavioral OF effect_selector IS

BEGIN

    -- Main control logic process
    -- Routes joystick axes to appropriate audio control parameters based on selected mode
    PROCESS (aclk)
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset all outputs to zero (minimum values)
                volume <= (OTHERS => '0');      -- Minimum volume
                balance <= (OTHERS => '0');     -- Full left balance
                lfo_period <= (OTHERS => '0');  -- Minimum LFO period

            ELSE
                -- Normal operation: Route joystick inputs based on effect mode

                -- X-axis always controls balance regardless of mode
                -- This provides consistent left/right audio balance control
                balance <= jstck_x;

                -- Y-axis control depends on selected effect mode
                -- Note: When switching between modes, the previous joystick values
                -- are preserved in the non-active outputs (volume/lfo_period)
                IF effect = '1' THEN
                    -- LFO Mode: Y-axis controls Low Frequency Oscillator period
                    -- Used for tremolo, vibrato, or other modulation effects
                    lfo_period <= jstck_y;
                    -- Volume remains at last set value (preserved from previous volume mode)

                ELSE
                    -- Volume/Balance Mode: Y-axis controls overall volume level
                    -- Traditional audio mixer control mode
                    volume <= jstck_y;
                    -- LFO period remains at last set value (preserved from previous LFO mode)

                END IF;

            END IF;

        END IF;

    END PROCESS;

END Behavioral;