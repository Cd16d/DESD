LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Entity: led_level_controller
-- Purpose: Audio level meter using LEDs to display real-time audio amplitude
--          Processes stereo audio samples and drives a bar graph LED display
--          Provides visual feedback of audio signal strength for both channels combined
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
        led : OUT STD_LOGIC_VECTOR(NUM_LEDS - 1 DOWNTO 0);  -- LED control signals (1=on, 0=off)

        -- AXI4-Stream Slave Interface (Audio Input)
        s_axis_tvalid : IN STD_LOGIC;                                      -- Input data valid signal
        s_axis_tdata : IN STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0);  -- Audio sample input
        s_axis_tlast : IN STD_LOGIC;                                       -- Channel indicator (0=right, 1=left)
        s_axis_tready : OUT STD_LOGIC                                      -- Always ready to accept data
    );
END led_level_controller;

ARCHITECTURE Behavioral OF led_level_controller IS

    -- Calculate number of clock cycles for LED refresh timing
    -- Example: 1ms refresh at 100MHz = (1*1,000,000)/10 = 100,000 cycles
    CONSTANT REFRESH_CYCLES : NATURAL := (refresh_time_ms * 1_000_000) / clock_period_ns;

    -- Audio processing signals
    SIGNAL abs_audio_left : unsigned(CHANNEL_LENGHT - 2 DOWNTO 0) := (OTHERS => '0');      -- Absolute value of left channel
    SIGNAL abs_audio_right : unsigned(CHANNEL_LENGHT - 2 DOWNTO 0) := (OTHERS => '0');     -- Absolute value of right channel

    -- LED control signals
    SIGNAL leds_int : STD_LOGIC_VECTOR(NUM_LEDS - 1 DOWNTO 0) := (OTHERS => '0');          -- Internal LED state
    SIGNAL led_update : STD_LOGIC := '0';                                                    -- Trigger for LED refresh

    -- Timing control
    SIGNAL refresh_counter : NATURAL RANGE 0 TO REFRESH_CYCLES - 1 := 0;                   -- Counter for refresh timing

BEGIN

    -- Connect internal signals to output ports
    led <= leds_int;           -- Drive external LEDs with internal state
    s_axis_tready <= '1';      -- Always ready to accept audio data (no backpressure)

    -- Audio sample processing and absolute value calculation
    -- Converts signed audio samples to unsigned absolute values for level detection
    PROCESS (aclk)
        VARIABLE sdata_signed : signed(CHANNEL_LENGHT - 1 DOWNTO 0);    -- Temporary signed audio value
        VARIABLE abs_value : unsigned(CHANNEL_LENGHT - 1 DOWNTO 0);     -- Temporary absolute value
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset: Clear all audio processing signals
                abs_audio_left <= (OTHERS => '0');    -- Clear left channel level
                abs_audio_right <= (OTHERS => '0');   -- Clear right channel level

            ELSIF s_axis_tvalid = '1' THEN
                -- Process new audio sample when valid data is available
                sdata_signed := signed(s_axis_tdata);  -- Convert input to signed format

                -- Absolute value calculation for amplitude detection
                -- Handle two's complement signed numbers correctly
                IF s_axis_tdata(s_axis_tdata'high) = '1' THEN
                    -- Negative number: Take two's complement to get absolute value
                    abs_value := unsigned(-sdata_signed);
                ELSE
                    -- Positive number: Direct conversion to unsigned
                    abs_value := unsigned(sdata_signed);
                END IF;

                -- Channel assignment based on tlast signal
                -- Note: Channel assignment appears reversed from typical convention
                IF s_axis_tlast = '1' THEN
                    -- tlast = '1': Assign to left channel
                    abs_audio_left <= abs_value(CHANNEL_LENGHT - 2 DOWNTO 0);
                ELSE
                    -- tlast = '0': Assign to right channel  
                    abs_audio_right <= abs_value(CHANNEL_LENGHT - 2 DOWNTO 0);
                END IF;

            END IF;

        END IF;

    END PROCESS;

    -- LED refresh timing control
    -- Generates periodic update signals for smooth LED display updates
    PROCESS (aclk)
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset timing control
                refresh_counter <= 0;      -- Clear refresh counter
                led_update <= '0';         -- Clear update trigger

            ELSIF refresh_counter = REFRESH_CYCLES - 1 THEN
                -- End of refresh period: Trigger LED update
                refresh_counter <= 0;      -- Reset counter for next period
                led_update <= '1';         -- Set update trigger

            ELSE
                -- Continue counting refresh period
                refresh_counter <= refresh_counter + 1;  -- Increment counter
                led_update <= '0';                       -- Clear update trigger

            END IF;

        END IF;

    END PROCESS;

    -- LED level calculation and bar graph generation
    -- Combines left and right channel levels and maps to LED array
    PROCESS (aclk)
        VARIABLE leds_on : NATURAL RANGE 0 TO NUM_LEDS;                      -- Number of LEDs to illuminate
        VARIABLE temp_led_level : INTEGER RANGE 0 TO NUM_LEDS;               -- Calculated LED level
        VARIABLE abs_audio_sum : unsigned(CHANNEL_LENGHT - 1 DOWNTO 0);     -- Combined channel amplitude
    BEGIN

        IF rising_edge(aclk) THEN

            IF aresetn = '0' THEN
                -- Reset: Turn off all LEDs
                leds_int <= (OTHERS => '0');

            ELSIF led_update = '1' THEN
                -- Update LED display when refresh trigger is active

                -- Combine left and right channel amplitudes
                abs_audio_sum := abs_audio_left + abs_audio_right;

                -- Level calculation with linear scaling to get the best visual result
                IF abs_audio_sum = 0 THEN
                    -- Mute: No LEDs illuminated
                    temp_led_level := 0;

                ELSE
                    -- Right shift by (CHANNEL_LENGHT - 4) to take in account only the most significant bits
                    -- to scale the audio amplitude in a linear way to fit within the LED range
                    temp_led_level := 1 + to_integer(shift_right(abs_audio_sum, CHANNEL_LENGHT - 4));

                END IF;

                -- Limit LED level to available LEDs (prevent array overflow)
                IF temp_led_level > NUM_LEDS THEN
                    leds_on := NUM_LEDS;           -- Cap at maximum LEDs
                ELSE
                    leds_on := temp_led_level;     -- Use calculated level
                END IF;

                -- Generate bar graph pattern: illuminate LEDs from 0 to (leds_on-1)
                -- This creates a classic audio level meter appearance
                leds_int <= (OTHERS => '0');      -- Start with all LEDs off

                IF leds_on > 0 THEN
                    -- Turn on LEDs from index 0 up to (leds_on-1)
                    -- Creates solid bar from bottom to current level
                    leds_int(leds_on - 1 DOWNTO 0) <= (OTHERS => '1');
                END IF;

            END IF;

        END IF;

    END PROCESS;

END Behavioral;