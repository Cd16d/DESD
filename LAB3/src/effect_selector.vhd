LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

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
        effect : IN STD_LOGIC;    -- Effect mode selector (0=volume/balance mode, 1=LFO)
        jstck_x : IN STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);  -- X-axis joystick position
        jstck_y : IN STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);  -- Y-axis joystick position

        -- Output control parameters
        volume : OUT STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);     -- Volume control output
        balance : OUT STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0);    -- Balance control output
        lfo_period : OUT STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0)  -- LFO period control output
    );
END effect_selector;

ARCHITECTURE Behavioral OF effect_selector IS

    constant JOYSTICK_DEFAULT : STD_LOGIC_VECTOR(JOYSTICK_LENGHT - 1 DOWNTO 0) := STD_LOGIC_VECTOR(to_unsigned(2 ** (JOYSTICK_LENGHT - 1), JOYSTICK_LENGHT)); -- Default joystick value (center position for 10-bit joystick is 512)
    
BEGIN

    -- Main control logic process
    -- Routes joystick axes to appropriate audio control parameters based on selected mode
    PROCESS (aclk)
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset all outputs to default/center values
                volume <= JOYSTICK_DEFAULT;      -- Default volume (center position)
                balance <= JOYSTICK_DEFAULT;     -- Center balance position
                lfo_period <= JOYSTICK_DEFAULT;  -- Default LFO period (center position)

            ELSE
                -- Normal operation: Route joystick inputs based on effect mode

                -- Y-axis always controls different parameters based on effect mode
                -- X-axis behavior differs between modes
                -- Note: When switching between modes, some outputs are reset while others preserved
                IF effect = '1' THEN
                    -- LFO Mode:
                    -- Y-axis controls Low Frequency Oscillator period
                    -- X-axis is ignored in this mode
                    lfo_period <= jstck_y;

                    -- Volume remains at last set value (preserved from previous mode)

                    -- Reset balance to center/default position when in LFO mode
                    balance <= JOYSTICK_DEFAULT;  -- Reset balance to center position

                ELSE
                    -- Volume/Balance Mode:
                    -- Y-axis controls overall volume level
                    -- X-axis controls left/right audio balance
                    volume <= jstck_y;
                    balance <= jstck_x;

                    -- LFO period remains at last set value (preserved from previous LFO mode)

                END IF;

            END IF;

        END IF;

    END PROCESS;

END Behavioral;