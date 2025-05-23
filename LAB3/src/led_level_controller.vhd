LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY led_level_controller IS
    GENERIC (
        NUM_LEDS : POSITIVE := 16;
        CHANNEL_LENGHT : POSITIVE := 24;
        refresh_time_ms : POSITIVE := 1;
        clock_period_ns : POSITIVE := 10
    );
    PORT (

        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;

        led : OUT STD_LOGIC_VECTOR(NUM_LEDS - 1 DOWNTO 0);

        s_axis_tvalid : IN STD_LOGIC;
        s_axis_tdata : IN STD_LOGIC_VECTOR(CHANNEL_LENGHT - 1 DOWNTO 0);
        s_axis_tlast : IN STD_LOGIC;
        s_axis_tready : OUT STD_LOGIC

    );
END led_level_controller;

ARCHITECTURE Behavioral OF led_level_controller IS
    CONSTANT REFRESH_CYCLES : NATURAL := (refresh_time_ms * 1_000_000) / clock_period_ns;

    SIGNAL volume_value : signed(CHANNEL_LENGHT - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL abs_audio_left : unsigned(CHANNEL_LENGHT - 2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL abs_audio_right : unsigned(CHANNEL_LENGHT - 2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL leds_int : STD_LOGIC_VECTOR(NUM_LEDS - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL led_update : STD_LOGIC := '0';
    SIGNAL refresh_counter : NATURAL RANGE 0 TO REFRESH_CYCLES - 1 := 0;

BEGIN
    led <= leds_int;
    s_axis_tready <= '1';

    -- Registering the absolute audio value
    PROCESS (aclk)
        VARIABLE sdata_signed : signed(CHANNEL_LENGHT - 1 DOWNTO 0);
        VARIABLE abs_value : unsigned(CHANNEL_LENGHT - 1 DOWNTO 0);
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                volume_value <= (OTHERS => '0');
                abs_audio_left <= (OTHERS => '0');
                abs_audio_right <= (OTHERS => '0');
            ELSIF s_axis_tvalid = '1' THEN
                sdata_signed := signed(s_axis_tdata);
                volume_value <= sdata_signed;
                -- Absolute value calculation
                IF sdata_signed(CHANNEL_LENGHT - 1) = '1' THEN
                    abs_value := unsigned(-sdata_signed);
                ELSE
                    abs_value := unsigned(sdata_signed);
                END IF;
                -- Assign to the correct channel
                IF s_axis_tlast = '1' THEN -- Left channel
                    abs_audio_left <= abs_value(CHANNEL_LENGHT - 2 DOWNTO 0);
                ELSE -- Right channel
                    abs_audio_right <= abs_value(CHANNEL_LENGHT - 2 DOWNTO 0);
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- Refresh counter
    PROCESS (aclk)
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                refresh_counter <= 0;
                led_update <= '0';
            ELSIF refresh_counter = REFRESH_CYCLES - 1 THEN
                refresh_counter <= 0;
                led_update <= '1';
            ELSE
                refresh_counter <= refresh_counter + 1;
                led_update <= '0';
            END IF;
        END IF;
    END PROCESS;

    -- Linear scaling and LED update
    PROCESS (aclk)
        VARIABLE leds_on : NATURAL RANGE 0 TO NUM_LEDS;
        VARIABLE temp_led_level : INTEGER RANGE 0 TO NUM_LEDS;
        VARIABLE abs_audio_sum : unsigned(CHANNEL_LENGHT - 1 DOWNTO 0);
    BEGIN
        IF rising_edge(aclk) THEN
            IF aresetn = '0' THEN
                leds_int <= (OTHERS => '0');
            ELSIF led_update = '1' THEN
                abs_audio_sum := resize(abs_audio_left, CHANNEL_LENGHT) + resize(abs_audio_right, CHANNEL_LENGHT);

                IF (abs_audio_left = 0 AND abs_audio_right = 0) THEN
                    temp_led_level := 0;
                ELSE
                    -- Automatic scaling
                    -- Sensitivity can be adjusted by changing the shift constant
                    temp_led_level := 1 + to_integer(shift_right(abs_audio_sum, CHANNEL_LENGHT - 4));
                END IF;

                -- Limit to the maximum number of LEDs
                IF temp_led_level > NUM_LEDS THEN
                    leds_on := NUM_LEDS;
                ELSE
                    leds_on := temp_led_level;
                END IF;

                -- Update the LEDs
                leds_int <= (OTHERS => '0');
                IF leds_on > 0 THEN
                    leds_int(leds_on - 1 DOWNTO 0) <= (OTHERS => '1');
                END IF;
            END IF;
        END IF;
    END PROCESS;
END Behavioral;