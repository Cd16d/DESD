LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.MATH_REAL.ALL;

-- Entity: led_level_controller
-- Purpose: Audio level meter using LEDs to display real-time audio amplitude
--          Processes stereo audio samples and drives a bar graph LED display
ENTITY led_level_controller IS
    GENERIC (
        NUM_LEDS : POSITIVE := 16;          -- Number of LEDs in the level meter display
        CHANNEL_LENGHT : POSITIVE := 24;    -- Width of audio data (24-bit audio samples)
        refresh_time_ms : POSITIVE := 1;    -- LED refresh rate in milliseconds (1ms = 1kHz update rate)
        clock_period_ns : POSITIVE := 10    -- System clock period in nanoseconds (10ns = 100MHz)
    );
    PORT (
        -- Clock and reset signals
        aclk : IN STD_LOGIC;        -- Main clock input
        aresetn : IN STD_LOGIC;     -- Active-low asynchronous reset

        -- LED output array (bar graph display)
        led : OUT STD_LOGIC_VECTOR(NUM_LEDS - 1 DOWNTO 0);      -- LED control signals (1=on, 0=off)

        -- AXI4-Stream Slave Interface (Audio Input)
        s_axis_tvalid : IN STD_LOGIC;                                       -- Input data valid signal
        s_axis_tdata : IN STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0);    -- Audio sample input
        s_axis_tlast : IN STD_LOGIC;                                        -- Channel indicator (0=right, 1=left)
        s_axis_tready : OUT STD_LOGIC                                       -- Always ready to accept data
    );
END led_level_controller;

ARCHITECTURE Behavioral OF led_level_controller IS

    -- Calculate clock cycles needed for LED refresh timing
    CONSTANT REFRESH_CYCLES : INTEGER := (refresh_time_ms * 1_000_000) / clock_period_ns - 1;

    -- Calculate the number of bits needed to represent the number of LEDs
    CONSTANT NUMLEDS_BITS : INTEGER := INTEGER(ceil(log2(real(NUM_LEDS))));

    -- LED refresh timing control signals
    SIGNAL refresh_counter : INTEGER RANGE 0 TO REFRESH_CYCLES := 0; -- Counts clock cycles between LED updates
    SIGNAL refresh_tick : STD_LOGIC := '0'; -- Pulse signal generated every refresh period

    -- Audio amplitude storage for both stereo channels
    -- Stores absolute values (magnitude) of left and right audio channels
    SIGNAL abs_l, abs_r : UNSIGNED(CHANNEL_LENGHT - 1 DOWNTO 0) := (OTHERS => '0'); -- Absolute amplitude registers

BEGIN

    -- Always ready for AXI4-Stream input
    s_axis_tready <= '1';

    -- Capture absolute value of input sample for left/right channel
    PROCESS (aclk)

        VARIABLE signed_sample : SIGNED(CHANNEL_LENGHT - 1 DOWNTO 0);

    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset: Clear both channel amplitude registers
                abs_l <= (OTHERS => '0');
                abs_r <= (OTHERS => '0');

            ELSIF s_axis_tvalid = '1' THEN
                -- Valid audio data received: Process the sample
                signed_sample := SIGNED(s_axis_tdata); -- Convert input to signed for ABS operation

                -- Channel routing based on AXI4-Stream tlast signal
                -- tlast = '1' indicates left channel, tlast = '0' indicates right channel
                IF s_axis_tlast = '1' THEN
                    -- Left channel: Store absolute value of audio sample
                    abs_l <= UNSIGNED(ABS(signed_sample));
                ELSE
                    -- Right channel: Store absolute value of audio sample
                    abs_r <= UNSIGNED(ABS(signed_sample));
                END IF;

            END IF;

        END IF;

    END PROCESS;

    -- LED refresh tick generator
    PROCESS (aclk)
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset: Initialize counter and tick signal
                refresh_counter <= 0;
                refresh_tick <= '0';

            ELSE
                IF refresh_counter = REFRESH_CYCLES THEN
                    refresh_counter <= 0;
                    refresh_tick <= '1';

                ELSE
                    refresh_counter <= refresh_counter + 1;
                    refresh_tick <= '0';

                END IF;

            END IF;

        END IF;

    END PROCESS;

    -- LED level calculation and bar graph generation process
    -- Combines left and right channel amplitudes and converts to LED display pattern
    -- Updates only when refresh_tick is active to maintain stable visual display
    PROCESS (aclk)

        VARIABLE combined_amp : UNSIGNED(CHANNEL_LENGHT - 1 DOWNTO 0);
        VARIABLE led_level : INTEGER RANGE 0 TO 2 ** NUMLEDS_BITS := 0;

    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset: Turn off all LEDs and reset level counter
                led <= (OTHERS => '0');

            ELSIF refresh_tick = '1' THEN
                -- LED update cycle: Calculate new LED pattern based on audio amplitude

                -- Combine left and right channel amplitudes
                -- RESIZE ensures the sum fits within the variable's bit width.
                -- There isn't data loss since both abs_l and abs_r are one bit shorter than combined_amp,
                -- due to the absolute value operation.
                combined_amp := RESIZE(abs_l + abs_r, combined_amp'LENGTH);

                -- Linear scale to LED level conversion to get the best visual effect
                IF combined_amp = 0 THEN
                    led_level := 0; -- No audio signal, turn off all LEDs
                ELSE
                    led_level := 1 + to_integer(shift_right(combined_amp, CHANNEL_LENGHT - NUMLEDS_BITS));
                END IF;

                -- Saturation protection: Limit LED level to maximum available LEDs
                -- Prevents overflow and ensures the LED index stays within bounds.
                IF led_level > NUM_LEDS THEN
                    led_level := NUM_LEDS;
                END IF;

                -- Update LED output based on calculated level
                led <= (OTHERS => '0');
                IF led_level > 0 THEN
                    led(led_level - 1 DOWNTO 0) <= (OTHERS => '1');
                END IF;

            END IF;

        END IF;

    END PROCESS;

END Behavioral;