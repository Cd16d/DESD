-- File:            KittCar_v1.vhd
-- Description:     Better asyncronous logic handling & unsigned n_period
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
    CONSTANT MIN_KITT_CAR_STEP_NS : UNSIGNED(46 DOWNTO 0) := to_unsigned(MIN_KITT_CAR_STEP_MS * 1000000, 47);

    SIGNAL leds_sr : STD_LOGIC_VECTOR(led'RANGE) := (OTHERS => '0');
    SIGNAL n_period : UNSIGNED(sw'RANGE) := to_unsigned(1, sw'LENGTH);
    SIGNAL up : STD_LOGIC := '1';
BEGIN

    -- Sincronous logic
    PROCESS (clk, reset)
        VARIABLE counter : UNSIGNED(46 DOWNTO 0) := (OTHERS => '0');
    BEGIN
        IF reset = '1' THEN
            leds_sr <= (OTHERS => '0');
            counter := (OTHERS => '0');
        ELSIF rising_edge(clk) THEN

            -- Kitt logic
            IF unsigned(leds_sr) = 0 THEN
                leds_sr(0) <= '1';
                up <= '1';
            ELSIF leds_sr(led'HIGH) = '1' THEN
                up <= '0';
            ELSIF leds_sr(led'LOW) = '1' THEN
                up <= '1';
            END IF;

            -- Increment the counter
            counter := counter + to_unsigned(CLK_PERIOD_NS, counter'LENGTH);

            -- Calculate the number of periods
            IF counter >= (MIN_KITT_CAR_STEP_NS * n_period) THEN

                -- Shift the leds
                IF up = '1' THEN
                    leds_sr <= leds_sr(NUM_OF_LEDS - 2 DOWNTO 0) & '0';
                ELSIF up = '0' THEN
                    leds_sr <= '0' & leds_sr(NUM_OF_LEDS - 1 DOWNTO 1);
                END IF;

                -- Reset the counter
                counter := (OTHERS => '0');
            END IF;
        END IF;
    END PROCESS;

    -- Handle the switch
    PROCESS (sw)
    BEGIN
        n_period <= unsigned(sw) + 1;
    END PROCESS;

    led <= leds_sr;

END Behavioral;