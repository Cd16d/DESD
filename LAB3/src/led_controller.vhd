LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Entity: led_controller
-- Purpose: Controls RGB LED indicators based on audio system status
--          Provides visual feedback for mute and filter enable states
ENTITY led_controller IS
    GENERIC (
        LED_WIDTH : POSITIVE := 8  -- Width of LED intensity control (8-bit = 0-255 intensity levels)
    );
    PORT (
        -- Control input signals
        mute_enable : IN STD_LOGIC;    -- Mute status (1=audio muted, 0=audio active)
        filter_enable : IN STD_LOGIC;  -- Filter status (1=filter active, 0=filter bypassed)

        -- RGB LED output signals (intensity control)
        led_r : OUT STD_LOGIC_VECTOR(LED_WIDTH - 1 DOWNTO 0);  -- Red LED intensity (0-255)
        led_g : OUT STD_LOGIC_VECTOR(LED_WIDTH - 1 DOWNTO 0);  -- Green LED intensity (0-255)
        led_b : OUT STD_LOGIC_VECTOR(LED_WIDTH - 1 DOWNTO 0)   -- Blue LED intensity (0-255)
    );
END led_controller;

ARCHITECTURE Behavioral OF led_controller IS

    -- Constants for LED intensity levels
    CONSTANT ALL_ON : STD_LOGIC_VECTOR(LED_WIDTH - 1 DOWNTO 0) := (OTHERS => '1');   -- Maximum brightness (255)
    CONSTANT ALL_OFF : STD_LOGIC_VECTOR(LED_WIDTH - 1 DOWNTO 0) := (OTHERS => '0');  -- LED off (0)

BEGIN

    -- LED Status Indication Logic:
    -- Priority-based color coding for system status
    -- 
    -- Color Scheme:
    -- RED    = Mute active (highest priority - audio completely off)
    -- BLUE   = Filter active (medium priority - audio processing enabled)
    -- GREEN  = Normal operation (lowest priority - audio pass-through)

    -- Red LED Control: Indicates mute status
    -- Turn on red LED when audio is muted, regardless of filter state
    led_r <= ALL_ON WHEN mute_enable = '1' ELSE
        ALL_OFF;

    -- Blue LED Control: Indicates filter activation
    -- Turn on blue LED when filter is active AND audio is not muted
    -- Mute has higher priority than filter indication
    led_b <= ALL_ON WHEN (mute_enable = '0' AND filter_enable = '1') ELSE
        ALL_OFF;

    -- Green LED Control: Indicates normal operation
    -- Turn on green LED when audio is active (not muted) AND filter is disabled
    -- This represents the default "audio pass-through" state
    led_g <= ALL_ON WHEN (mute_enable = '0' AND filter_enable = '0') ELSE
        ALL_OFF;

    -- Truth Table for LED States:
    -- mute_enable | filter_enable | RED | GREEN | BLUE | Status
    -- ------------|---------------|-----|-------|------|------------------
    --      0      |       0       |  0  |   1   |  0   | Normal (Green)
    --      0      |       1       |  0  |   0   |  1   | Filter On (Blue)
    --      1      |       0       |  1  |   0   |  0   | Muted (Red)
    --      1      |       1       |  1  |   0   |  0   | Muted (Red)

END Behavioral;