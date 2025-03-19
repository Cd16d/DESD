-- File:            KittCar_v2.vhd
-- Description:     Counter prescaler
-- Known problem:   Not yet tested

---------- DEFAULT LIBRARY ---------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
------------------------------------

ENTITY KittCar IS
    GENERIC (

        CLK_PERIOD_NS : POSITIVE RANGE 1 TO 100 := 10; -- clk period in nanoseconds
        MIN_KITT_CAR_STEP_MS : POSITIVE RANGE 1 TO 2000 := 1; -- Minimum step period in milliseconds (i.e., value in milliseconds of Delta_t)

        NUM_OF_SWS : INTEGER RANGE 1 TO 16 := 16; -- Number of input switches
        NUM_OF_LEDS : INTEGER RANGE 1 TO 16 := 16 -- Number of output LEDs

    );
    PORT (

        ------- Reset/Clock --------
        reset : IN STD_LOGIC;
        clk : IN STD_LOGIC;
        ----------------------------

        -------- LEDs/SWs ----------
        sw : IN STD_LOGIC_VECTOR(NUM_OF_SWS - 1 DOWNTO 0); -- Switches avaiable on Basys3
        led : OUT STD_LOGIC_VECTOR(NUM_OF_LEDS - 1 DOWNTO 0) -- LEDs avaiable on Basys3
        ----------------------------

    );
END KittCar;

ARCHITECTURE Behavioral OF KittCar IS
    SIGNAL leds_sr : STD_LOGIC_VECTOR(led'RANGE) := (OTHERS => '0');
    SIGNAL n_period : POSITIVE RANGE 1 TO (2 ** NUM_OF_SWS) := 1;
    SIGNAL up : STD_LOGIC := '1';
BEGIN

    -- Sincronous logic
    PROCESS (clk, reset)
        VARIABLE counter_ns : INTEGER := 0;
        VARIABLE counter_ms : INTEGER := 0;
    BEGIN
        IF reset = '1' THEN
            leds_sr <= (OTHERS => '0');
            counter_ns := 0;
            counter_ms := 0;
        ELSIF rising_edge(clk) THEN

            -- Reset the leds
            IF unsigned(leds_sr) = 0 THEN
                leds_sr(0) <= '1';
            END IF;

            -- Handle counters
            counter_ns := counter_ns + CLK_PERIOD_NS;
            IF counter_ns >= 1000000 THEN
                counter_ms := counter_ms + 1;
                counter_ns := 0;
            END IF;

            -- Calculate the number of periods
            IF counter_ms >= (MIN_KITT_CAR_STEP_MS * n_period) THEN

                -- Shift the leds
                IF up = '1' THEN
                    leds_sr <= leds_sr(NUM_OF_LEDS - 2 DOWNTO 0) & '0';
                ELSIF up = '0' THEN
                    leds_sr <= '0' & leds_sr(NUM_OF_LEDS - 1 DOWNTO 1);
                END IF;

                -- Reset the counter
                counter_ms := 0;
            END IF;
        END IF;
    END PROCESS;

    -- Kitt logic
    PROCESS (leds_sr)
    BEGIN
        IF leds_sr(led'HIGH) = '1' THEN
            up <= '0';
        ELSIF leds_sr(led'LOW) = '1' THEN
            up <= '1';
        END IF;
    END PROCESS;

    -- Handle the switch
    PROCESS (sw)
    BEGIN
        n_period <= to_integer(unsigned(sw)) + 1;
    END PROCESS;

    led <= leds_sr;

END Behavioral;