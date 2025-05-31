LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Entity: led_level_controller
-- Purpose: Audio level meter using LEDs to display real-time audio amplitude
--          Processes stereo audio samples and drives a bar graph LED display
--          Provides visual feedback of audio signal strength for both channels combined
ENTITY led_level_controller IS
    GENERIC (
        NUM_LEDS : POSITIVE := 16; -- Number of LEDs in the level meter display
        CHANNEL_LENGHT : POSITIVE := 24; -- Width of audio data (24-bit audio samples)
        refresh_time_ms : POSITIVE := 1; -- LED refresh rate in milliseconds (1ms = 1kHz update rate)
        clock_period_ns : POSITIVE := 10 -- System clock period in nanoseconds (10ns = 100MHz)
    );
    PORT (
        -- Clock and reset signals
        aclk : IN STD_LOGIC; -- Main clock input
        aresetn : IN STD_LOGIC; -- Active-low asynchronous reset

        -- LED output array (bar graph display)
        led : OUT STD_LOGIC_VECTOR(NUM_LEDS - 1 DOWNTO 0); -- LED control signals (1=on, 0=off)

        -- AXI4-Stream Slave Interface (Audio Input)
        s_axis_tvalid : IN STD_LOGIC; -- Input data valid signal
        s_axis_tdata : IN STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0); -- Audio sample input
        s_axis_tlast : IN STD_LOGIC; -- Channel indicator (0=right, 1=left)
        s_axis_tready : OUT STD_LOGIC -- Always ready to accept data
    );
END led_level_controller;

ARCHITECTURE Behavioral OF led_level_controller IS

    -- Calculate clock cycles needed for LED refresh timing
    -- Formula: (refresh_time_ms * 1_000_000 ns/ms) / clock_period_ns
    -- Example: (1ms * 1,000,000) / 10ns = 100,000 cycles for 1ms refresh at 100MHz
    CONSTANT REFRESH_CYCLES : INTEGER := (refresh_time_ms * 1_000_000) / clock_period_ns;

    -- LED refresh timing control signals
    SIGNAL refresh_counter : INTEGER RANGE 0 TO REFRESH_CYCLES := 0; -- Counts clock cycles between LED updates
    SIGNAL refresh_tick : STD_LOGIC := '0'; -- Pulse signal generated every refresh period

    -- Audio amplitude storage for both stereo channels
    -- Stores absolute values (magnitude) of left and right audio channels
    SIGNAL abs_l, abs_r : UNSIGNED(CHANNEL_LENGHT - 1 DOWNTO 0) := (OTHERS => '0'); -- Absolute amplitude registers

BEGIN

    -- AXI4-Stream interface: Always ready to receive audio data
    -- This ensures continuous audio processing without backpressure
    s_axis_tready <= '1';

    -- Audio sample acquisition process based on channel identification
    -- Processes incoming stereo audio samples and converts to absolute amplitude values
    -- Uses s_axis_tlast to distinguish between left (1) and right (0) channels
    PROCESS (aclk)
        VARIABLE signed_sample : SIGNED(CHANNEL_LENGHT - 1 DOWNTO 0); -- Temporary variable for signed arithmetic
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

    -- LED refresh timing generator process
    -- Creates a periodic tick signal to control LED update rate
    -- Prevents LED flickering by limiting update frequency to human-visible rates
    PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                -- Reset: Initialize counter and tick signal
                refresh_counter <= 0;
                refresh_tick <= '0';
            ELSE
                -- Normal operation: Count clock cycles and generate refresh tick
                IF refresh_counter = REFRESH_CYCLES - 1 THEN
                    -- End of refresh period: Reset counter and generate tick pulse
                    refresh_counter <= 0;
                    refresh_tick <= '1'; -- Single clock cycle pulse for LED update
                ELSE
                    -- Continue counting: Increment counter, no tick
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
        VARIABLE combined_amp : UNSIGNED(CHANNEL_LENGHT - 1 DOWNTO 0); -- Combined amplitude of both channels
        VARIABLE led_level : INTEGER RANGE 0 TO NUM_LEDS := 0; -- Calculated LED level for bar graph display
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                -- Reset: Turn off all LEDs and reset level counter
                led <= (OTHERS => '0');

            ELSIF refresh_tick = '1' THEN
                -- LED update cycle: Calculate new LED pattern based on audio amplitude
                -- This section is executed once per refresh_tick to avoid flicker and ensure a stable display.

                -- Combine left and right channel amplitudes
                -- The sum of the absolute values of both channels gives a measure of total audio energy.
                -- RESIZE ensures the sum fits within the variable's bit width.
                combined_amp := RESIZE(abs_l + abs_r, combined_amp'LENGTH);

                -- Normalize combined amplitude to LED scale (0 to NUM_LEDS)
                -- The combined amplitude is mapped to the number of LEDs using a right shift.
                -- For 24-bit audio, shifting by (CHANNEL_LENGHT - 4) reduces the range to approximately 4 bits (0-15).
                -- Adding 1 ensures that at least one LED lights up for any non-zero audio input.
                -- Example: For 24-bit input, 1 + (combined_amp >> 20) gives a range from 1 to 16.
                led_level := 1 + to_integer(shift_right(combined_amp, CHANNEL_LENGHT - 4));

                -- Saturation protection: Limit LED level to maximum available LEDs
                -- Prevents overflow and ensures the LED index stays within bounds.
                IF led_level > NUM_LEDS THEN
                    led_level := NUM_LEDS;
                END IF;

                -- Generate bar graph LED pattern
                -- Implements a "thermometer" style display: all LEDs from 0 up to (led_level-1) are ON.
                -- All higher LEDs remain OFF.
                -- The assignment first turns all LEDs OFF, then sets the lower 'led_level' LEDs ON.
                led <= (OTHERS => '0');
                IF led_level > 0 THEN
                    led(led_level - 1 DOWNTO 0) <= (OTHERS => '1');
                END IF;
            END IF;
        END IF;
    END PROCESS;

END Behavioral;