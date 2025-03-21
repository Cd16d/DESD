---------- DEFAULT LIBRARY ---------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
------------------------------------

ENTITY KittCarPWM IS
    GENERIC (
        CLK_PERIOD_NS : POSITIVE RANGE 1 TO 100 := 10; -- clk period in nanoseconds
        MIN_KITT_CAR_STEP_MS : POSITIVE RANGE 1 TO 2000 := 1; -- Minimum step period in milliseconds (i.e., value in milliseconds of Delta_t)

        NUM_OF_SWS : INTEGER RANGE 1 TO 16 := 16; -- Number of input switches
        NUM_OF_LEDS : INTEGER RANGE 1 TO 16 := 16; -- Number of output LEDs

        TAIL_LENGTH : INTEGER RANGE 1 TO 16 := 4 -- Tail length
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
END KittCarPWM;

ARCHITECTURE Behavioral OF KittCarPWM IS
    COMPONENT PulseWidthModulator
        GENERIC (
            BIT_LENGTH : INTEGER RANGE 1 TO 16;
            T_ON_INIT : POSITIVE;
            PERIOD_INIT : POSITIVE;
            PWM_INIT : STD_LOGIC
        );
        PORT (
            reset : IN STD_LOGIC;
            clk : IN STD_LOGIC;

            Ton : IN STD_LOGIC_VECTOR(BIT_LENGTH - 1 DOWNTO 0);
            Period : IN STD_LOGIC_VECTOR(BIT_LENGTH - 1 DOWNTO 0);
            PWM : OUT STD_LOGIC
        );
    END COMPONENT;

    TYPE led_reg IS ARRAY (TAIL_LENGTH - 1 DOWNTO 0) OF INTEGER RANGE 0 TO led'HIGH;

    CONSTANT MIN_KITT_CAR_STEP_NS : UNSIGNED(46 DOWNTO 0) := to_unsigned(MIN_KITT_CAR_STEP_MS * 1000000, 47);
    CONSTANT BIT_LENGTH : INTEGER RANGE 1 TO 16 := 8;

    SIGNAL leds_sr : led_reg := (OTHERS => 0);
    SIGNAL leds_pwm : STD_LOGIC_VECTOR(TAIL_LENGTH - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL led_sig : STD_LOGIC_VECTOR(NUM_OF_LEDS - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL n_period : UNSIGNED(NUM_OF_SWS DOWNTO 0) := to_unsigned(1, NUM_OF_SWS + 1);
    SIGNAL up : STD_LOGIC := '1';
BEGIN

    -- Instantiate the PWM
    PWM : FOR i IN 1 TO TAIL_LENGTH GENERATE
    BEGIN
        PWM : PulseWidthModulator
        GENERIC MAP(
            BIT_LENGTH => BIT_LENGTH,
            T_ON_INIT => 64,
            PERIOD_INIT => 128,
            PWM_INIT => '0'
        )
        PORT MAP(
            reset => reset,
            clk => clk,
            Ton => STD_LOGIC_VECTOR(to_unsigned(i, BIT_LENGTH)),
            Period => STD_LOGIC_VECTOR(to_unsigned(TAIL_LENGTH - 1, BIT_LENGTH)),
            PWM => leds_pwm(i - 1)
        );
    END GENERATE;

    -- Sincronous logic
    PROCESS (clk, reset)
        VARIABLE counter : UNSIGNED(46 DOWNTO 0) := (OTHERS => '0');
    BEGIN
        IF reset = '1' THEN
            leds_sr <= (OTHERS => 0);
            led_sig <= (OTHERS => '0');
            counter := (OTHERS => '0');
        ELSIF rising_edge(clk) THEN

            -- Kitt logic
            IF leds_sr(TAIL_LENGTH - 1) = 15 THEN
                up <= '0';
            ELSIF leds_sr(TAIL_LENGTH - 1) = 0 THEN
                up <= '1';
            END IF;

            -- Increment the counter
            counter := counter + to_unsigned(CLK_PERIOD_NS, counter'LENGTH);

            -- Calculate the number of periods
            IF counter >= (MIN_KITT_CAR_STEP_NS * n_period) THEN

                -- Shift the leds
                IF up = '1' THEN
                    leds_sr <= (leds_sr(TAIL_LENGTH - 1) + 1) & leds_sr(TAIL_LENGTH - 2 DOWNTO 0);
                ELSIF up = '0' THEN
                    leds_sr <= (leds_sr(TAIL_LENGTH - 1) - 1) & leds_sr(TAIL_LENGTH - 2 DOWNTO 0);
                END IF;

                -- Reset leg_sig
                led_sig <= (OTHERS => '0');

                -- Assign the leds
                FOR i IN 0 TO TAIL_LENGTH - 1 LOOP
                    led_sig(leds_sr(i)) <= leds_pwm(i);
                END LOOP;

                -- Reset the counter
                counter := (OTHERS => '0');
            END IF;
        END IF;
    END PROCESS;

    -- Handle the switch
    PROCESS (sw)
    BEGIN
        n_period <= unsigned('0' & sw) + 1;
    END PROCESS;

    led <= led_sig;

END Behavioral;